# Tally

Track every dinar you get and every dinar you spend.
Flutter app + Express / MongoDB API, amounts in DA.

```
tally/
├── backend/   Express + MongoDB API
└── app/       Flutter mobile app
```

## What it does

- **Accounts** — sign up, log in, stay logged in, change password, delete account
- **Money in** — amount, where it came from (salary, freelance, gift…), wallet, date, note
- **Money out** — amount, what it was for (food, transport, bills…), wallet, date, note
- **Wallets** — cash, CCP, bank, BaridiMob… each with its own balance
- **Categories & sources** — add, rename, recolour, delete your own
- **Monthly budget** — how much is left to spend this month
- **Activity** — search notes, filter by type, category and month, swipe to delete
- **Stats** — spending / income by category (donut) and the last 6 months (bars)
- Light, dark and automatic themes. No images anywhere — icons only.

---

## 1. Run the backend

Needs Node 18+ and a MongoDB database (local, or a free MongoDB Atlas cluster).

```bash
cd backend
npm install
cp .env.example .env      # then open .env and fill it in
npm run dev
```

In `.env`, set at least:

| Variable | What to put |
|---|---|
| `MONGO_URI` | Your MongoDB connection string |
| `JWT_ACCESS_SECRET` | A long random string. Generate one: `node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"` |

The server refuses to start if these are missing or the secret is shorter than 32 characters.

Check it works: open `http://localhost:5000/api/health` → `{"ok":true}`.

**Run the tests** (downloads a temporary MongoDB the first time, no database needed):

```bash
npm test
```

## 2. Run the app

Needs Flutter 3.22 or newer.

The platform folders (android/ios) aren't included except for the Android manifest and its network config. Generate the rest once — this keeps the existing files:

```bash
cd app
flutter create --project-name tally_app --org com.softwebelevation --platforms=android,ios .
flutter pub get
```

Then open `app/.env` and set where the API lives:

| Running on | `API_URL` |
|---|---|
| Android emulator, backend on your PC | `http://10.0.2.2:5000/api` (default) |
| iOS simulator | `http://localhost:5000/api` |
| Real phone / production | `https://your-api.onrender.com/api` |

```bash
flutter run
```

`app/.env` is bundled inside the app, so anyone with the APK can read it. Only put the API address there — never secrets.

**Real phone against your PC:** Android blocks plain `http://` except for the emulator addresses. Either deploy the API with HTTPS (Render, Railway…) or add your PC's LAN IP to `app/android/app/src/main/res/xml/network_security_config.xml`. On iOS you'd also need to allow local networking in `Info.plist` (`NSAppTransportSecurity` → `NSAllowsLocalNetworking`).

---

## API

All routes are under `/api`. Everything except `/auth/*` and `/health` needs `Authorization: Bearer <accessToken>`.

| Method | Route | |
|---|---|---|
| POST | `/auth/register` | `{name, email, password}` → user + tokens |
| POST | `/auth/login` | `{email, password}` → user + tokens |
| POST | `/auth/refresh` | `{refreshToken}` → new token pair (old one stops working) |
| POST | `/auth/logout` | `{refreshToken}` |
| GET / PATCH / DELETE | `/users/me` | profile, `{name, monthlyBudget}`, delete needs `{password}` |
| PATCH | `/users/me/password` | `{currentPassword, newPassword}` |
| GET / POST | `/categories` | `{name, type: income\|expense, icon, color}` |
| PATCH / DELETE | `/categories/:id` | |
| GET / POST | `/wallets` | `{name, icon, color, initialBalance}` — GET includes live balances |
| PATCH / DELETE | `/wallets/:id` | |
| GET | `/transactions` | `?type&category&wallet&from&to&q&page&limit` (limit ≤ 100) |
| POST | `/transactions` | `{type, amount, category, wallet, note?, date?}` |
| GET / PATCH / DELETE | `/transactions/:id` | |
| GET | `/stats/summary` | `?from&to` → income, expense, net, balance, budget |
| GET | `/stats/by-category` | `?type&from&to` → totals and % per category |
| GET | `/stats/trend` | `?months=6` → income vs expense per month |

## Security

Built with the secure-coding checklist applied throughout:

- Passwords hashed with bcrypt (12 rounds); login takes the same time whether or not the email exists, and returns the same error
- Short-lived access tokens (15 min, HS256 pinned, issuer/audience checked) + refresh tokens that are random, stored only as SHA-256 hashes, single-use (rotated on every refresh) and expire after 30 days
- Changing your password logs out every other device
- Every query is scoped to the logged-in user, including updates and deletes — another user's IDs just return "not found". Category and wallet ownership is checked before a transaction can use them
- Every request body is validated with zod and unknown fields are rejected, which blocks NoSQL operator injection (`{"$ne": null}`) and mass assignment (`user`, `passwordHash`…)
- Rate limits on login (per IP and per email), sign-up, refresh, password change and account deletion, plus a general API limit
- helmet security headers, 20 KB body limit, CORS closed to browsers unless you list origins, max page size, regex-escaped search
- Generic error messages to clients, details only in server logs; no passwords or tokens are logged
- In the app, tokens live in the Android Keystore / iOS Keychain (flutter_secure_storage), cleartext HTTP is blocked except for local dev addresses, and app backups are disabled

Before going live, set `NODE_ENV=production`, `TRUST_PROXY=1` if you're behind a proxy (Render, Railway, Nginx), and serve the API over HTTPS only.
