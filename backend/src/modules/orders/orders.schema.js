import { z } from 'zod';

export const createOrderSchema = z.object({
  storeId: z.string().min(1),
  items: z.array(z.object({
    itemId: z.string().min(1),
    quantity: z.number().int().min(1)
  })).min(1),
  fulfillment: z.enum(['PICKUP', 'DELIVERY']),
  deliveryAddress: z.string().optional(),
  couponCode: z.string().optional(),
  notes: z.string().optional()
});

export const updateOrderStatusSchema = z.object({
  status: z.enum(['ACCEPTED', 'REJECTED', 'READY', 'DELIVERED'])
});
