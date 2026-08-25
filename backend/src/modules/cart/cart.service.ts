import { pool, query } from "../../db/index.js";
import type { AddCartItemInput, UpdateCartItemInput } from "./cart.validation.js";

export interface CartItemDetail {
  item_id: string;
  product_id: string;
  product_name: string;
  unit_price: string;
  image_url: string | null;
  is_available: boolean;
  loyalty_points_per_unit: number;
  quantity: number;
  item_subtotal: string;
}

export interface CartResponse {
  cart_id: string | null;
  store: {
    id: string;
    name: string;
    area: string;
    is_active: boolean;
  };
  items: CartItemDetail[];
  subtotal: string;
  itemCount: number;
  hasUnavailableItems: boolean;
}

export class CartService {
  /**
   * Retrieve customer's cart for a selected store.
   * Calculates subtotal server-side based on current product prices.
   * Flags unavailable items without deleting them.
   */
  static async getCart(userId: string, storeId: string): Promise<CartResponse> {
    const storeRes = await query<{
      id: string;
      name: string;
      area: string;
      is_active: boolean;
    }>(`SELECT id, name, area, is_active FROM stores WHERE id = $1`, [storeId]);

    if (storeRes.rows.length === 0 || !storeRes.rows[0]?.is_active) {
      const err = new Error("Store not found or unavailable");
      (err as unknown as { status: number }).status = 404;
      throw err;
    }

    const store = storeRes.rows[0]!;

    const cartRes = await query<{ id: string }>(
      `SELECT id FROM carts WHERE user_id = $1 AND store_id = $2`,
      [userId, storeId]
    );

    if (cartRes.rows.length === 0) {
      return {
        cart_id: null,
        store: {
          id: store.id,
          name: store.name,
          area: store.area,
          is_active: store.is_active,
        },
        items: [],
        subtotal: "0.00",
        itemCount: 0,
        hasUnavailableItems: false,
      };
    }

    const cartId = cartRes.rows[0]!.id;

    const itemsRes = await query<{
      item_id: string;
      product_id: string;
      quantity: number;
      product_name: string;
      unit_price: string;
      image_url: string | null;
      is_available: boolean;
      loyalty_points_per_unit: number;
    }>(
      `SELECT ci.id AS item_id, ci.product_id, ci.quantity,
              p.name AS product_name, p.price::text AS unit_price, p.image_url,
              p.is_available, p.loyalty_points_per_unit
       FROM cart_items ci
       JOIN products p ON p.id = ci.product_id AND p.store_id = ci.store_id
       WHERE ci.cart_id = $1
       ORDER BY ci.created_at ASC`,
      [cartId]
    );

    let totalSubtotalNum = 0;
    let totalCount = 0;
    let hasUnavailable = false;

    const items: CartItemDetail[] = itemsRes.rows.map((row) => {
      const priceNum = Number(row.unit_price) || 0;
      const itemSubtotalNum = priceNum * row.quantity;

      totalSubtotalNum += itemSubtotalNum;
      totalCount += row.quantity;

      if (!row.is_available) {
        hasUnavailable = true;
      }

      return {
        item_id: row.item_id,
        product_id: row.product_id,
        product_name: row.product_name,
        unit_price: Number(row.unit_price).toFixed(2),
        image_url: row.image_url,
        is_available: row.is_available,
        loyalty_points_per_unit: row.loyalty_points_per_unit,
        quantity: row.quantity,
        item_subtotal: itemSubtotalNum.toFixed(2),
      };
    });

    return {
      cart_id: cartId,
      store: {
        id: store.id,
        name: store.name,
        area: store.area,
        is_active: store.is_active,
      },
      items,
      subtotal: totalSubtotalNum.toFixed(2),
      itemCount: totalCount,
      hasUnavailableItems: hasUnavailable,
    };
  }

  /**
   * Add item to customer's store cart (Atomic Transaction).
   * Increments quantity if product is already in cart.
   */
  static async addCartItem(
    userId: string,
    input: AddCartItemInput
  ): Promise<CartResponse> {
    const client = await pool.connect();
    try {
      await client.query("BEGIN");

      // 1. Verify store exists & active
      const storeRes = await client.query<{ is_active: boolean }>(
        `SELECT is_active FROM stores WHERE id = $1`,
        [input.store_id]
      );

      if (storeRes.rows.length === 0 || !storeRes.rows[0]?.is_active) {
        const err = new Error("Store not found or unavailable");
        (err as unknown as { status: number }).status = 404;
        throw err;
      }

      // 2. Verify product exists, belongs to store, and is available
      const prodRes = await client.query<{
        id: string;
        store_id: string;
        is_available: boolean;
      }>(`SELECT id, store_id, is_available FROM products WHERE id = $1`, [
        input.product_id,
      ]);

      if (prodRes.rows.length === 0) {
        const err = new Error("Product not found");
        (err as unknown as { status: number }).status = 404;
        throw err;
      }

      const product = prodRes.rows[0]!;

      if (product.store_id !== input.store_id) {
        const err = new Error("Product does not belong to the selected store");
        (err as unknown as { status: number }).status = 400;
        throw err;
      }

      if (!product.is_available) {
        const err = new Error("Product is currently unavailable");
        (err as unknown as { status: number }).status = 400;
        throw err;
      }

      // 3. Upsert cart row for customer & store
      const cartRes = await client.query<{ id: string }>(
        `INSERT INTO carts (user_id, store_id)
         VALUES ($1, $2)
         ON CONFLICT (user_id, store_id)
         DO UPDATE SET updated_at = CURRENT_TIMESTAMP
         RETURNING id`,
        [userId, input.store_id]
      );

      const cartId = cartRes.rows[0]!.id;

      // 4. Upsert item with store_id composite FK enforcement
      await client.query(
        `INSERT INTO cart_items (cart_id, product_id, store_id, quantity)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (cart_id, product_id)
         DO UPDATE SET quantity = cart_items.quantity + EXCLUDED.quantity, updated_at = CURRENT_TIMESTAMP`,
        [cartId, input.product_id, input.store_id, input.quantity]
      );

      await client.query("COMMIT");
    } catch (err) {
      await client.query("ROLLBACK");
      throw err;
    } finally {
      client.release();
    }

    return this.getCart(userId, input.store_id);
  }

  /**
   * Update quantity of an item in customer's cart for a store.
   */
  static async updateCartItemQuantity(
    userId: string,
    input: UpdateCartItemInput
  ): Promise<CartResponse> {
    const cartRes = await query<{ id: string }>(
      `SELECT id FROM carts WHERE user_id = $1 AND store_id = $2`,
      [userId, input.store_id]
    );

    if (cartRes.rows.length === 0) {
      const err = new Error("Item not found in cart");
      (err as unknown as { status: number }).status = 404;
      throw err;
    }

    const cartId = cartRes.rows[0]!.id;

    const updateRes = await query(
      `UPDATE cart_items
       SET quantity = $1, updated_at = CURRENT_TIMESTAMP
       WHERE cart_id = $2 AND product_id = $3 AND store_id = $4
       RETURNING id`,
      [input.quantity, cartId, input.product_id, input.store_id]
    );

    if ((updateRes.rowCount ?? 0) === 0) {
      const err = new Error("Item not found in cart");
      (err as unknown as { status: number }).status = 404;
      throw err;
    }

    return this.getCart(userId, input.store_id);
  }

  /**
   * Remove a single item from customer's store cart.
   */
  static async removeCartItem(
    userId: string,
    storeId: string,
    productId: string
  ): Promise<CartResponse> {
    await query(
      `DELETE FROM cart_items
       WHERE cart_id = (SELECT id FROM carts WHERE user_id = $1 AND store_id = $2)
         AND product_id = $3`,
      [userId, storeId, productId]
    );

    return this.getCart(userId, storeId);
  }

  /**
   * Clear all items from customer's store cart.
   */
  static async clearCart(userId: string, storeId: string): Promise<CartResponse> {
    await query(
      `DELETE FROM cart_items
       WHERE cart_id = (SELECT id FROM carts WHERE user_id = $1 AND store_id = $2)`,
      [userId, storeId]
    );

    return this.getCart(userId, storeId);
  }
}
