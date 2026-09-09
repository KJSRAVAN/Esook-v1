# Esook Backend — Architecture

## Overview

Modular monolith deployed in containers. Internally domain-isolated (each module
has its own controller/service/repository), deployed as one unit today.
Each domain can be extracted into its own service later without touching others.

```
+-------------------------------------------------------+
|               Cloudflare (TLS, WAF, DDoS)             |
+-------------------------+-----------------------------+
                          |
                          v
+-------------------------------------------------------+
|              NestJS API  :4000                        |
|  modules: auth | catalog | cart | orders | coupons   |
|           users | stores | health                    |
+------------------+-------------------+---------------+
                   |                   |
                   v                   v
          +-----------+         +-----------+
          |PostgreSQL |         |  Redis    |
          |(Supabase) |         |(Upstash)  |
          +-----------+         +-----------+
```

## Component Choices

| Component | Choice | Reason |
|---|---|---|
| API | NestJS (TypeScript) | Module isolation, DI, Swagger, same JS ecosystem as v1 |
| Database | PostgreSQL + Prisma ORM | Relational integrity; no raw SQL anywhere |
| Cache | Redis (ioredis) | OTP store (hashed), cart cache, rate limiting |
| Auth | Passport + JWT | Short-lived access tokens; rotating refresh tokens |
| Deploy | Railway free tier | Docker + managed PostgreSQL + Redis; GitHub CI/CD |
| OTP primary | WhatsApp Cloud API | No Saudi SMS (SUDI) approval needed |
| OTP fallback | Nodemailer SMTP | Works for any user with email |

## Auth Model

```
Customer:  POST /auth/otp/send (phone)
           -> WhatsApp OTP (fallback: email OTP)
           POST /auth/otp/verify (phone + 6-digit code)
           -> access_token (JWT, 15 min) + refresh_token (UUID, 7 days)

Staff:     POST /auth/staff/login (email + argon2 password)
           -> same token pair

Refresh:   POST /auth/refresh (refresh_token)
           -> new access_token + new refresh_token (old revoked)

Logout:    POST /auth/logout (refresh_token) -> revoke token
```

Refresh tokens are stored SHA-256 hashed in the `RefreshToken` table.
Token reuse detection: using a revoked token revokes ALL sessions for that user.

## Data Flow: Customer Order

```
Customer -> POST /auth/otp/send         -> WhatsApp OTP sent
Customer -> POST /auth/otp/verify       -> JWT issued
Customer -> GET  /stores                -> browse stores
Customer -> GET  /stores/:id/items      -> browse catalog (public)
Customer -> POST /cart/items            -> Redis cart (no DB write)
Customer -> POST /orders                -> DB transaction:
                                            validate items
                                            apply coupon (atomic decrement)
                                            snapshot prices
                                            create Order + OrderItems
                                            write AuditLog
Staff    -> GET  /orders/store/:id      -> see PENDING orders
Staff    -> PATCH /orders/:id/status    -> ACCEPTED | PREPARING | READY | DELIVERED
                                            write AuditLog
```

## Idempotency

`POST /orders` accepts an `X-Idempotency-Key` header. If a key is replayed, the
original order response is returned (no double-order, no double coupon use).

## OTP Security

- 6-digit code, cryptographically random
- Stored as SHA-256 hash in Redis (never plaintext)
- 5-minute expiry
- Max 5 verification attempts before lock (requires new code)
- Max 3 OTP requests per 10 minutes per phone (Redis rate limit)

## Scaling Path

The monolith is ready to split: each module touches only its own Prisma models
and has a clear public service interface. When traffic justifies it:
- Extract `auth` -> auth-service
- Extract `orders` -> orders-service
- Same Docker images, new orchestrator (K8s)
