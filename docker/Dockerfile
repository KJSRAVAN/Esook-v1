# ---- Build stage ----
FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./
COPY prisma ./prisma/

RUN npm ci

COPY . .

RUN npm run db:generate
RUN npm run build

# ---- Production stage ----
FROM node:20-alpine AS production

WORKDIR /app

COPY package*.json ./
COPY prisma ./prisma/

# Install prod deps + keep prisma CLI for migrate deploy at startup
RUN npm ci --omit=dev && npm cache clean --force

# Generate Prisma client in this stage too
RUN npm run db:generate

# Copy compiled app from build stage
COPY --from=builder /app/dist ./dist

# Non-root user for security
RUN addgroup -S esook && adduser -S esook -G esook
USER esook

EXPOSE 4000

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD wget -qO- http://localhost:4000/health || exit 1

# prisma is in devDependencies so we call it via npx from node_modules/.bin
CMD ["sh", "-c", "node_modules/.bin/prisma migrate deploy && node dist/main"]