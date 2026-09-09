import { Injectable, BadRequestException, NotFoundException, Logger } from '@nestjs/common';
import { RedisService } from '@shared/redis/redis.service';
import { PrismaService } from '@shared/database/prisma.service';
import { Cart, CartItem } from './cart.schemas';

const CART_TTL = 7 * 24 * 60 * 60; // 7 days
const cartKey = (userId: string) => `cart:${userId}`;

/**
 * Redis-backed cart. Redis is a convenience layer, NOT the source of truth.
 * If Redis is unavailable:
 *  - getCart() returns an empty cart (user re-adds items on next load)
 *  - addItem / updateItem fail with a 503 (cart writes need Redis to persist)
 * The cart is intentionally ephemeral — it becomes permanent only when
 * POST /orders is called and the order is written to Postgres.
 */
@Injectable()
export class CartService {
  private readonly logger = new Logger(CartService.name);

  constructor(
    private readonly redis: RedisService,
    private readonly prisma: PrismaService,
  ) {}

  async getCart(userId: string): Promise<Cart> {
    try {
      const raw = await this.redis.get(cartKey(userId));
      if (!raw) return this.emptyCart(userId);
      return JSON.parse(raw) as Cart;
    } catch (err) {
      this.logger.warn(`Redis unavailable reading cart for ${userId}: ${(err as Error).message}`);
      return this.emptyCart(userId);
    }
  }

  async addItem(userId: string, itemId: string, quantity: number): Promise<Cart> {
    const item = await this.prisma.item.findUnique({
      where: { id: itemId, isAvailable: true },
    });
    if (!item) throw new NotFoundException('Item not found or not available');

    const cart = await this.getCart(userId);

    if (cart.storeId && cart.storeId !== item.storeId) {
      throw new BadRequestException({
        code: 'CART_STORE_MISMATCH',
        message: 'Your cart contains items from a different store. Clear it first.',
      });
    }

    const existing = cart.items.find((i) => i.itemId === itemId);
    if (existing) {
      existing.quantity += quantity;
    } else {
      cart.items.push({
        itemId: item.id,
        name: item.name,
        price: Number(item.price),
        quantity,
        imageUrl: item.imageUrl ?? undefined,
      });
    }

    cart.storeId = item.storeId;
    cart.subtotal = this.computeSubtotal(cart.items);
    cart.updatedAt = new Date().toISOString();

    await this.saveCart(userId, cart);
    return cart;
  }

  async updateItem(userId: string, itemId: string, quantity: number): Promise<Cart> {
    const cart = await this.getCart(userId);
    const idx = cart.items.findIndex((i) => i.itemId === itemId);
    if (idx === -1) throw new NotFoundException('Item not in cart');

    if (quantity === 0) {
      cart.items.splice(idx, 1);
    } else {
      cart.items[idx].quantity = quantity;
    }

    if (cart.items.length === 0) cart.storeId = null;
    cart.subtotal = this.computeSubtotal(cart.items);
    cart.updatedAt = new Date().toISOString();

    await this.saveCart(userId, cart);
    return cart;
  }

  async clearCart(userId: string): Promise<void> {
    await this.redis.del(cartKey(userId)).catch(() => {
      // Best-effort clear — if Redis is down the TTL will expire it anyway
      this.logger.warn(`Could not clear cart for ${userId} — Redis may be unavailable`);
    });
  }

  private emptyCart(userId: string): Cart {
    return { userId, storeId: null, items: [], subtotal: 0, updatedAt: new Date().toISOString() };
  }

  private computeSubtotal(items: CartItem[]): number {
    return items.reduce((sum, i) => sum + i.price * i.quantity, 0);
  }

  private async saveCart(userId: string, cart: Cart): Promise<void> {
    await this.redis.set(cartKey(userId), JSON.stringify(cart), 'EX', CART_TTL);
  }
}