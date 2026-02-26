# 📅 Sistem de Gestionare Date Blocate și Prețuri Modificate

## 🎯 Funcționalități Implementate

### 1. **Dashboard Admin - Interfață de Management**

Locație: `apartment-dashboard/src/components/DateManagement.jsx`

#### Caracteristici:

- ✅ **Combo Box** cu 2 opțiuni:

  - **Blochează o dată/perioadă** - Previne rezervările pentru anumite intervale
  - **Modifică prețul unei date/perioade** - Setează prețuri speciale pentru anumite intervale

- ✅ **Formulare Interactive**:

  - Selecție apartament
  - Date început și sfârșit (calendar)
  - Pentru blocări: motiv optional (ex: "Renovări", "Întreținere")
  - Pentru prețuri: preț nou per noapte

- ✅ **Vizualizare în Timp Real**:

  - Listă cu toate datele blocate active
  - Listă cu toate modificările de preț active
  - Posibilitate de ștergere pentru fiecare intrare

- ✅ **Interfață Prietenoasă**:
  - Design responsive
  - Validare date
  - Mesaje de succes/eroare
  - Emoji-uri pentru vizualizare îmbunătățită

---

## 🔧 Implementare Backend

### Scheme MongoDB Noi:

#### 1. **BlockedDate Schema**

```typescript
{
  apartmentId: ObjectId,
  startDate: Date,
  endDate: Date,
  reason: String (opțional),
  isActive: Boolean
}
```

#### 2. **PriceOverride Schema**

```typescript
{
  apartmentId: ObjectId,
  startDate: Date,
  endDate: Date,
  price: Number,
  currency: String (default: 'EUR'), // Suportă RON și EUR
  isActive: Boolean
}
```

### Endpoint-uri API Noi:

#### **Blocări Date:**

- `POST /api/apartment-service/:id/block-dates` - Blochează o perioadă
- `GET /api/apartment-service/:id/blocked-dates` - Listează blocările active
- `DELETE /api/apartment-service/blocked-dates/:blockId` - Șterge o blocare

#### **Modificări Preț:**

- `POST /api/apartment-service/:id/price-override` - Setează un preț custom
- `GET /api/apartment-service/:id/price-overrides` - Listează prețurile modificate
- `DELETE /api/apartment-service/price-overrides/:overrideId` - Șterge o modificare

#### **Verificări și Calcule:**

- `GET /api/apartment-service/:id/check-blocked` - Verifică dacă o perioadă este blocată

  - Query params: `checkInDate`, `checkOutDate`
  - Returnează: `{ isBlocked: boolean, message?: string, blockedDates?: [] }`

- `GET /api/apartment-service/:id/calculate-price` - Calculează prețul cu override-uri
  - Query params: `checkInDate`, `checkOutDate`
  - Returnează:
    ```json
    {
      "totalPrice": 450,
      "nightlyPrices": [
        { "date": "2026-03-01", "price": 150, "currency": "EUR" },
        { "date": "2026-03-02", "price": 150, "currency": "EUR" },
        { "date": "2026-03-03", "price": 150, "currency": "EUR" }
      ],
      "averagePrice": 150,
      "hasOverrides": false,
      "currency": "EUR"
    }
    ```

---

## 📱 Cum se Afișează în Frontend

### 1. **În Dashboard (Admin)**

Al doilea card după "Manage Apartments" și înainte de "Discount Codes":

```
┌─────────────────────────────────────┐
│  📅 Gestionare Date și Prețuri      │
│                                      │
│  [Combo Box: Blochează / Modif Preț]│
│  [Selectează Apartamentul]           │
│  [Data început] [Data sfârșit]      │
│  [Preț: ___] [Valută: EUR/RON]      │
│  [Buton Submit]                      │
│                                      │
│  ── Date Blocate Active ──          │
│  📅 01.03.2026 - 05.03.2026 [Șterge]│
│     (Renovări)                       │
│                                      │
│  ── Prețuri Modificate Active ──    │
│  💰 10.03.2026 - 15.03.2026 [Șterge]│
│     €200/noapte                      │
│  💰 20.03.2026 - 25.03.2026 [Șterge]│
│     850 lei/noapte                   │
└─────────────────────────────────────┘
```

### 2. **În Website Public (Frontend)**

Integrare automată în procesul de rezervare:

#### La Selecția Datelor:

- ❌ **Datele blocate** → nu pot fi selectate/rezervate
- ✅ **Prețurile modificate** → aplicate automat la calcul

#### La Checkout:

```javascript
// Verificare automată înainte de plată:
const blockCheck = await checkIfBlocked(apartmentId, checkIn, checkOut);
if (blockCheck.isBlocked) {
  // Afișează eroare: "Perioada nu este disponibilă"
  return { error: blockCheck.message };
}

// Calcul preț cu override-uri:
const priceCalc = await calculatePriceWithOverrides(
  apartmentId,
  checkIn,
  checkOut
);
// Folosește priceCalc.totalPrice în loc de apartment.price
```

---

## 🔄 Cum se Anulează Acțiunile?

### Metoda 1: **Din Dashboard (Recomandat)**

1. Accesează dashboard-ul admin
2. Scroll la secțiunea "Gestionare Date și Prețuri"
3. Selectează apartamentul dorit
4. Alege tipul acțiunii (Blochează / Modifică preț)
5. Vezi lista de acțiuni active
6. Click pe **[Șterge]** la acțiunea dorită
7. ✅ Confirmare instant - acțiunea este anulată

### Metoda 2: **Via API Direct**

```bash
# Șterge blocare
curl -X DELETE https://dailyguest.online/api/apartment-service/blocked-dates/{blockId} \
  -H "x-api-key: your-api-key"

# Șterge modificare preț
curl -X DELETE https://dailyguest.online/api/apartment-service/price-overrides/{overrideId} \
  -H "x-api-key: your-api-key"
```

---

## 🚀 Testare Completă

### Pas 1: Pornește Aplicațiile

```bash
# Terminal 1 - Backend
cd dailyguest-api
npm run start:dev

# Terminal 2 - Dashboard
cd apartment-dashboard
npm run dev

# Terminal 3 - Frontend Public
cd Website-Adrian/frontend
npm run dev
```

### Pas 2: Testează Blocarea Datelor

1. Accesează dashboard: http://localhost:5173
2. Login cu credențialele admin
3. Navighează la "Gestionare Date și Prețuri"
4. Selectează "Blochează o dată/perioadă"
5. Alege un apartament
6. Setează: Start: 01.03.2026, End: 05.03.2026
7. Motiv: "Test blocare"
8. Click "🔒 Blochează perioada"
9. ✅ Vezi mesaj: "Datele au fost blocate cu succes!"

### Pas 3: Testează Frontend Public

1. Accesează website: http://localhost:3001
2. Selectează același apartament
3. Încearcă să rezervi datele 01-05 Martie 2026
4. ❌ Ar trebui să primești eroare: "Perioada nu este disponibilă"

### Pas 4: Testează Modificarea Prețului

1. Înapoi în dashboard
2. Selectează "Modifică prețul unei date"
3. Alege apartament
4. Setează: Start: 10.03.2026, End: 15.03.2026
5. Preț nou: 200
6. Valută: EUR (sau RON pentru lei)
7. Click "💰 Modifică prețul"
8. ✅ Vezi mesaj: "Prețul a fost modificat cu succes!"

### Pas 5: Verifică Calculul Prețului

**Manual via API:**

```bash
curl "https://dailyguest.online/api/apartment-service/{apartmentId}/calculate-price?checkInDate=2026-03-10&checkOutDate=2026-03-15" \
  -H "x-api-key: your-api-key"
```

**Răspuns așteptat:**

```json
{
  "totalPrice": 1000,
  "nightlyPrices": [
    { "date": "2026-03-10", "price": 200, "currency": "EUR" },
    { "date": "2026-03-11", "price": 200, "currency": "EUR" },
    { "date": "2026-03-12", "price": 200, "currency": "EUR" },
    { "date": "2026-03-13", "price": 200, "currency": "EUR" },
    { "date": "2026-03-14", "price": 200, "currency": "EUR" }
  ],
  "averagePrice": 200,
  "hasOverrides": true,
  "currency": "EUR"
}
```

### Pas 6: Anulează Acțiunile

1. În dashboard, scroll la listele de blocări/prețuri
2. Click **[Șterge]** pe fiecare intrare
3. ✅ Confirmare: "Blocarea/Modificarea a fost ștearsă"
4. Verifică că website-ul acum permite rezervarea

---

## 📊 Cazuri de Utilizare Practice

### 1. **Sezon de Vârf (Sărbători)**

```
Acțiune: Modifică prețul
Dată: 24.12.2026 - 02.01.2027
Preț: +50% față de prețul normal
Rezultat: Prețuri automat mai mari în perioada sărbătorilor
```

### 2. **Renovări/Întreținere**

```
Acțiune: Blochează dată
Dată: 15.03.2026 - 20.03.2026
Motiv: "Renovare bucătărie"
Rezultat: Apartamentul nu poate fi rezervat
```

### 3. **Ofertă Last Minute**

```
Acțiune: Modifică prețul
Dată: Următoarele 7 zile
Preț: -30% reducere
Rezultat: Încurajează rezervările pe termen scurt
```

### 4. **Evenimente Speciale**

```
Acțiune: Modifică prețul
Dată: Weekend concert major (ex: 05-07.04.2026)
Preț: +80% creștere
Valută: EUR sau RON (după preferință)
Rezultat: Profită de cererea crescută
```

### 5. **Prețuri în Lei (RON)**

```
Acțiune: Modifică prețul
Dată: 01.05.2026 - 10.05.2026
Preț: 750 lei
Valută: RON
Rezultat: Ideal pentru piața locală, prețuri în moneda națională
```

---

## 🔐 Securitate

- ✅ Toate endpoint-urile admin necesită autentificare
- ✅ API key verificat prin `ApiKeyGuard`
- ✅ Validare date pe backend (DTO-uri)
- ✅ Protecție împotriva date invalide
- ✅ Rate limiting recomandat pentru producție

---

## 📝 Notițe Importante

1. **Priorități**: Blocările au prioritate INAINTE de orice altă verificare
2. **Suprapuneri**: Dacă există multiple price overrides pentru aceeași dată, se ia ultima setată
3. **Multi-Valute**: Sistem suportă atât EUR cât și RON - selectezi valuta la crearea fiecărui price override
4. **Conversie Valută**: Frontend-ul poate aplica conversie automată dacă este nevoie (recomandat pentru consistență)
5. **Cleanup Automat**: Date trecute pot fi șterse automat cu un cron job (recomandare viitoare)
6. **Performanță**: Index-uri MongoDB create pentru rapiditate
7. **Backward Compatibility**: Prețul de bază al apartamentului rămâne neschimbat

---

## 🐛 Troubleshooting

### "Endpoint-urile nu funcționează"

✅ Verifică că backend-ul rulează pe portul 3000
✅ Verifică că `.env` are `VITE_API_URL=http://localhost:3000` (dev) sau URL-ul corect (prod)

### "Nu văd componenta în dashboard"

✅ Verifică că ai importat `DateManagement` în `AdminApartments.jsx`
✅ Verifică că arrays-ul de apartamente se încarcă corect

### "Prețurile nu se aplică"

✅ Verifică că frontend-ul folosește funcția `calculatePriceWithOverrides()`
✅ Verifică că integrarea este făcută în pagina de checkout

---

## 📞 Suport

Pentru întrebări sau probleme:

1. Verifică acest fișier README
2. Verifică console-ul browser-ului pentru erori
3. Verifică logs backend-ul (terminal)
4. Testează endpoint-urile manual cu Postman/cURL

---

**Status**: ✅ Implementat și Funcțional
**Ultima actualizare**: Februarie 2026
**Versiune**: 1.0
