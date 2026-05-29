# Deploy API to Railway

## Prerequisites

1. [Railway account](https://railway.app/)
2. **MongoDB Atlas** cluster (free tier is fine) — Railway does not include MongoDB by default
3. GitHub repo **or** [Railway CLI](https://docs.railway.app/develop/cli)

---

## Option A — Deploy from GitHub (recommended)

1. Push this project to GitHub (only the `server` folder is required, but the whole repo is fine).
2. In Railway: **New Project** → **Deploy from GitHub repo** → select your repo.
3. **Root Directory** can stay at repo root — the root `Dockerfile` and `railway.toml` build `server/`.  
   (Optional: set Root Directory to `server` and use `server/railway.toml` instead.)
4. **Variables** → add:

| Variable | Example |
|----------|---------|
| `NODE_ENV` | `production` |
| `MONGODB_URI` | `mongodb+srv://USER:PASS@cluster.mongodb.net/chicken_farm?retryWrites=true&w=majority` |
| `JWT_SECRET` | long random string (32+ chars) |
| `JWT_EXPIRES_IN` | `7d` |
| `BCRYPT_ROUNDS` | `12` |

5. In MongoDB Atlas → **Network Access** → add `0.0.0.0/0` (or Railway’s egress IPs) so the API can connect.
6. Deploy. Copy your public URL, e.g. `https://chicken-farm-api-production.up.railway.app`.
7. API base for the app: `https://YOUR-URL/api` (test: `https://YOUR-URL/health`).

### Seed production database (once)

From your PC (with `MONGODB_URI` pointing at Atlas):

```bash
cd server
npm install
# set MONGODB_URI and JWT_SECRET in .env to the same values as Railway
npm run seed
```

---

## Option B — Deploy with Railway CLI (no GitHub)

```powershell
npm install -g @railway/cli
cd c:\chick\server
railway login
railway init
railway variables set NODE_ENV=production
railway variables set MONGODB_URI="mongodb+srv://..."
railway variables set JWT_SECRET="your-long-secret"
railway up
railway domain
```

`railway up` uploads the `server` folder and builds it.

---

## Point the Flutter app at Railway

Build or run with your Railway URL:

```bash
cd app
flutter run --dart-define=API_BASE_URL=https://YOUR-APP.up.railway.app/api
```

Release APK:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://YOUR-APP.up.railway.app/api
```

APK output: `app/build/app/outputs/flutter-apk/app-release.apk`

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Build fails | Push latest repo (root `Dockerfile` + `railway.toml`) |
| **Healthcheck failed** | Set `MONGODB_URI` + `JWT_SECRET`; Atlas → **Network Access** → `0.0.0.0/0` |
| Crash on start | `JWT_SECRET` must not be empty; `NODE_ENV=production` |
| MongoDB timeout | URL-encode special characters in password (`@` → `%40`) |
| App cannot login | Use `https://.../api` (with `/api`), not bare domain |

Check **Deploy Logs**. If you see `JWT_SECRET must be set` or `MONGODB_URI must be set`, add variables and redeploy.
