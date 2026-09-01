import { z } from 'zod';

export const createItemSchema = z.object({
  name: z.string().min(1),
  description: z.string().optional(),
  price: z.number().min(0),
  imageUrl: z.string().url().optional(),
  category: z.string().optional()
});

export const updateItemSchema = z.object({
  isAvailable: z.boolean().optional(),
  price: z.number().min(0).optional(),
  description: z.string().optional()
});
