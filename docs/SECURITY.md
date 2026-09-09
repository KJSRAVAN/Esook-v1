# Esook Backend — Security

## Auth Threat Model

| Threat | Mitigation |
|---|---|
| OTP brute force | Max 5 attempts per OTP; lock + require fresh code on exceed |
| OTP flooding / cost blowout | Max 3 sends per 10 min per phone number (Redis) |
| Refresh token theft | Rotating tokens; token-reuse detection (family revocation) |
| Password attacks | argon2id hashing for staff passwords |
| JWT secret leak | 15-minute access token lifespan limits exposure window |
| CSRF | Bearer token auth (not cookie); no CSRF surface |
| Input injection | Zod schema validation at every endpoint boundary |
| Mass assignment | `whitelist: true` on global ValidationPipe |

## Input Validation

All endpoints validate at the boundary using Zod schemas before any business
logic runs. Invalid input always returns:
```json
{ "error": { "code": "INVALID_INPUT", "message": "...", "details": [...] } }
```

## Database Security

- Prisma ORM only — zero raw SQL string concatenation
- App DB user: SELECT / INSERT / UPDATE / DELETE only
- Cannot DROP tables, ALTER schema, or TRUNCATE
- Schema migrations run with a separate privileged migration user

## PCI Scope

This backend handles **no payment card data**. All orders are cash on delivery.
No card numbers, PANs, CVVs, or payment credentials transit or are stored here.
PCI scope: **entirely out of scope**.

## Secrets Management

- All credentials in env vars; never committed to source
- `.env.example` is the only committed env file (no values, only keys)
- Production: use Railway environment variables dashboard or a secrets manager

## Audit Log

Every sensitive action writes to `AuditLog`:
- OTP send / verify attempts (channel, masked phone prefix, success/fail)
- Order creation (actorId, orderId, total)
- Order status changes (from/to, actorId)

**Nothing sensitive is logged**: no OTP codes, no passwords, no full phone numbers.

## Dependency Scanning

`.github/workflows/ci.yml` runs `npm audit` on every PR. Enable GitHub Dependabot
alerts in repository settings for automated PR-based dependency updates.
