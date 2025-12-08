# Deployment - Docker Compose Setup

Acest proiect conține trei submodule configurate pentru deployment cu Docker Compose.

## 📦 Servicii

1. **Backend API** (dailyguest-api) - NestJS API pe portul 3000
2. **Frontend** (Website-Adrian/frontend) - Next.js pe portul 3001
3. **Dashboard** (apartment-dashboard) - React/Vite pe portul 5173
4. **MongoDB** - Baza de date pe portul 27017

## 🚀 Rulare Proiect

### 1. Configurare Variabile de Mediu

Creează un fișier `.env` în directorul root `Deployment/`:

```bash
# În directorul Deployment/
```

Fișierul `.env` trebuie să conțină:

```env
# Backend Environment Variables
STRIPE_SECRET_KEY=sk_test_your_stripe_secret_key
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret
INTERNAL_API_KEY=your-internal-api-key-here
JWT_SECRET=your-jwt-secret-key-change-in-production
JWT_EXPIRES_IN=3600
PYNBOOKING_API_KEY=your-pynbooking-api-key

# Frontend Environment Variables (Next.js)
NEXT_PUBLIC_API_URL=http://localhost:3000
NEXT_PUBLIC_API_KEY=your-internal-api-key-here
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_your_stripe_publishable_key
NEXT_PUBLIC_PYNBOOKING_API_KEY=your-pynbooking-api-key
```

**Notă importantă pentru Frontend:**
- Next.js citește automat variabilele `NEXT_PUBLIC_*` din `.env.local` la build time
- Dockerfile-ul extrage automat doar variabilele `NEXT_PUBLIC_*` din `.env` root și le pune în `.env.local` pentru frontend
- Dacă preferi, poți crea manual un fișier `.env.local` în `Website-Adrian/frontend/` cu doar variabilele `NEXT_PUBLIC_*`

### 2. Build și Start Servicii

```bash
# Build și start toate serviciile
docker-compose up --build

# Sau în background
docker-compose up -d --build
```

### 3. Verificare Status

```bash
# Vezi statusul serviciilor
docker-compose ps

# Vezi logurile
docker-compose logs -f

# Vezi logurile pentru un serviciu specific
docker-compose logs -f backend
```

## 🌐 Accesare Servicii

După ce serviciile sunt pornite, pot fi accesate la:

- **Frontend**: http://localhost:3001
- **Backend API**: http://localhost:3000
- **Dashboard**: http://localhost:5173
- **MongoDB**: localhost:27017

## 🛠️ Comenzi Utile

```bash
# Oprește serviciile
docker-compose down

# Oprește și șterge volume-urile (atenție: șterge datele MongoDB!)
docker-compose down -v

# Rebuild un serviciu specific
docker-compose build backend

# Restart un serviciu
docker-compose restart backend

# Execută comenzi în container
docker-compose exec backend sh
docker-compose exec mongodb mongosh
```

## 📁 Structură Proiect

```
Deployment/
├── docker-compose.yml          # Configurație Docker Compose
├── .env                        # Variabile de mediu (creat manual)
├── Website-Adrian/
│   └── frontend/
│       ├── frontend.Dockerfile # Dockerfile pentru Next.js
│       └── .env.local          # Generat automat din .env (doar NEXT_PUBLIC_*)
├── dailyguest-api/
│   └── backend.Dockerfile      # Dockerfile pentru NestJS
└── apartment-dashboard/
    ├── dashboard.Dockerfile    # Dockerfile pentru React/Vite
    └── nginx.conf              # Configurație Nginx
```

## ⚠️ Note Importante

1. **Variabile de Mediu**:
   - **Backend**: Citește din `.env` root prin `env_file` în docker-compose
   - **Frontend**: Dockerfile-ul extrage automat variabilele `NEXT_PUBLIC_*` din `.env` root și le pune în `.env.local` pentru Next.js la build time
   - **Dashboard**: Nu necesită variabile de mediu (build static)

2. **MongoDB**: Datele sunt persistate în volume Docker (`mongodb_data`)

3. **CORS**: Backend-ul este configurat să accepte request-uri de la frontend și dashboard

4. **Porturi**: Asigură-te că porturile 3000, 3001, 5173 și 27017 nu sunt deja folosite

## 🔧 Troubleshooting

### Serviciile nu pornesc
```bash
# Verifică logurile
docker-compose logs

# Verifică dacă porturile sunt libere
netstat -ano | findstr :3000
```

### MongoDB nu se conectează
- Verifică că serviciul `mongodb` rulează: `docker-compose ps`
- Verifică variabila `MONGO_URI` în docker-compose.yml

### Frontend nu se conectează la backend
- Verifică că `NEXT_PUBLIC_API_URL` este setat corect în `.env`
- Verifică că backend-ul rulează: `docker-compose logs backend`
- Verifică că variabilele `NEXT_PUBLIC_*` sunt în `.env` root

### Frontend nu folosește variabilele de mediu
- Verifică că variabilele încep cu `NEXT_PUBLIC_` în `.env`
- Rebuild frontend-ul: `docker-compose build frontend`
- Verifică logurile build: `docker-compose logs frontend`
