import type { PoolClient } from "pg";
import { pool, query } from "../../db/index.js";

export interface WalletResponse {
  user_id: string;
  total_points: number;
  updated_at?: Date;
}

export interface LoyaltyTransactionResponse {
  id: string;
  user_id: string;
  order_id: string;
  order_number?: string;
  points: number;
  transaction_type: string;
  created_at: Date;
}

export class LoyaltyService {
  /**
   * Get or initialize customer loyalty wallet balance.
   */
  static async getWallet(userId: string): Promise<WalletResponse> {
    const res = await query<WalletResponse>(
      `SELECT user_id, total_points, updated_at FROM customer_loyalty_wallets WHERE user_id = $1`,
      [userId]
    );

    if (res.rows.length === 0) {
      return {
        user_id: userId,
        total_points: 0,
      };
    }

    return res.rows[0]!;
  }

  /**
   * List loyalty transactions for a customer.
   */
  static async getTransactions(userId: string): Promise<LoyaltyTransactionResponse[]> {
    const res = await query<LoyaltyTransactionResponse>(
      `SELECT lt.id, lt.user_id, lt.order_id, lt.points, lt.transaction_type, lt.created_at,
              o.order_number
       FROM loyalty_transactions lt
       JOIN orders o ON o.id = lt.order_id
       WHERE lt.user_id = $1
       ORDER BY lt.created_at DESC`,
      [userId]
    );

    return res.rows;
  }

  /**
   * Atomic, Idempotent Order Completion Loyalty Awarding.
   * Runs inside an existing or new PostgreSQL transaction client:
   * 1. Locks the order FOR UPDATE.
   * 2. Checks points_earned from order snapshot.
   * 3. Checks uq_order_loyalty_transaction constraint to prevent double-crediting.
   * 4. Upserts customer_loyalty_wallets and inserts loyalty_transactions.
   */
  static async awardOrderCompletionPoints(
    orderId: string,
    existingClient?: PoolClient
  ): Promise<boolean> {
    const client = existingClient || (await pool.connect());
    const isExternalTx = Boolean(existingClient);

    try {
      if (!isExternalTx) {
        await client.query("BEGIN");
      }

      // 1. Lock order row and read snapshotted points_earned and customer_id
      const orderRes = await client.query<{
        id: string;
        user_id: string;
        points_earned: number;
        status: string;
      }>(
        `SELECT id, user_id, points_earned, status FROM orders WHERE id = $1 FOR UPDATE`,
        [orderId]
      );

      const order = orderRes.rows[0];
      if (!order) {
        if (!isExternalTx) await client.query("ROLLBACK");
        return false;
      }

      // If points_earned is 0, no points to award
      if (order.points_earned <= 0) {
        if (!isExternalTx) await client.query("COMMIT");
        return true;
      }

      // 2. Check if loyalty points for this order were already awarded (idempotency check)
      const existingTx = await client.query<{ id: string }>(
        `SELECT id FROM loyalty_transactions WHERE order_id = $1 AND transaction_type = 'order_completion'`,
        [order.id]
      );

      if (existingTx.rows.length > 0) {
        // Points already awarded! Skip to prevent double-crediting
        if (!isExternalTx) await client.query("COMMIT");
        return true;
      }

      // 3. Upsert wallet balance atomically
      await client.query(
        `INSERT INTO customer_loyalty_wallets (user_id, total_points)
         VALUES ($1, $2)
         ON CONFLICT (user_id)
         DO UPDATE SET total_points = customer_loyalty_wallets.total_points + EXCLUDED.total_points,
                      updated_at = CURRENT_TIMESTAMP`,
        [order.user_id, order.points_earned]
      );

      // 4. Insert loyalty transaction (guaranteed unique by uq_order_loyalty_transaction constraint)
      await client.query(
        `INSERT INTO loyalty_transactions (user_id, order_id, points, transaction_type)
         VALUES ($1, $2, $3, 'order_completion')
         ON CONFLICT (order_id, transaction_type) DO NOTHING`,
        [order.user_id, order.id, order.points_earned]
      );

      if (!isExternalTx) {
        await client.query("COMMIT");
      }

      return true;
    } catch (err) {
      if (!isExternalTx) {
        await client.query("ROLLBACK");
      }
      throw err;
    } finally {
      if (!isExternalTx) {
        client.release();
      }
    }
  }
}
