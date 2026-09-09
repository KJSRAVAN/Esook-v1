import { z } from 'zod';

export const createCouponSchema = z.object({
  code: z.string().min(3).max(50).toUpperCase(),
  discountType: z.enum(['PERCENT', 'FLAT']),
  discountValue: z.number().positive(),
  minOrderValue: z.number().positive().optional(),
  maxUses: z.number().int().positive().optional(),
  expiresAt: z.string().datetime().optional(),
});

export const updateCouponSchema = createCouponSchema.partial().extend({
  isActive: z.boolean().optional(),
});

export const validateCouponSchema = z.object({
  code: z.string().min(1),
  orderTotal: z.number().positive(),
});

export type CreateCouponDto = z.infer<typeof createCouponSchema>;
export type UpdateCouponDto = z.infer<typeof updateCouponSchema>;
export type ValidateCouponDto = z.infer<typeof validateCouponSchema>;
