import { z } from 'zod';

export const updateProfileSchema = z.object({
  name: z.string().min(2).max(100).optional(),
  email: z.string().email().optional(),
});

export const userQuerySchema = z.object({
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().positive().max(100).default(50),
  role: z.enum(['CUSTOMER', 'STAFF', 'MANAGER', 'SUPER_ADMIN']).optional(),
});

export type UpdateProfileDto = z.infer<typeof updateProfileSchema>;
export type UserQueryDto = z.infer<typeof userQuerySchema>;
