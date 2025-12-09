# 🚀 Ghid Deployment pe DigitalOcean

## Ce trebuie modificat când primești IP-ul de la DigitalOcean

### 1. **Backend CORS** (`dailyguest-api/src/main.ts`)

Adaugă IP-ul sau domeniul tău în lista de origins permise:

```typescript
app.enableCors({
  origin: [
    'http://localhost:5173',        // Development
    'http://localhost:3001',        // Development
    'http://localhost:80',         // Development
    'http://frontend:3001',          // Docker internal
    'http://dashboard:80',           // Docker internal
    'http://YOUR_DROPLET_IP:3001',  // ✅ Adaugă IP-ul tău pentru frontend
    'http://YOUR_DROPLET_IP:5173',  // ✅ Adaugă IP-ul tău pentru dashboard
    // Sau dacă ai domeniu:
    'https://yourdomain.com',       // ✅ Frontend domain
    'https://dashboard.yourdomain.com', // ✅ Dashboard domain
  ],
  // ... rest of config
});
```

### 2. **Frontend Environment Variables**

În `Website-Adrian/frontend/.env.production.local` (sau `.env`):

```env
# ✅ Schimbă localhost cu IP-ul sau domeniul tău
NEXT_PUBLIC_API_URL=http://YOUR_DROPLET_IP:3000
# Sau dacă ai domeniu:
# NEXT_PUBLIC_API_URL=https://api.yourdomain.com

NEXT_PUBLIC_API_KEY=your-api-key-here
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_...
NEXT_PUBLIC_PYNBOOKING_API_KEY=your-key
# ... rest of variables
```

**IMPORTANT:** Rebuild frontend-ul după modificare:
```bash
docker-compose build frontend
```

### 3. **Dashboard API URLs** (Hardcodate în cod)

Trebuie să modifici fișierele din `apartment-dashboard/src/service/`:

#### `apartment-dashboard/src/service/ApartmentService.js`:
```javascript
// ❌ Schimbă asta:
const API_BASE_URL = 'http://localhost:3000/api/apartment-service';

// ✅ Cu asta:
const API_BASE_URL = 'http://YOUR_DROPLET_IP:3000/api/apartment-service';
// Sau dacă ai domeniu:
// const API_BASE_URL = 'https://api.yourdomain.com/api/apartment-service';
```

#### `apartment-dashboard/src/service/AuthService.js`:
```javascript
// ❌ Schimbă asta:
const API_BASE_URL = 'http://localhost:3000/api/auth-service';

// ✅ Cu asta:
const API_BASE_URL = 'http://YOUR_DROPLET_IP:3000/api/auth-service';
```

#### `apartment-dashboard/src/service/DiscountService.js`:
```javascript
// ❌ Schimbă asta:
const API_BASE_URL = 'http://localhost:3000/api/discount-code-service';

// ✅ Cu asta:
const API_BASE_URL = 'http://YOUR_DROPLET_IP:3000/api/discount-code-service';
```

**IMPORTANT:** Rebuild dashboard-ul după modificare:
```bash
docker-compose build dashboard
```

### 4. **Docker Compose Build Args** (Opțional)

În `docker-compose.yml`, poți actualiza build args pentru frontend:

```yaml
frontend:
  build:
    args:
      - NEXT_PUBLIC_API_URL=http://YOUR_DROPLET_IP:3000  # ✅ Actualizează aici
      # ... rest
```

## 📋 Checklist Deployment

- [ ] Modificat CORS în `dailyguest-api/src/main.ts`
- [ ] Actualizat `NEXT_PUBLIC_API_URL` în `Website-Adrian/frontend/.env.production.local`
- [ ] Modificat `API_BASE_URL` în toate serviciile dashboard (`ApartmentService.js`, `AuthService.js`, `DiscountService.js`)
- [ ] Rebuild toate serviciile: `docker-compose build`
- [ ] Verificat că porturile sunt expuse corect în DigitalOcean Firewall
- [ ] Testat conexiunea de la frontend la backend
- [ ] Testat conexiunea de la dashboard la backend

## 🔥 DigitalOcean Firewall Setup

Asigură-te că ai deschis următoarele porturi în DigitalOcean Firewall:

- **Port 3000** - Backend API
- **Port 3001** - Frontend Next.js
- **Port 5173** - Dashboard
- **Port 22** - SSH (pentru acces)

## 🌐 Configurare Domeniu și SSL

### Pasul 1: Configurare DNS

În panoul DNS al provider-ului tău de domeniu, adaugă următoarele record-uri A:

```
Type    Name              Value              TTL
A       @                 YOUR_DROPLET_IP    3600
A       www                YOUR_DROPLET_IP    3600
A       api                YOUR_DROPLET_IP    3600
A       dashboard          YOUR_DROPLET_IP    3600
```

### Pasul 2: Instalare Nginx și Certbot

```bash
# Conectează-te la droplet-ul tău DigitalOcean
ssh root@YOUR_DROPLET_IP

# Instalează Nginx
apt-get update
apt-get install -y nginx

# Instalează Certbot pentru SSL
apt-get install -y certbot python3-certbot-nginx
```

### Pasul 3: Configurare Nginx Reverse Proxy

1. Copiază configurația:
```bash
# Copiază fișierul nginx-reverse-proxy.conf în /etc/nginx/sites-available/yourdomain.com
# Editează și înlocuiește "yourdomain.com" cu domeniul tău real
nano /etc/nginx/sites-available/yourdomain.com
```

2. Activează configurația:
```bash
ln -s /etc/nginx/sites-available/yourdomain.com /etc/nginx/sites-enabled/
nginx -t  # Verifică configurația
systemctl reload nginx
```

### Pasul 4: Obținere Certificate SSL

```bash
# Pentru frontend (yourdomain.com)
certbot --nginx -d yourdomain.com -d www.yourdomain.com --non-interactive --agree-tos --email your@email.com

# Pentru backend API (api.yourdomain.com)
certbot --nginx -d api.yourdomain.com --non-interactive --agree-tos --email your@email.com

# Pentru dashboard (dashboard.yourdomain.com)
certbot --nginx -d dashboard.yourdomain.com --non-interactive --agree-tos --email your@email.com
```

Sau folosește scriptul automatizat:
```bash
chmod +x setup-ssl.sh
./setup-ssl.sh yourdomain.com your@email.com
```

### Pasul 5: Auto-Renewal SSL (Cron Job)

Certbot configurează automat un cron job care verifică zilnic certificatele și le reînnoiește automat când mai au **mai puțin de 30 de zile** până la expirare.

Verifică cron job-ul:
```bash
crontab -l | grep certbot
```

Ar trebui să vezi ceva de genul:
```
0 0,12 * * * certbot renew --quiet
```

**Notă:** Certbot verifică automat și reînnoiește certificatele când mai au < 30 zile până la expirare. Nu trebuie să faci nimic manual!

### Pasul 6: Actualizare Environment Variables

După configurarea SSL, actualizează variabilele de mediu:

**Frontend** (`Website-Adrian/frontend/.env.production.local`):
```env
NEXT_PUBLIC_API_URL=https://api.yourdomain.com
```

**Dashboard** (în servicii):
```javascript
const API_BASE_URL = 'https://api.yourdomain.com/api/apartment-service';
```

**Backend CORS** (`dailyguest-api/src/main.ts`):
```typescript
origin: [
  'https://yourdomain.com',
  'https://www.yourdomain.com',
  'https://dashboard.yourdomain.com',
  // ... rest
]
```

## ⚠️ Note Importante

1. **HTTPS**: Pentru producție, folosește HTTPS (Let's Encrypt cu Certbot)
2. **Environment Variables**: Nu hardcoda IP-uri în cod, folosește variabile de mediu
3. **Security**: Asigură-te că API keys și secrets nu sunt expuse în cod
4. **MongoDB**: Dacă folosești MongoDB Atlas, nu trebuie să modifici nimic

