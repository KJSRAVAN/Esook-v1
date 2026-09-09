import { z } from 'zod';

export const createItemSchema = z.object({
  name: z.string().min(1).max(200),
  description: z.string().max(2000).optional(),
  price: z.number().positive().multipleOf(0.01),
  categoryId: z.string().optional(),
  imageUrl: z.string().url().optional(),
  sortOrder: z.number().int().default(0),
});

export const updateItemSchema = createItemSchema.partial().extend({
  isAvailable: z.boolean().optional(),
});

export const createCategorySchema = z.object({
  name: z.string().min(1).max(100),
  sortOrder: z.number().int().default(0),
});

export const updateCategorySchema = createCategorySchema.partial();

export const catalogQuerySchema = z.object({
  categoryId: z.string().optional(),
  search: z.string().max(100).optional(),
  available: z.enum(['true', 'false']).optional(),
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().positive().max(100).default(50),
});

export type CreateItemDto = z.infer<typeof createItemSchema>;
export type UpdateItemDto = z.infer<typeof updateItemSchema>;
export type CreateCategoryDto = z.infer<typeof createCategorySchema>;
export type CatalogQueryDto = z.infer<typeof catalogQuerySchema>;

