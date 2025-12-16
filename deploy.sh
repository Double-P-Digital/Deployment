#!/usr/bin/env bash
set -euo pipefail

# ============================================
# CONFIGURATION
# ============================================
DOMAIN="dailyguest.online"
EMAIL="parnau.patrick@yahoo.com"
REPO_URL="https://github.com/Double-P-Digital/Deployment.git"
APP_DIR="/opt/deployment"

# Enable BuildKit for faster Docker builds
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

# ============================================
# HELPER FUNCTIONS
# ============================================
log() { echo -e "\n\033[1;34m[INFO]\033[0m $1"; }
error() { echo -e "\n\033[1;31m[ERROR]\033[0m $1" >&2; }
success() { echo -e "\n\033[1;32m[SUCCESS]\033[0m $1"; }
warn() { echo -e "\n\033[1;33m[WARNING]\033[0m $1"; }

require_root() {
  if [[ $EUID -ne 0 ]]; then
    error "Rulează cu sudo/root."
    exit 1
  fi
}

# ============================================
# INSTALL PACKAGES
# ============================================
install_packages() {
  log "Instalez pachete necesare..."
  apt-get update
  apt-get install -y ca-certificates curl gnupg git ufw nginx certbot python3-certbot-nginx fail2ban

  # Install Docker
  if ! command -v docker &> /dev/null; then
    log "Instalez Docker..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$UBUNTU_CODENAME") stable" \
      > /etc/apt/sources.list.d/docker.list
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    systemctl enable --now docker
  else
    log "Docker deja instalat."
  fi
}

# ============================================
# SETUP SECURITY (fail2ban only)
# ============================================
setup_security() {
  log "Configurez securitate..."
  
  # Configure fail2ban
  cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 86400
EOF

  systemctl enable fail2ban
  systemctl restart fail2ban
  
  success "Fail2ban configurat."
  
  # Notă: Autentificarea cu parolă NU se dezactivează automat.
  # Pentru securitate maximă, după ce ai configurat SSH keys, poți rula manual:
  # sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && systemctl reload ssh
}

# ============================================
# SETUP FIREWALL
# ============================================
setup_firewall() {
  log "Configurez firewall..."
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow OpenSSH
  ufw allow 80/tcp
  ufw allow 443/tcp
  ufw --force enable
  success "Firewall configurat."
}

# ============================================
# CLONE/UPDATE REPOSITORY
# ============================================
clone_repo() {
  log "Clonez/actualizez repository..."
  if [[ -d "$APP_DIR/.git" ]]; then
    cd "$APP_DIR"
    git pull
    git submodule update --init --recursive --remote
  else
    git clone --recursive "$REPO_URL" "$APP_DIR"
    cd "$APP_DIR"
  fi
}

# ============================================
# CHECK ENV FILES
# ============================================
check_env_files() {
  log "Verific fișierele .env..."
  
  local missing=0
  
  if [[ ! -f "$APP_DIR/dailyguest-api/.env" ]]; then
    error "Lipsește: $APP_DIR/dailyguest-api/.env"
    echo "Creează fișierul cu variabilele necesare:"
    echo "  MONGO_URI=mongodb+srv://..."
    echo "  STRIPE_SECRET_KEY=sk_live_..."
    echo "  STRIPE_WEBHOOK_SECRET=whsec_..."
    echo "  INTERNAL_API_KEY=..."
    echo "  PYNBOOKING_API_KEY=..."
    echo "  JWT_SECRET=..."
    missing=1
  fi
  
  if [[ ! -f "$APP_DIR/Website-Adrian/frontend/.env.production.local" ]]; then
    warn "Lipsește: $APP_DIR/Website-Adrian/frontend/.env.production.local"
    echo "Creează fișierul cu:"
    echo "  NEXT_PUBLIC_API_URL=https://dailyguest.online"
    echo "  NEXT_PUBLIC_API_KEY=<your-api-key>"
    echo "  NEXT_PUBLIC_GOOGLE_MAPS_API_KEY=<your-maps-key>"
    echo "  NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_live_..."
  fi
  
  if [[ $missing -eq 1 ]]; then
    exit 1
  fi
  
  success "Fișierele .env sunt prezente."
}

# ============================================
# SETUP NGINX (REVERSE PROXY) - WITHOUT SSL
# ============================================
setup_nginx_http() {
  log "Configurez Nginx (HTTP)..."
  
  cat > /etc/nginx/sites-available/$DOMAIN <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN www.$DOMAIN;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Dashboard (React/Vite)
    location /dashboard {
        proxy_pass http://127.0.0.1:5173;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # API Backend
    location /api/ {
        proxy_pass http://127.0.0.1:3000/api/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 86400;
        proxy_set_header Content-Type \$content_type;
    }

    # Frontend (Next.js)
    location / {
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 86400;
    }
}
EOF

  ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
  rm -f /etc/nginx/sites-enabled/default
  
  nginx -t && systemctl reload nginx
  success "Nginx configurat (HTTP)."
}

# ============================================
# OBTAIN SSL CERTIFICATE + AUTO-RENEW
# ============================================
obtain_ssl() {
  log "Obțin certificat SSL..."
  
  # Verifică dacă DNS-ul pointează corect
  local server_ip=$(curl -s ifconfig.me)
  local dns_ip=$(dig +short $DOMAIN | head -n1)
  
  if [[ "$server_ip" != "$dns_ip" ]]; then
    warn "DNS-ul pentru $DOMAIN ($dns_ip) nu pointează la acest server ($server_ip)"
    warn "SSL va fi configurat, dar poate eșua dacă DNS-ul nu e propagat."
    echo ""
    read -p "Continui oricum? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Poți rula SSL mai târziu cu:"
      echo "  certbot --nginx -d $DOMAIN -d www.$DOMAIN --redirect --agree-tos -m $EMAIL"
      return 0
    fi
  fi
  
  # Obține certificat SSL
  certbot --nginx -d "$DOMAIN" -d "www.$DOMAIN" \
    --redirect --agree-tos -m "$EMAIL" --non-interactive || {
      error "Certbot a eșuat!"
      echo ""
      echo "Posibile cauze:"
      echo "  1. DNS-ul nu pointează încă la acest server"
      echo "  2. Portul 80 nu e accesibil"
      echo "  3. Rate limit Let's Encrypt"
      echo ""
      echo "Poți rula SSL manual mai târziu cu:"
      echo "  certbot --nginx -d $DOMAIN -d www.$DOMAIN --redirect --agree-tos -m $EMAIL"
      return 1
    }
  
  # Testează auto-renew
  log "Verific auto-renew..."
  certbot renew --dry-run
  
  # Verifică timer-ul systemd pentru auto-renew
  if systemctl list-timers | grep -q certbot; then
    success "Auto-renew configurat (systemd timer activ)."
  else
    # Adaugă cron job ca backup
    log "Adaug cron job pentru auto-renew..."
    (crontab -l 2>/dev/null | grep -v certbot; echo "0 3 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -
    success "Auto-renew configurat (cron job)."
  fi
  
  success "SSL configurat cu succes!"
}

# ============================================
# BUILD AND RUN DOCKER CONTAINERS
# ============================================
run_compose() {
  log "Pornesc containerele Docker..."
  cd "$APP_DIR"
  
  log "Build containers (poate dura câteva minute)..."
  docker compose build --parallel
  
  docker compose up -d
  
  sleep 15
  
  log "Status containere:"
  docker compose ps
  
  success "Containerele sunt pornite."
}

# ============================================
# MAIN
# ============================================
main() {
  require_root
  
  log "=== DEPLOYMENT DAILYGUEST.ONLINE ==="
  
  install_packages
  setup_security
  setup_firewall
  clone_repo
  check_env_files
  
  # Build and run Docker
  run_compose
  
  # Setup nginx (HTTP first)
  setup_nginx_http
  
  # Setup SSL (cu auto-renew)
  obtain_ssl
  
  echo ""
  success "=== DEPLOYMENT COMPLET ==="
  echo ""
  echo "🌐 Site: https://$DOMAIN"
  echo "📊 Dashboard: https://$DOMAIN/dashboard/"
  echo "🔧 API: https://$DOMAIN/api/"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Comenzi utile:"
  echo "  cd $APP_DIR && docker compose logs -f      # Vezi loguri"
  echo "  cd $APP_DIR && docker compose ps           # Status"
  echo "  cd $APP_DIR && docker compose restart      # Restart"
  echo "  certbot renew --dry-run                    # Test renew SSL"
  echo "  systemctl list-timers | grep certbot       # Verifică auto-renew"
  echo ""
}

# Permite rularea individuală a funcțiilor
# Exemplu: ./deploy.sh obtain_ssl
if [[ "${1:-}" != "" ]]; then
  "$1"
else
  main
fi

