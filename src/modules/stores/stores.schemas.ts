import { z } from 'zod';

export const createStoreSchema = z.object({
  name: z.string().min(2).max(100),
  areaId: z.string().min(1),
  address: z.string().max(500).optional(),
  phone: z.string().optional(),
});

export const updateStoreSchema = createStoreSchema.partial().extend({
  isActive: z.boolean().optional(),
});

export const storeParamSchema = z.object({
  storeId: z.string().min(1),
});

export type CreateStoreDto = z.infer<typeof createStoreSchema>;
export type UpdateStoreDto = z.infer<typeof updateStoreSchema>;
