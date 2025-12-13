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
  apt-get install -y ca-certificates curl gnupg git ufw nginx certbot python3-certbot-nginx

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
# SETUP FIREWALL
# ============================================
setup_firewall() {
  log "Configurez firewall..."
  ufw allow OpenSSH
  ufw allow 80/tcp
  ufw allow 443/tcp
  ufw --force enable
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
  
  if [[ ! -f "$APP_DIR/dailyguest-api/.env" ]]; then
    error "Lipsește: $APP_DIR/dailyguest-api/.env"
    echo "Creează fișierul cu variabilele necesare:"
    echo "  MONGO_URI=mongodb://..."
    echo "  STRIPE_SECRET_KEY=sk_..."
    echo "  STRIPE_WEBHOOK_SECRET=whsec_..."
    echo "  INTERNAL_API_KEY=..."
    echo "  PYNBOOKING_API_KEY=..."
    exit 1
  fi
  
  success "Fișierele .env sunt prezente."
}

# ============================================
# SETUP NGINX (REVERSE PROXY)
# ============================================
setup_nginx() {
  log "Configurez Nginx reverse proxy..."
  
  cat > /etc/nginx/sites-available/$DOMAIN <<EOF
# Redirect HTTP to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN www.$DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

# Main site
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN www.$DOMAIN;

    # SSL will be configured by Certbot
    # ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Dashboard (React/Vite) - serves at /dashboard/
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
        
        # For Stripe webhooks - preserve raw body
        proxy_set_header Content-Type \$content_type;
    }

    # Frontend (Next.js) - catch-all, must be last
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

  # Enable site
  ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
  rm -f /etc/nginx/sites-enabled/default
  
  # Test and reload
  nginx -t && systemctl reload nginx
  success "Nginx configurat."
}

# ============================================
# OBTAIN SSL CERTIFICATE
# ============================================
obtain_ssl() {
  log "Obțin certificat SSL..."
  
  # First, create a simple HTTP config for Certbot
  cat > /etc/nginx/sites-available/$DOMAIN-temp <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN www.$DOMAIN;
    
    location / {
        root /var/www/html;
    }
}
EOF
  ln -sf /etc/nginx/sites-available/$DOMAIN-temp /etc/nginx/sites-enabled/
  rm -f /etc/nginx/sites-enabled/$DOMAIN
  nginx -t && systemctl reload nginx
  
  # Get certificate (only main domain and www)
  certbot --nginx -d "$DOMAIN" -d "www.$DOMAIN" \
    --redirect --agree-tos -m "$EMAIL" --non-interactive || {
      error "Certbot a eșuat. Verifică DNS-ul."
      exit 1
    }
  
  # Remove temp config and enable full config
  rm -f /etc/nginx/sites-enabled/$DOMAIN-temp
  rm -f /etc/nginx/sites-available/$DOMAIN-temp
  
  # Re-setup nginx with SSL
  setup_nginx
  
  # Test renewal
  certbot renew --dry-run
  
  success "SSL configurat."
}

# ============================================
# BUILD AND RUN DOCKER CONTAINERS
# ============================================
run_compose() {
  log "Pornesc containerele Docker..."
  cd "$APP_DIR"
  
  # Build with parallel builds
  log "Build containers (poate dura câteva minute)..."
  docker compose build --parallel
  
  # Start containers
  docker compose up -d
  
  # Wait and check health
  sleep 10
  
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
  setup_firewall
  clone_repo
  check_env_files
  
  # Setup nginx before SSL
  setup_nginx
  
  # Get SSL
  obtain_ssl
  
  # Build and run
  run_compose
  
  echo ""
  success "=== DEPLOYMENT COMPLET ==="
  echo ""
  echo "🌐 Site: https://$DOMAIN"
  echo "📊 Dashboard: https://$DOMAIN/dashboard/"
  echo "🔧 API: https://$DOMAIN/api/"
  echo ""
  echo "Comenzi utile:"
  echo "  cd $APP_DIR && docker compose logs -f    # Vezi loguri"
  echo "  cd $APP_DIR && docker compose ps         # Status"
  echo "  cd $APP_DIR && docker compose restart    # Restart"
  echo ""
}

main "$@"

