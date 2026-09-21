import { z } from 'zod';

export const sendOtpSchema = z.object({
  phone: z
    .string()
    .regex(/^\+?[1-9]\d{7,14}$/, 'Invalid phone number format. Use E.164 format e.g. +966501234567'),
  email: z.string().email().optional(),
  name: z.string().min(2).max(100).optional(),
});

export const verifyOtpSchema = z.object({
  phone: z
    .string()
    .regex(/^\+?[1-9]\d{7,14}$/, 'Invalid phone number format'),
  code: z
    .string()
    .length(6, 'OTP must be exactly 6 digits')
    .regex(/^\d{6}$/, 'OTP must be numeric'),
});

// Staff login accepts either email OR phone — drivers use phone, staff use email
export const staffLoginSchema = z.object({
  email: z.string().email().optional(),
  phone: z.string().regex(/^\+?[1-9]\d{7,14}$/).optional(),
  password: z.string().min(8),
}).refine(
  (d) => !!d.email || !!d.phone,
  { message: 'Either email or phone is required', path: ['email'] },
);

// Dedicated customer registration schema
export const customerSignupSchema = z.object({
  name: z.string().trim().min(2, 'Name must be at least 2 characters').max(100),
  email: z.string().trim().email('Invalid email address').toLowerCase(),
  phone: z
    .string()
    .trim()
    .regex(
      /^\+?[1-9]\d{7,14}$/,
      'Invalid phone number format. Use E.164 format e.g. +966501234567 or +919876543210',
    ),
  password: z.string().min(8, 'Password must be at least 8 characters'),
});

// Customer email OTP verification schema
export const customerVerifyEmailSchema = z.object({
  email: z.string().trim().email('Invalid email address').toLowerCase(),
  code: z
    .string()
    .trim()
    .length(6, 'OTP must be exactly 6 digits')
    .regex(/^\d{6}$/, 'OTP must be numeric'),
});

// Dedicated customer login schema (accepts email + password OR phone + password)
export const customerLoginSchema = z.object({
  email: z.string().trim().email('Invalid email address').toLowerCase().optional(),
  phone: z.string().trim().regex(/^\+?[1-9]\d{7,14}$/, 'Invalid phone number format').optional(),
  password: z.string().min(8, 'Password must be at least 8 characters'),
}).refine(
  (d) => !!d.email || !!d.phone,
  { message: 'Either email or phone is required', path: ['email'] },
);

// Customer request password reset schema
export const customerRequestPasswordResetSchema = z.object({
  email: z.string().trim().email('Invalid email address').toLowerCase(),
});

// Customer reset password schema
export const customerResetPasswordSchema = z.object({
  email: z.string().trim().email('Invalid email address').toLowerCase(),
  code: z
    .string()
    .trim()
    .length(6, 'OTP must be exactly 6 digits')
    .regex(/^\d{6}$/, 'OTP must be numeric'),
  newPassword: z.string().min(8, 'Password must be at least 8 characters'),
});

export const registerDriverSchema = z.object({
  name: z.string().min(2).max(100),
  phone: z.string().regex(/^\+?[1-9]\d{7,14}$/, 'Invalid phone number format'),
  password: z.string().min(8, 'Password must be at least 8 characters'),
});

export const refreshTokenSchema = z.object({
  refreshToken: z.string().min(1),
});

export const logoutSchema = z.object({
  refreshToken: z.string().min(1),
});

export type SendOtpDto = z.infer<typeof sendOtpSchema>;
export type VerifyOtpDto = z.infer<typeof verifyOtpSchema>;
export type StaffLoginDto = z.infer<typeof staffLoginSchema>;
export type CustomerSignupDto = z.infer<typeof customerSignupSchema>;
export type CustomerVerifyEmailDto = z.infer<typeof customerVerifyEmailSchema>;
export type CustomerLoginDto = z.infer<typeof customerLoginSchema>;
export type CustomerRequestPasswordResetDto = z.infer<typeof customerRequestPasswordResetSchema>;
export type CustomerResetPasswordDto = z.infer<typeof customerResetPasswordSchema>;
export type RegisterDriverDto = z.infer<typeof registerDriverSchema>;
export type RefreshTokenDto = z.infer<typeof refreshTokenSchema>;
export type LogoutDto = z.infer<typeof logoutSchema>;