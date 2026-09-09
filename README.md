# Esook Backend v2

Production-grade NestJS backend for the Esook multi-store e-commerce platform.

## Stack

| Layer | Tech |
|---|---|
| API | NestJS (TypeScript) + Prisma |
| Database | PostgreSQL (Supabase free tier) |
| Cache | Redis (Upstash free tier) |
| Auth | OTP via WhatsApp Cloud API, JWT access + rotating refresh tokens |
| Deploy | Railway (free tier) |

## Quick Start (local)

### Prerequisites
- Node.js 20+
- Docker + Docker Compose

### 1. Clone and install
```bash
git clone <repo>
cd esook-backend
npm install
```

### 2. Configure environment
```bash
cp .env.example .env
# Edit .env -- at minimum set DATABASE_URL and REDIS_URL
```

### 3. Start services
```bash
docker compose -f docker/docker-compose.yml up postgres redis -d
```

### 4. Run database migrations and seed
```bash
npm run db:generate
npm run db:migrate
npm run db:seed
```

### 5. Start the API
```bash
npm run start:dev
```

API: http://localhost:4000
Swagger: http://localhost:4000/api/docs
Health: http://localhost:4000/health

---

## Full Docker stack
```bash
docker compose -f docker/docker-compose.yml up --build
```

---

## Default seed credentials

| Role | Email | Password |
|---|---|---|
| SUPER_ADMIN | admin@esook.store | Admin@1234 |
| MANAGER (Riyadh) | manager.riyadh@esook.store | Manager@1234 |
| MANAGER (Jeddah) | manager.jeddah@esook.store | Manager@1234 |
| STAFF | staff.riyadh@esook.store | Staff@1234 |

Customer login is phone OTP (WhatsApp or email fallback) -- no password.

---

## Tests
```bash
# Unit tests
npm run test

# Unit tests with coverage
npm run test:cov

# E2E tests (requires postgres + redis running)
npm run test:e2e
```

---

## Key API Endpoints

```
POST   /auth/otp/send          Customer: request OTP
POST   /auth/otp/verify        Customer: verify OTP -> tokens
POST   /auth/staff/login       Staff/Admin: email+password -> tokens
POST   /auth/refresh           Rotate refresh token
POST   /auth/logout            Revoke refresh token
GET    /auth/me                Get current user

GET    /stores                 List stores (public)
GET    /stores/:id/items       Browse catalog (public)
GET    /stores/:id/categories  List categories (public)

POST   /cart/items             Add to cart
GET    /cart                   View cart
PATCH  /cart/items/:itemId     Update quantity
DELETE /cart                   Clear cart

POST   /orders                 Place order (X-Idempotency-Key header)
GET    /orders/my              My order history
GET    /orders/store/:storeId  Store orders (STAFF+)
PATCH  /orders/:id/status      Update order status (STAFF+)

POST   /coupons/validate       Validate coupon (public)
GET    /health                 Health check
```

---

## Environment Variables

See `.env.example` for all required variables. Required for production:
- `DATABASE_URL` -- PostgreSQL connection string
- `REDIS_URL` -- Redis connection string  
- `JWT_ACCESS_SECRET` -- min 32 chars, random
- `JWT_REFRESH_SECRET` -- min 32 chars, random, different from access secret
- `WHATSAPP_PHONE_NUMBER_ID` -- Meta Business phone number ID
- `WHATSAPP_ACCESS_TOKEN` -- Meta Cloud API access token

---

## Deployment (Railway)

1. Create a Railway project
2. Add PostgreSQL and Redis plugins
3. Connect your GitHub repo
4. Set environment variables in Railway dashboard
5. Railway auto-deploys on push to `main`

Railway detects `railway.toml` and uses the Dockerfile automatically.

---

## Architecture

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

## Security

See [docs/SECURITY.md](docs/SECURITY.md)
