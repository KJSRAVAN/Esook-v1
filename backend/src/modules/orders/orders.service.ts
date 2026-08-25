import crypto from "node:crypto";
import { pool, query } from "../../db/index.js";
import { LoyaltyService } from "../loyalty/loyalty.service.js";
import type {
  CreateOrderInput,
  UpdateOrderStatusInput,
  OrderStatus,
} from "./orders.validation.js";

export interface OrderItemDetail {
  product_id: string;
  product_name: string;
  unit_price: string;
  quantity: number;
  subtotal: string;
  loyalty_points_per_unit: number;
  subtotal_points: number;
}

export interface OrderResponse {
  id: string;
  order_number?: string;
  customer_id: string;
  customer?: {
    full_name: string;
    phone_number: string;
  };
  store_id: string;
  store_name?: string;
  status: OrderStatus;
  fulfillment_type: "delivery" | "pickup";
  delivery_address: string | null;
  total_amount: string;
  points_earned: number;
  items: OrderItemDetail[];
  created_at: Date;
  updated_at: Date;
}

const ALLOWED_STATUS_TRANSITIONS: Record<OrderStatus, Set<OrderStatus>> = {
  pending: new Set(["accepted", "rejected", "cancelled"]),
  accepted: new Set(["preparing", "cancelled"]),
  preparing: new Set(["out_for_delivery", "completed", "cancelled"]),
  out_for_delivery: new Set(["completed", "cancelled"]),
  completed: new Set(),
  cancelled: new Set(),
  rejected: new Set(),
};

/**
 * Generate collision-safe order number using cryptographic randomness.
 */
function generateOrderNumber(): string {
  const timePart = Date.now().toString(36).toUpperCase();
  const randomPart = crypto.randomBytes(4).toString("hex").toUpperCase();
  return `ESK-${timePart}-${randomPart}`;
}

export class OrdersService {
  /**
   * Atomic Order Creation with SELECT ... FOR UPDATE Cart Row Locking.
   * Runs in a single PostgreSQL transaction:
   * 1. Verifies store is active.
   * 2. Locks customer's cart row (`SELECT ... FOR UPDATE`) to prevent concurrent order creation.
   * 3. Reads cart items and locks product rows (`FOR SHARE`).
   * 4. Validates product availability and store matching.
   * 5. Performs exact cent-integer decimal arithmetic for unit_price, subtotal, and total_amount.
   * 6. Snapshots product data into order_items.
   * 7. Clears customer cart items.
   * 8. Commits transaction or rolls back on any error.
   */
  static async createOrder(
    customerId: string,
    input: CreateOrderInput
  ): Promise<OrderResponse> {
    const client = await pool.connect();
    try {
      await client.query("BEGIN");

      // 1. Verify store exists and is active
      const storeRes = await client.query<{ is_active: boolean; name: string }>(
        `SELECT name, is_active FROM stores WHERE id = $1`,
        [input.store_id]
      );

      if (storeRes.rows.length === 0 || !storeRes.rows[0]?.is_active) {
        const err = new Error("Store not found or unavailable");
        (err as unknown as { status: number }).status = 404;
        throw err;
      }

      const storeName = storeRes.rows[0]!.name;

      // 2. Lock customer's cart row FOR UPDATE to prevent concurrent order creation race conditions
      const cartRes = await client.query<{ id: string }>(
        `SELECT id FROM carts WHERE user_id = $1 AND store_id = $2 FOR UPDATE`,
        [customerId, input.store_id]
      );

      if (cartRes.rows.length === 0) {
        const err = new Error("Cart is empty");
        (err as unknown as { status: number }).status = 400;
        throw err;
      }

      const cartId = cartRes.rows[0]!.id;

      // 3. Read cart items and lock product rows FOR SHARE
      const itemsRes = await client.query<{
        product_id: string;
        quantity: number;
        product_name: string;
        unit_price: string;
        product_store_id: string;
        is_available: boolean;
        loyalty_points_per_unit: number;
      }>(
        `SELECT ci.product_id, ci.quantity,
                p.name AS product_name, p.price::text AS unit_price,
                p.store_id AS product_store_id, p.is_available,
                p.loyalty_points_per_unit
         FROM cart_items ci
         JOIN products p ON p.id = ci.product_id
         WHERE ci.cart_id = $1
         FOR SHARE OF p`,
        [cartId]
      );

      if (itemsRes.rows.length === 0) {
        const err = new Error("Cart is empty");
        (err as unknown as { status: number }).status = 400;
        throw err;
      }

      // 4. Validate products & calculate totals using exact integer cent arithmetic
      let totalAmountCents = 0;
      let totalPointsEarned = 0;
      const orderItemsToInsert: OrderItemDetail[] = [];

      for (const item of itemsRes.rows) {
        if (item.product_store_id !== input.store_id) {
          const err = new Error("Product does not belong to the selected store");
          (err as unknown as { status: number }).status = 400;
          throw err;
        }

        if (!item.is_available) {
          const err = new Error(`Product '${item.product_name}' is currently unavailable`);
          (err as unknown as { status: number }).status = 400;
          throw err;
        }

        // Exact cent integer arithmetic to prevent floating point inaccuracies
        const unitPriceCents = Math.round(Number(item.unit_price) * 100);
        const subtotalCents = unitPriceCents * item.quantity;
        const subtotalPoints = item.loyalty_points_per_unit * item.quantity;

        totalAmountCents += subtotalCents;
        totalPointsEarned += subtotalPoints;

        orderItemsToInsert.push({
          product_id: item.product_id,
          product_name: item.product_name,
          unit_price: (unitPriceCents / 100).toFixed(2),
          quantity: item.quantity,
          subtotal: (subtotalCents / 100).toFixed(2),
          loyalty_points_per_unit: item.loyalty_points_per_unit,
          subtotal_points: subtotalPoints,
        });
      }

      const totalAmountFormatted = (totalAmountCents / 100).toFixed(2);
      const orderNumber = generateOrderNumber();

      // 5. Create Order row
      const orderRes = await client.query<{
        id: string;
        order_number: string;
        customer_id: string;
        store_id: string;
        status: "pending";
        fulfillment_type: "delivery" | "pickup";
        delivery_address: string | null;
        total_amount: string;
        points_earned: number;
        created_at: Date;
        updated_at: Date;
      }>(
        `INSERT INTO orders (order_number, user_id, store_id, status, fulfillment_type, delivery_address, subtotal, delivery_fee, total_amount, points_earned)
         VALUES ($1, $2, $3, 'pending', $4, $5, $6, 0.00, $6, $7)
         RETURNING id, order_number, user_id AS customer_id, store_id, status, fulfillment_type, delivery_address, total_amount::text, points_earned, created_at, updated_at`,
        [
          orderNumber,
          customerId,
          input.store_id,
          input.fulfillment_type,
          input.delivery_address || null,
          totalAmountFormatted,
          totalPointsEarned,
        ]
      );

      const orderRow = orderRes.rows[0]!;

      // 6. Insert Order Items (with composite FK enforcement)
      for (const item of orderItemsToInsert) {
        await client.query(
          `INSERT INTO order_items (order_id, product_id, store_id, product_name, unit_price, quantity, loyalty_points_per_unit, subtotal_price, subtotal_points)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
          [
            orderRow.id,
            item.product_id,
            input.store_id,
            item.product_name,
            item.unit_price,
            item.quantity,
            item.loyalty_points_per_unit,
            item.subtotal,
            item.subtotal_points,
          ]
        );
      }

      // 7. Clear customer cart items for this store
      await client.query(`DELETE FROM cart_items WHERE cart_id = $1`, [cartId]);

      await client.query("COMMIT");

      return {
        id: orderRow.id,
        order_number: orderRow.order_number,
        customer_id: orderRow.customer_id,
        store_id: orderRow.store_id,
        store_name: storeName,
        status: orderRow.status,
        fulfillment_type: orderRow.fulfillment_type,
        delivery_address: orderRow.delivery_address,
        total_amount: Number(orderRow.total_amount).toFixed(2),
        points_earned: orderRow.points_earned,
        items: orderItemsToInsert,
        created_at: orderRow.created_at,
        updated_at: orderRow.updated_at,
      };
    } catch (err) {
      await client.query("ROLLBACK");
      throw err;
    } finally {
      client.release();
    }
  }

  /**
   * List orders based on user role and store scoping.
   * Delivery riders MUST have assigned store_id and are restricted to their store.
   */
  static async listOrders(
    userId: string,
    role: string,
    userStoreId?: string | null,
    storeIdFilter?: string
  ): Promise<OrderResponse[]> {
    let sql = `
      SELECT o.id, o.order_number, o.user_id AS customer_id, o.store_id, o.status, o.fulfillment_type,
             o.delivery_address, o.total_amount::text, o.points_earned,
             o.created_at, o.updated_at,
             s.name AS store_name,
             u.full_name AS customer_name, u.phone_number AS customer_phone
      FROM orders o
      JOIN stores s ON s.id = o.store_id
      JOIN users u ON u.id = o.user_id
    `;
    const params: unknown[] = [];

    if (role === "customer") {
      sql += ` WHERE o.user_id = $1`;
      params.push(userId);
    } else if (role === "store_staff" || role === "store_manager") {
      if (!userStoreId) {
        const err = new Error("Staff account is not assigned to a store");
        (err as unknown as { status: number }).status = 403;
        throw err;
      }
      sql += ` WHERE o.store_id = $1`;
      params.push(userStoreId);
    } else if (role === "delivery_rider") {
      if (!userStoreId) {
        const err = new Error("Forbidden: Delivery rider is not assigned to a store");
        (err as unknown as { status: number }).status = 403;
        throw err;
      }
      sql += ` WHERE o.store_id = $1`;
      params.push(userStoreId);
    } else if (role === "super_admin") {
      if (storeIdFilter) {
        sql += ` WHERE o.store_id = $1`;
        params.push(storeIdFilter);
      }
    }

    sql += ` ORDER BY o.created_at DESC`;

    const result = await query<{
      id: string;
      order_number: string;
      customer_id: string;
      store_id: string;
      status: OrderStatus;
      fulfillment_type: "delivery" | "pickup";
      delivery_address: string | null;
      total_amount: string;
      points_earned: number;
      created_at: Date;
      updated_at: Date;
      store_name: string;
      customer_name: string;
      customer_phone: string;
    }>(sql, params);

    const orders: OrderResponse[] = [];

    for (const row of result.rows) {
      const itemsRes = await query<{
        product_id: string;
        product_name: string;
        unit_price: string;
        quantity: number;
        subtotal: string;
        loyalty_points_per_unit: number;
        subtotal_points: number;
      }>(
        `SELECT product_id, product_name, unit_price::text, quantity,
                subtotal_price::text AS subtotal, loyalty_points_per_unit, subtotal_points
         FROM order_items
         WHERE order_id = $1
         ORDER BY created_at ASC`,
        [row.id]
      );

      orders.push({
        id: row.id,
        order_number: row.order_number,
        customer_id: row.customer_id,
        customer: {
          full_name: row.customer_name,
          phone_number: row.customer_phone,
        },
        store_id: row.store_id,
        store_name: row.store_name,
        status: row.status,
        fulfillment_type: row.fulfillment_type,
        delivery_address: row.delivery_address,
        total_amount: Number(row.total_amount).toFixed(2),
        points_earned: row.points_earned,
        items: itemsRes.rows.map((item) => ({
          ...item,
          unit_price: Number(item.unit_price).toFixed(2),
          subtotal: Number(item.subtotal).toFixed(2),
        })),
        created_at: row.created_at,
        updated_at: row.updated_at,
      });
    }

    return orders;
  }

  /**
   * Get single order by ID with strict ownership and role validation.
   * Delivery riders MUST have a non-null store_id and match order.store_id.
   */
  static async getOrderById(
    orderId: string,
    userId: string,
    role: string,
    userStoreId?: string | null
  ): Promise<OrderResponse> {
    const result = await query<{
      id: string;
      order_number: string;
      customer_id: string;
      store_id: string;
      status: OrderStatus;
      fulfillment_type: "delivery" | "pickup";
      delivery_address: string | null;
      total_amount: string;
      points_earned: number;
      created_at: Date;
      updated_at: Date;
      store_name: string;
      customer_name: string;
      customer_phone: string;
    }>(
      `SELECT o.id, o.order_number, o.user_id AS customer_id, o.store_id, o.status, o.fulfillment_type,
              o.delivery_address, o.total_amount::text, o.points_earned,
              o.created_at, o.updated_at,
              s.name AS store_name,
              u.full_name AS customer_name, u.phone_number AS customer_phone
       FROM orders o
       JOIN stores s ON s.id = o.store_id
       JOIN users u ON u.id = o.user_id
       WHERE o.id = $1`,
      [orderId]
    );

    const orderRow = result.rows[0];
    if (!orderRow) {
      const err = new Error("Order not found");
      (err as unknown as { status: number }).status = 404;
      throw err;
    }

    // Role-based access control & store isolation checks
    if (role === "customer") {
      if (orderRow.customer_id !== userId) {
        const err = new Error("Order not found");
        (err as unknown as { status: number }).status = 404;
        throw err;
      }
    } else if (role === "store_staff" || role === "store_manager" || role === "delivery_rider") {
      if (!userStoreId || orderRow.store_id !== userStoreId) {
        const err = new Error("Forbidden: Cannot access orders belonging to another store");
        (err as unknown as { status: number }).status = 403;
        throw err;
      }
    }

    const itemsRes = await query<{
      product_id: string;
      product_name: string;
      unit_price: string;
      quantity: number;
      subtotal: string;
      loyalty_points_per_unit: number;
      subtotal_points: number;
    }>(
      `SELECT product_id, product_name, unit_price::text, quantity,
              subtotal_price::text AS subtotal, loyalty_points_per_unit, subtotal_points
       FROM order_items
       WHERE order_id = $1
       ORDER BY created_at ASC`,
      [orderId]
    );

    return {
      id: orderRow.id,
      order_number: orderRow.order_number,
      customer_id: orderRow.customer_id,
      customer: {
        full_name: orderRow.customer_name,
        phone_number: orderRow.customer_phone,
      },
      store_id: orderRow.store_id,
      store_name: orderRow.store_name,
      status: orderRow.status,
      fulfillment_type: orderRow.fulfillment_type,
      delivery_address: orderRow.delivery_address,
      total_amount: Number(orderRow.total_amount).toFixed(2),
      points_earned: orderRow.points_earned,
      items: itemsRes.rows.map((item) => ({
        ...item,
        unit_price: Number(item.unit_price).toFixed(2),
        subtotal: Number(item.subtotal).toFixed(2),
      })),
      created_at: orderRow.created_at,
      updated_at: orderRow.updated_at,
    };
  }

  /**
   * Store Staff / Manager / Rider / Admin: Update order status.
   * Enforces single PostgreSQL transaction using ONE PoolClient:
   * BEGIN
   *   1. Lock order row FOR UPDATE.
   *   2. Validate role & store ownership.
   *   3. Validate state machine transition.
   *   4. UPDATE orders SET status = 'completed'.
   *   5. LoyaltyService.awardOrderCompletionPoints(orderId, client) inside SAME transaction.
   * COMMIT
   * If ANY step fails: ROLLBACK everything (order status NOT changed, wallet NOT credited).
   */
  static async updateOrderStatus(
    orderId: string,
    input: UpdateOrderStatusInput,
    userId: string,
    role: string,
    userStoreId?: string | null
  ): Promise<OrderResponse> {
    const client = await pool.connect();
    try {
      await client.query("BEGIN");

      // 1. Lock order row FOR UPDATE
      const result = await client.query<{
        id: string;
        order_number: string;
        user_id: string;
        store_id: string;
        status: OrderStatus;
        fulfillment_type: "delivery" | "pickup";
        delivery_address: string | null;
        total_amount: string;
        points_earned: number;
        created_at: Date;
        updated_at: Date;
      }>(
        `SELECT id, order_number, user_id, store_id, status, fulfillment_type,
                delivery_address, total_amount::text, points_earned, created_at, updated_at
         FROM orders
         WHERE id = $1
         FOR UPDATE`,
        [orderId]
      );

      const orderRow = result.rows[0];
      if (!orderRow) {
        const err = new Error("Order not found");
        (err as unknown as { status: number }).status = 404;
        throw err;
      }

      // Role-based access control & store isolation checks
      if (role === "customer") {
        if (orderRow.user_id !== userId) {
          const err = new Error("Order not found");
          (err as unknown as { status: number }).status = 404;
          throw err;
        }
      } else if (
        role === "store_staff" ||
        role === "store_manager" ||
        role === "delivery_rider"
      ) {
        if (!userStoreId || orderRow.store_id !== userStoreId) {
          const err = new Error(
            "Forbidden: Cannot access orders belonging to another store"
          );
          (err as unknown as { status: number }).status = 403;
          throw err;
        }
      }

      // State machine transition validation
      const allowedNext = ALLOWED_STATUS_TRANSITIONS[orderRow.status];
      if (!allowedNext || !allowedNext.has(input.status)) {
        const err = new Error(
          `Invalid status transition from '${orderRow.status}' to '${input.status}'`
        );
        (err as unknown as { status: number }).status = 400;
        throw err;
      }

      // 2. Update orders status inside transaction
      await client.query(
        `UPDATE orders
         SET status = $1, updated_at = CURRENT_TIMESTAMP
         WHERE id = $2`,
        [input.status, orderRow.id]
      );

      // 3. If input.status === 'completed', award loyalty points inside SAME transaction
      if (input.status === "completed") {
        await LoyaltyService.awardOrderCompletionPoints(orderRow.id, client);
      }

      await client.query("COMMIT");
    } catch (err) {
      await client.query("ROLLBACK");
      throw err;
    } finally {
      client.release();
    }

    return this.getOrderById(orderId, userId, role, userStoreId);
  }
}
