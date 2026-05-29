# Chicken Farm Management System

A production-ready mobile application for chicken farm management with MongoDB backend.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter, Riverpod, GoRouter, Dio, Material 3 |
| Backend | Node.js, Express.js, Mongoose |
| Database | MongoDB Atlas |
| Auth | JWT, bcrypt |
| PDF | pdf + printing packages |

## Project Structure

```
chick/
├── server/          # Node.js REST API
│   ├── controllers/
│   ├── models/
│   ├── routes/
│   ├── services/    # Invoice & stock transaction logic
│   ├── middleware/
│   └── utils/
└── app/             # Flutter mobile app
    └── lib/
        ├── core/
        ├── features/
        ├── models/
        ├── repositories/
        ├── services/
        └── shared/
```

## Quick Start

### Backend

```bash
cd server
cp .env.example .env
# Edit .env with your MongoDB Atlas URI and JWT secret
npm install
npm run seed    # Seed users & clients (stock is added via admin UI)
npm run dev     # Start on http://localhost:3000
```

### Flutter App

```bash
cd app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

> Use `http://localhost:3000/api` for iOS simulator or physical device on same network (replace with your machine IP).

## Demo Credentials

| Role | Email | Password |
|------|-------|----------|
| Admin | admin@chickenfarm.com | admin123 |
| Employee | employee@chickenfarm.com | employee123 |
| Client | client@chickenfarm.com | client123 |

After seeding, sign in as **admin** and add stock from **Stock** (demo stock types are not seeded).

To remove existing demo stock from the database without re-seeding users:

```bash
cd server && npm run clear-stock
```

## API Endpoints

### Auth
- `POST /api/auth/login` — Login
- `POST /api/auth/register` — Register user (admin only)
- `GET /api/auth/me` — Current user
- `POST /api/auth/logout` — Logout

### Clients
- `GET /api/clients` — List clients
- `POST /api/clients` — Create client
- `PUT /api/clients/:id` — Update client
- `DELETE /api/clients/:id` — Delete client

### Stock
- `GET /api/stock` — List stock with low-stock alerts
- `POST /api/stock` — Add stock (IN movement + transaction)
- `PUT /api/stock/:id` — Update pricing/thresholds
- `GET /api/stock/alerts` — Low stock alerts
- `GET /api/stock/movements` — Movement history

### Invoices
- `GET /api/invoices` — List invoices (role-filtered)
- `POST /api/invoices` — Create invoice (stock OUT + transaction)
- `GET /api/invoices/:id` — Invoice details
- `PATCH /api/invoices/:id` — Update payment status or invoice (admin)

### Reports (Admin)
- `GET /api/reports/dashboard` — Dashboard analytics
- `GET /api/treasury` — Main treasury balance (admin only)
- `PATCH /api/treasury` — Set main treasury amount (admin only)
- `GET /api/employees/:id/ledger` — Employee expenses & goods debt (admin)
- `POST /api/employees/:id/ledger/expense` — Add expense (deducts main treasury)
- `POST /api/me/ledger/expense` — Employee records own expense (deducts main treasury)
- `GET /api/me/ledger` — Employee views own debt & expenses
- `GET /api/reports/sales` — Sales report
- `GET /api/reports/revenue` — Daily/monthly revenue
- `GET /api/reports/audit-logs` — Audit trail

## Stock Transaction Rule

Stock is **never** decreased directly. All changes go through `StockMovements`:

1. Validate stock availability
2. Start MongoDB transaction (`session.startTransaction()`)
3. Create invoice
4. Create OUT stock movement(s)
5. Update stock quantity
6. Commit or abort transaction

## Features

- JWT authentication with role-based access (Admin, Employee, Client)
- Professional Material 3 UI with green farm theme
- Dashboard with charts and analytics
- PDF invoice generation with QR code
- Offline caching with Hive
- Low stock alerts
- Audit logging
- Search, filter, pagination

## GitHub

Repository: **https://github.com/es810/chick** (create the empty repo on GitHub, then push — see below).

```powershell
cd c:\chick
gh auth login
gh repo create chick --public --source=. --remote=origin --push
```

If the repo already exists:

```powershell
git push -u origin main
```

`.env` files are not committed; use `server/.env.example` as a template.

## Deploy API to Railway

See **[server/DEPLOY_RAILWAY.md](server/DEPLOY_RAILWAY.md)** for MongoDB Atlas + Railway variables and Flutter `API_BASE_URL`.

Quick check after deploy: `GET https://YOUR-APP.up.railway.app/health`

## Security

- Passwords hashed with bcrypt (12 rounds)
- JWT-protected routes
- Role middleware on all endpoints
- Input validation with express-validator
- MongoDB transactions prevent negative stock
