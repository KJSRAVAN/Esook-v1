import { z } from 'zod';

export const addToCartSchema = z.object({
  itemId: z.string().min(1),
  quantity: z.number().int().positive().max(99),
});

export const updateCartItemSchema = z.object({
  quantity: z.number().int().min(0).max(99), // 0 = remove
});

export type AddToCartDto = z.infer<typeof addToCartSchema>;
export type UpdateCartItemDto = z.infer<typeof updateCartItemSchema>;

export interface CartItem {
  itemId: string;
  name: string;
  price: number;
  quantity: number;
  imageUrl?: string;
}

export interface Cart {
  userId: string;
  storeId: string | null;
  items: CartItem[];
  subtotal: number;
  updatedAt: string;
}
