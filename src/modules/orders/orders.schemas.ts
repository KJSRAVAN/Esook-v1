import { z } from 'zod';

export const createOrderSchema = z.object({
  storeId: z.string().min(1),
  fulfillment: z.enum(['PICKUP', 'DELIVERY']),
  deliveryAddress: z.string().max(500).optional(),
  couponCode: z.string().max(50).optional(),
  notes: z.string().max(1000).optional(),
  items: z.array(
    z.object({
      itemId: z.string().min(1),
      quantity: z.number().int().positive().max(99),
    }),
  ).min(1, 'Order must contain at least one item'),
}).refine(
  (data) => data.fulfillment !== 'DELIVERY' || !!data.deliveryAddress,
  { message: 'deliveryAddress is required for DELIVERY orders', path: ['deliveryAddress'] },
);

export const updateOrderStatusSchema = z.object({
  status: z.enum(['ACCEPTED', 'REJECTED', 'PREPARING', 'READY', 'OUT_FOR_DELIVERY', 'DELIVERED', 'CANCELLED']),
  rejectedReason: z.string().max(500).optional(),
});

export const orderQuerySchema = z.object({
  status: z.enum(['PENDING', 'ACCEPTED', 'REJECTED', 'PREPARING', 'READY', 'OUT_FOR_DELIVERY', 'DELIVERED', 'CANCELLED']).optional(),
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().positive().max(100).default(20),
});

export type CreateOrderDto = z.infer<typeof createOrderSchema>;
export type UpdateOrderStatusDto = z.infer<typeof updateOrderStatusSchema>;
export type OrderQueryDto = z.infer<typeof orderQuerySchema>;
