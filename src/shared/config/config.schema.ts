import { z } from 'zod';

export const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().default(4000),

  // Database
  DATABASE_URL: z.string().url(),
  // DIRECT_URL bypasses the connection pooler for Prisma migrations (required by Supabase Supavisor)
  DIRECT_URL: z.string().url().optional(),

  // Redis — accept both standard REDIS_URL and Upstash's variable name
  // Priority: REDIS_URL > UPSTASH_REDIS_REST_URL
  // Note: Upstash REST URL (https://...) won't work with ioredis.
  // You need the ioredis-compatible URL from the Upstash dashboard
  // (Connect → ioredis tab): rediss://default:TOKEN@host:6379
  REDIS_URL: z.string().optional(),
  UPSTASH_REDIS_REST_URL: z.string().optional(),

  // JWT
  JWT_ACCESS_SECRET: z.string().min(32),
  JWT_REFRESH_SECRET: z.string().min(32),
  JWT_ACCESS_EXPIRES_IN: z.string().default('15m'),
  JWT_REFRESH_EXPIRES_IN: z.string().default('7d'),

  // OTP
  OTP_EXPIRY_SECONDS: z.coerce.number().default(300),
  OTP_MAX_ATTEMPTS: z.coerce.number().default(5),
  OTP_RATE_LIMIT_MAX: z.coerce.number().default(3),
  OTP_RATE_LIMIT_WINDOW_SECONDS: z.coerce.number().default(600),

  // WhatsApp
  WHATSAPP_API_URL: z.string().default('https://graph.facebook.com/v19.0'),
  WHATSAPP_PHONE_NUMBER_ID: z.string().optional(),
  WHATSAPP_ACCESS_TOKEN: z.string().optional(),
  WHATSAPP_OTP_TEMPLATE_NAME: z.string().default('otp_verification'),
  WHATSAPP_OTP_TEMPLATE_LANG: z.string().default('en'),

  // SMTP (email OTP fallback)
  SMTP_HOST: z.string().optional(),
  SMTP_PORT: z.coerce.number().default(587),
  SMTP_SECURE: z.coerce.boolean().default(false),
  SMTP_USER: z.string().optional(),
  SMTP_PASS: z.string().optional(),
  EMAIL_FROM: z.string().default('Esook <noreply@esook.store>'),

  // CORS
  CORS_ORIGINS: z.string().default('http://localhost:3000'),
}).refine(
  (data) => !!(data.REDIS_URL || data.UPSTASH_REDIS_REST_URL),
  { message: 'Either REDIS_URL or UPSTASH_REDIS_REST_URL must be set', path: ['REDIS_URL'] },
);

export type AppConfig = z.infer<typeof envSchema>;