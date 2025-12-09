#!/bin/bash
# Script pentru setup SSL cu Let's Encrypt și auto-renewal

set -e

echo "🔒 SSL Setup Script pentru DigitalOcean"

# Verifică dacă rulează ca root
if [ "$EUID" -ne 0 ]; then 
    echo "⚠️  Te rog rulează scriptul cu sudo"
    exit 1
fi

# Instalează Certbot
echo "📦 Instalare Certbot..."
apt-get update
apt-get install -y certbot python3-certbot-nginx

# Variabile
DOMAIN="${1:-yourdomain.com}"
EMAIL="${2:-admin@${DOMAIN}}"

if [ "$DOMAIN" == "yourdomain.com" ]; then
    echo "⚠️  Folosește: ./setup-ssl.sh yourdomain.com your@email.com"
    exit 1
fi

echo "🌐 Configurare SSL pentru domeniul: $DOMAIN"
echo "📧 Email pentru notificări: $EMAIL"

# Obține certificate SSL
echo "🔐 Obținere certificate SSL..."
certbot --nginx -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos --email $EMAIL

# Creează script de renewal
echo "📝 Creare script renewal..."
cat > /usr/local/bin/renew-ssl.sh << 'EOF'
#!/bin/bash
# Script pentru renewal SSL

# Verifică dacă certificatele expiră în mai puțin de 30 de zile
certbot renew --dry-run --quiet

if [ $? -eq 0 ]; then
    # Dacă dry-run reușește, face renewal real
    certbot renew --quiet
    
    # Reload Nginx pentru a aplica noile certificate
    systemctl reload nginx
    
    echo "$(date): SSL certificates renewed successfully" >> /var/log/ssl-renewal.log
else
    echo "$(date): SSL renewal check failed" >> /var/log/ssl-renewal.log
fi
EOF

chmod +x /usr/local/bin/renew-ssl.sh

# Configurează cron job pentru renewal (rulează zilnic la 3 AM)
echo "⏰ Configurare cron job pentru auto-renewal..."
(crontab -l 2>/dev/null | grep -v renew-ssl.sh; echo "0 3 * * * /usr/local/bin/renew-ssl.sh >> /var/log/ssl-renewal.log 2>&1") | crontab -

echo "✅ SSL setup complet!"
echo "📋 Certificatele vor fi verificate zilnic și reînnoite automat când mai au < 30 zile până la expirare"
echo "📝 Loguri disponibile în: /var/log/ssl-renewal.log"

