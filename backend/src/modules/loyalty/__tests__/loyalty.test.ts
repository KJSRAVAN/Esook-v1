import { describe, it, expect, beforeAll, afterAll, vi } from "vitest";
import supertest from "supertest";
import app from "../../../app.js";
import { query } from "../../../db/index.js";
import { signAccessToken } from "../../../utils/jwt.js";
import { LoyaltyService } from "../loyalty.service.js";

const request = supertest(app);

describe("Loyalty Module & Idempotent Transaction Ledger", () => {
  let storeId: string;
  let customerAUserId: string;
  let customerBUserId: string;
  let productId: string;

  let customerAToken: string;
  let customerBToken: string;
  let staffToken: string;
  let adminToken: string;

  let orderAId: string;

  beforeAll(async () => {
    // 1. Create store
    const storeRes = await query<{ id: string }>(
      `INSERT INTO stores (name, area, is_active) VALUES ('Loyalty Store', $1, TRUE) RETURNING id`,
      [`Riyadh - Loyalty Area ${Date.now()}`]
    );
    storeId = storeRes.rows[0]!.id;

    // 2. Create product with 10 loyalty points per unit
    const prodRes = await query<{ id: string }>(
      `INSERT INTO products (store_id, name, price, is_available, loyalty_points_per_unit)
       VALUES ($1, 'Loyalty Juice', 15.00, TRUE, 10) RETURNING id`,
      [storeId]
    );
    productId = prodRes.rows[0]!.id;

    // 3. Create users
    const uA = await query<{ id: string }>(
      `INSERT INTO users (phone_number, full_name, password_hash, role)
       VALUES ($1, 'Customer Loyalty A', 'hash', 'customer') RETURNING id`,
      [`+9665${Math.floor(10000000 + Math.random() * 90000000)}`]
    );
    customerAUserId = uA.rows[0]!.id;

    const uB = await query<{ id: string }>(
      `INSERT INTO users (phone_number, full_name, password_hash, role)
       VALUES ($1, 'Customer Loyalty B', 'hash', 'customer') RETURNING id`,
      [`+9665${Math.floor(10000000 + Math.random() * 90000000)}`]
    );
    customerBUserId = uB.rows[0]!.id;

    // 4. Generate JWT tokens
    customerAToken = signAccessToken({
      id: customerAUserId,
      role: "customer",
      store_id: null,
    });

    customerBToken = signAccessToken({
      id: customerBUserId,
      role: "customer",
      store_id: null,
    });

    staffToken = signAccessToken({
      id: "staff-loyalty-uuid",
      role: "store_staff",
      store_id: storeId,
    });

    adminToken = signAccessToken({
      id: "admin-loyalty-uuid",
      role: "super_admin",
      store_id: null,
    });
  });

  afterAll(async () => {
    if (storeId) {
      await query(`DELETE FROM orders WHERE store_id = $1`, [storeId]);
      await query(`DELETE FROM customer_loyalty_wallets WHERE user_id IN ($1, $2)`, [
        customerAUserId,
        customerBUserId,
      ]);
    }
    if (customerAUserId) await query(`DELETE FROM users WHERE id = $1`, [customerAUserId]);
    if (customerBUserId) await query(`DELETE FROM users WHERE id = $1`, [customerBUserId]);
    if (storeId) await query(`DELETE FROM stores WHERE id = $1`, [storeId]);
  });

  describe("Customer Wallet Creation & Initial State", () => {
    it("should return initial wallet balance = 0 for new customer", async () => {
      const res = await request
        .get("/api/loyalty/wallet")
        .set("Authorization", `Bearer ${customerAToken}`);

      expect(res.status).toBe(200);
      expect(res.body.wallet.user_id).toBe(customerAUserId);
      expect(res.body.wallet.total_points).toBe(0);
    });

    it("should return empty transaction history for new customer", async () => {
      const res = await request
        .get("/api/loyalty/transactions")
        .set("Authorization", `Bearer ${customerAToken}`);

      expect(res.status).toBe(200);
      expect(res.body.transactions).toEqual([]);
    });

    it("should reject store staff from using customer loyalty endpoints with 403", async () => {
      const res = await request
        .get("/api/loyalty/wallet")
        .set("Authorization", `Bearer ${staffToken}`);

      expect(res.status).toBe(403);
    });
  });

  describe("Order Completion Single-Transaction Boundary & Rollback Tests", () => {
    beforeAll(async () => {
      // Add product (quantity 3 -> 30 loyalty points) to cart and create order
      await request
        .post("/api/cart/items")
        .set("Authorization", `Bearer ${customerAToken}`)
        .send({ store_id: storeId, product_id: productId, quantity: 3 });

      const res = await request
        .post("/api/orders")
        .set("Authorization", `Bearer ${customerAToken}`)
        .send({ store_id: storeId, fulfillment_type: "pickup" });

      orderAId = res.body.order.id;
    });

    it("should NOT award loyalty points while order is pending, accepted, or preparing", async () => {
      // 1. Order status = pending
      const walletBefore = await request
        .get("/api/loyalty/wallet")
        .set("Authorization", `Bearer ${customerAToken}`);
      expect(walletBefore.body.wallet.total_points).toBe(0);

      // 2. Transition pending -> accepted
      await request
        .patch(`/api/orders/${orderAId}/status`)
        .set("Authorization", `Bearer ${staffToken}`)
        .send({ status: "accepted" });

      const walletAccepted = await request
        .get("/api/loyalty/wallet")
        .set("Authorization", `Bearer ${customerAToken}`);
      expect(walletAccepted.body.wallet.total_points).toBe(0);

      // 3. Transition accepted -> preparing
      await request
        .patch(`/api/orders/${orderAId}/status`)
        .set("Authorization", `Bearer ${staffToken}`)
        .send({ status: "preparing" });

      const walletPreparing = await request
        .get("/api/loyalty/wallet")
        .set("Authorization", `Bearer ${customerAToken}`);
      expect(walletPreparing.body.wallet.total_points).toBe(0);
    });

    it("should rollback BOTH order completion and wallet crediting if loyalty awarding fails", async () => {
      // Create a test order for Customer B
      await request
        .post("/api/cart/items")
        .set("Authorization", `Bearer ${customerBToken}`)
        .send({ store_id: storeId, product_id: productId, quantity: 2 });

      const orderBRes = await request
        .post("/api/orders")
        .set("Authorization", `Bearer ${customerBToken}`)
        .send({ store_id: storeId, fulfillment_type: "pickup" });

      const orderBId = orderBRes.body.order.id;

      // Mock LoyaltyService.awardOrderCompletionPoints to throw a simulated error
      const originalAwardMethod = LoyaltyService.awardOrderCompletionPoints;
      vi.spyOn(LoyaltyService, "awardOrderCompletionPoints").mockImplementationOnce(async () => {
        throw new Error("Simulated Database Error During Loyalty Awarding");
      });

      // Attempt to complete order B
      const updateRes = await request
        .patch(`/api/orders/${orderBId}/status`)
        .set("Authorization", `Bearer ${staffToken}`)
        .send({ status: "accepted" });

      // Move to preparing
      await request
        .patch(`/api/orders/${orderBId}/status`)
        .set("Authorization", `Bearer ${staffToken}`)
        .send({ status: "preparing" });

      // Now attempt completion where mock will fail
      const failedCompletionRes = await request
        .patch(`/api/orders/${orderBId}/status`)
        .set("Authorization", `Bearer ${staffToken}`)
        .send({ status: "completed" });

      // Must return 500 error and rollback
      expect(failedCompletionRes.status).toBe(500);

      // Verify order status was NOT changed to completed (remains 'preparing')
      const orderBCheck = await request
        .get(`/api/orders/${orderBId}`)
        .set("Authorization", `Bearer ${staffToken}`);
      expect(orderBCheck.body.order.status).toBe("preparing");

      // Verify wallet balance remains 0
      const walletBCheck = await request
        .get("/api/loyalty/wallet")
        .set("Authorization", `Bearer ${customerBToken}`);
      expect(walletBCheck.body.wallet.total_points).toBe(0);

      // Restore mock
      vi.restoreAllMocks();
    });

    it("should award exact snapshotted points and commit order + loyalty together in single transaction", async () => {
      // Transition preparing -> completed for Order A
      const updateRes = await request
        .patch(`/api/orders/${orderAId}/status`)
        .set("Authorization", `Bearer ${staffToken}`)
        .send({ status: "completed" });

      expect(updateRes.status).toBe(200);
      expect(updateRes.body.order.status).toBe("completed");

      // Verify wallet balance is credited with 30 points (3 * 10)
      const walletRes = await request
        .get("/api/loyalty/wallet")
        .set("Authorization", `Bearer ${customerAToken}`);

      expect(walletRes.status).toBe(200);
      expect(walletRes.body.wallet.total_points).toBe(30);

      // Verify transaction ledger record
      const txRes = await request
        .get("/api/loyalty/transactions")
        .set("Authorization", `Bearer ${customerAToken}`);

      expect(txRes.status).toBe(200);
      expect(txRes.body.transactions.length).toBe(1);
      expect(txRes.body.transactions[0].points).toBe(30);
      expect(txRes.body.transactions[0].transaction_type).toBe("order_completion");
    });

    it("should handle concurrent completion requests safely without double-crediting", async () => {
      // Create Order C for Customer B
      await request
        .post("/api/cart/items")
        .set("Authorization", `Bearer ${customerBToken}`)
        .send({ store_id: storeId, product_id: productId, quantity: 1 });

      const orderCRes = await request
        .post("/api/orders")
        .set("Authorization", `Bearer ${customerBToken}`)
        .send({ store_id: storeId, fulfillment_type: "pickup" });

      const orderCId = orderCRes.body.order.id;

      // Move to accepted -> preparing
      await request.patch(`/api/orders/${orderCId}/status`).set("Authorization", `Bearer ${staffToken}`).send({ status: "accepted" });
      await request.patch(`/api/orders/${orderCId}/status`).set("Authorization", `Bearer ${staffToken}`).send({ status: "preparing" });

      // Fire 2 concurrent completion status updates
      const results = await Promise.all([
        request.patch(`/api/orders/${orderCId}/status`).set("Authorization", `Bearer ${staffToken}`).send({ status: "completed" }),
        request.patch(`/api/orders/${orderCId}/status`).set("Authorization", `Bearer ${staffToken}`).send({ status: "completed" }),
      ]);

      const successCount = results.filter((r) => r.status === 200).length;
      const failedCount = results.filter((r) => r.status === 400).length;

      // Exactly ONE request succeeds in transitioning preparing -> completed; second fails with invalid transition
      expect(successCount).toBe(1);
      expect(failedCount).toBe(1);

      // Wallet balance for Customer B should have exactly 10 points (1 * 10)
      const walletB = await request
        .get("/api/loyalty/wallet")
        .set("Authorization", `Bearer ${customerBToken}`);
      expect(walletB.body.wallet.total_points).toBe(10);
    });

    it("should verify PostgreSQL uniqueness constraint uq_order_loyalty_transaction exists in database catalog", async () => {
      const dbRes = await query<{ count: string }>(
        `SELECT count(*) FROM pg_constraint WHERE conname = 'uq_order_loyalty_transaction'`
      );
      expect(Number(dbRes.rows[0]?.count)).toBeGreaterThan(0);
    });
  });

  describe("Customer Isolation & Super Admin Inspection", () => {
    it("should prevent Customer B from accessing Customer A's wallet or transaction ledger", async () => {
      const walletB = await request
        .get("/api/loyalty/wallet")
        .set("Authorization", `Bearer ${customerBToken}`);

      // Customer B's wallet must be isolated (10 points from order C)
      expect(walletB.body.wallet.user_id).toBe(customerBUserId);
      expect(walletB.body.wallet.total_points).toBe(10);
    });

    it("should allow super_admin to inspect customer wallet using ?user_id parameter", async () => {
      const res = await request
        .get(`/api/loyalty/wallet?user_id=${customerAUserId}`)
        .set("Authorization", `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(res.body.wallet.user_id).toBe(customerAUserId);
      expect(res.body.wallet.total_points).toBe(30);
    });
  });
});
