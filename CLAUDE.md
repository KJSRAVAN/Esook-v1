# CLAUDE.md — Esook Backend Project Spec

> This file is the standing project spec for all Claude Code sessions on this backend.
> Read this file first in every session before touching any code.

---

## Project Summary

Multi-store e-commerce platform backend (Gulf/Saudi market). Architecture: modular monolith in
NestJS (TypeScript) + Prisma + PostgreSQL + Redis. Deployed on Railway (free tier).

- **Customers** log in via phone OTP (WhatsApp primary, email fallback)
- **Staff/Admin** log in via email + argon2 password
- Order flow: customer places order -> store staff sees and accepts/rejects/updates it
- No payment gateway. Cash on delivery.
- No inventory stock tracking. Staff toggles `isAvailable` on items.

---

## Hard Constraints (MUST -- flag, never silently violate)

1. **No source file over 300 lines.** Split proactively.
2. **No domain reaching into another domain's internals.** Go through the service layer.
3. **No raw SQL.** Prisma ORM only.
4. **No secrets in code.** Env vars only. Keep `.env.example` current.
5. **Every new endpoint:** OpenAPI entry + Zod input validation + at least one test.
6. **Every component** independently addressable by its own config/URL.
7. **State-changing endpoints** (orders, coupon use) are transactional and idempotent.
8. Prefer boring, well-documented libraries.

---

## File Structure

```
src/
  modules/
    auth/           -- OTP providers, JWT, refresh tokens
      otp/          -- OtpProvider interface + WhatsApp + email implementations
      guards/       -- JwtAuthGuard, RolesGuard, JwtStrategy
      token/        -- TokenService (access + refresh tokens)
    catalog/        -- Products, categories (public read, MANAGER write)
    stores/         -- Area -> Store management
    cart/           -- Redis-backed cart (no DB writes per item add)
    orders/         -- Order lifecycle, audit log
    coupons/        -- Coupon management and validation
    users/          -- Profile management
    health/         -- GET /health (DB + Redis status)
  shared/
    config/         -- Zod env schema + ConfigModule
    database/       -- PrismaService singleton
    redis/          -- RedisService (ioredis)
    filters/        -- GlobalExceptionFilter (standard error shape)
    interceptors/   -- TimeoutInterceptor (30s)
    middleware/     -- RequestIdMiddleware
    pipes/          -- ZodValidationPipe
prisma/
  schema.prisma     -- Source of truth for DB schema
  seed.ts           -- Dev seed data
docs/
  ARCHITECTURE.md
  SECURITY.md
docker/
  Dockerfile        -- Multi-stage build
  docker-compose.yml -- api + postgres + redis
```

---

## Session Checklist

When starting a coding session:

1. Re-read this file first.
2. Check which module/domain the task touches and stay in that boundary.
3. Enforce the 300-line rule -- split proactively into `*_controller`, `*_service`, `*_repository`.
4. Update `docs/openapi.yaml` (or Swagger decorators) and tests as part of the same change.
5. For anything touching orders/OTP: confirm idempotency/transaction compliance per Section 8 of the project spec.
6. Flag (don't silently skip) anything that conflicts with the security or reliability rules.

---

## Standard Error Shape

All endpoints return errors in this format:
```json
{ "error": { "code": "SNAKE_CASE_CODE", "message": "Human message", "details": [] } }
```

Implemented in `src/shared/filters/http-exception.filter.ts`.

---

## Auth Summary

- Customer: `POST /auth/otp/send` (phone) -> WhatsApp OTP -> `POST /auth/otp/verify` -> JWT pair
- Staff: `POST /auth/staff/login` (email + password) -> JWT pair
- Access token: 15 min, JWT (HS256)
- Refresh token: 7 days, UUID stored SHA-256 hashed in `RefreshToken` table, rotated on use
- Guards: `JwtAuthGuard` (passport-jwt), `RolesGuard` + `@Roles()` decorator
- OTP: 6 digits, SHA-256 hashed in Redis, 5 min TTL, 5 attempts max, 3 sends per 10 min rate limit

---

## Delivery Checkpoints Completed

- [x] Checkpoint 1: Foundations (Docker, Prisma schema, Redis, shared infra)
- [x] Checkpoint 2: Auth + OTP (WhatsApp + email providers, guards, token rotation)
- [x] Checkpoint 3: Catalog (public read, MANAGER write, category management)
- [x] Checkpoint 4: Cart + Orders (Redis cart, transactional order creation, idempotency)
- [ ] Checkpoint 5: Background jobs (BullMQ processors for async OTP delivery, notifications)
- [ ] Checkpoint 6: Hardening (OWASP audit, load test, failure-mode test)
- [ ] Checkpoint 7: Docs + Deploy (finalized openapi.yaml, Railway deploy, monitoring)
- [ ] Checkpoint 8: End-to-end pass with mobile teammate

---

## Deploy Target

Railway (free tier). Config: `railway.toml`. 
- PostgreSQL: Supabase free tier recommended for managed DB
- Redis: Upstash free tier recommended (10K req/day, 256MB)
