import { describe, it, expect, beforeAll, afterAll } from "vitest";
import supertest from "supertest";
import app from "../../../app.js";
import { query } from "../../../db/index.js";
import { signAccessToken } from "../../../utils/jwt.js";

const request = supertest(app);

describe("Orders Module Hardening & Concurrency & State Machine Tests", () => {
  let storeAId: string;
  let storeBId: string;
  let inactiveStoreId: string;

  let customerAToken: string;
  let customerBToken: string;
  let staffAToken: string;
  let staffBToken: string;
  let managerBToken: string;
  let riderAToken: string;
  let riderBToken: string;
  let riderNoStoreToken: string;
  let adminToken: string;

  let customerAUserId: string;
  let customerBUserId: string;

  let productA1Id: string;
  let productA2UnavailableId: string;
  let productB1Id: string;

  beforeAll(async () => {
    // 1. Create stores
    const resA = await query<{ id: string }>(
      `INSERT INTO stores (name, area, is_active) VALUES ('Order Store A', $1, TRUE) RETURNING id`,
      [`Riyadh - Order Area A ${Date.now()}`]
    );
    storeAId = resA.rows[0]!.id;

    const resB = await query<{ id: string }>(
      `INSERT INTO stores (name, area, is_active) VALUES ('Order Store B', $1, TRUE) RETURNING id`,
      [`Riyadh - Order Area B ${Date.now()}`]
    );
    storeBId = resB.rows[0]!.id;

    const resInactive = await query<{ id: string }>(
      `INSERT INTO stores (name, area, is_active) VALUES ('Order Inactive Store', $1, FALSE) RETURNING id`,
      [`Riyadh - Order Inactive Area ${Date.now()}`]
    );
    inactiveStoreId = resInactive.rows[0]!.id;

    // 2. Create products
    const pA1 = await query<{ id: string }>(
      `INSERT INTO products (store_id, name, price, is_available, loyalty_points_per_unit)
       VALUES ($1, 'Store A Organic Bread', 8.50, TRUE, 4) RETURNING id`,
      [storeAId]
    );
    productA1Id = pA1.rows[0]!.id;

    const pA2 = await query<{ id: string }>(
      `INSERT INTO products (store_id, name, price, is_available, loyalty_points_per_unit)
       VALUES ($1, 'Store A Out of Stock Butter', 14.00, FALSE, 8) RETURNING id`,
      [storeAId]
    );
    productA2UnavailableId = pA2.rows[0]!.id;

    const pB1 = await query<{ id: string }>(
      `INSERT INTO products (store_id, name, price, is_available, loyalty_points_per_unit)
       VALUES ($1, 'Store B Fresh Juice', 10.00, TRUE, 5) RETURNING id`,
      [storeBId]
    );
    productB1Id = pB1.rows[0]!.id;

    // 3. Create users
    const uA = await query<{ id: string }>(
      `INSERT INTO users (phone_number, full_name, password_hash, role)
       VALUES ($1, 'Customer Order A', 'hash', 'customer') RETURNING id`,
      [`+9665${Math.floor(10000000 + Math.random() * 90000000)}`]
    );
    customerAUserId = uA.rows[0]!.id;

    const uB = await query<{ id: string }>(
      `INSERT INTO users (phone_number, full_name, password_hash, role)
       VALUES ($1, 'Customer Order B', 'hash', 'customer') RETURNING id`,
      [`+9665${Math.floor(10000000 + Math.random() * 90000000)}`]
    );
    customerBUserId = uB.rows[0]!.id;

    // 4. Generate JWTs
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

    staffAToken = signAccessToken({
      id: "staff-order-a",
      role: "store_staff",
      store_id: storeAId,
    });

    staffBToken = signAccessToken({
      id: "staff-order-b",
      role: "store_staff",
      store_id: storeBId,
    });

    managerBToken = signAccessToken({
      id: "manager-order-b",
      role: "store_manager",
      store_id: storeBId,
    });

    riderAToken = signAccessToken({
      id: "rider-order-a",
      role: "delivery_rider",
      store_id: storeAId,
    });

    riderBToken = signAccessToken({
      id: "rider-order-b",
      role: "delivery_rider",
      store_id: storeBId,
    });

    riderNoStoreToken = signAccessToken({
      id: "rider-no-store",
      role: "delivery_rider",
      store_id: null,
    });

    adminToken = signAccessToken({
      id: "admin-order-uuid",
      role: "super_admin",
      store_id: null,
    });
  });

  afterAll(async () => {
    if (storeAId || storeBId) {
      await query(`DELETE FROM orders WHERE store_id IN ($1, $2)`, [storeAId, storeBId]);
    }
    if (customerAUserId) await query(`DELETE FROM users WHERE id = $1`, [customerAUserId]);
    if (customerBUserId) await query(`DELETE FROM users WHERE id = $1`, [customerBUserId]);
    if (storeAId) await query(`DELETE FROM stores WHERE id = $1`, [storeAId]);
    if (storeBId) await query(`DELETE FROM stores WHERE id = $1`, [storeBId]);
    if (inactiveStoreId) await query(`DELETE FROM stores WHERE id = $1`, [inactiveStoreId]);
  });

  describe("Order Creation Validations & Cart Checks", () => {
    it("should reject order creation if customer cart is empty", async () => {
      const res = await request
        .post("/api/orders")
        .set("Authorization", `Bearer ${customerAToken}`)
        .send({
          store_id: storeAId,
          fulfillment_type: "pickup",
        });

      expect(res.status).toBe(400);
      expect(res.body.error).toContain("Cart is empty");
    });

    it("should reject delivery order when delivery_address is missing or empty", async () => {
      await request
        .post("/api/cart/items")
        .set("Authorization", `Bearer ${customerAToken}`)
        .send({ store_id: storeAId, product_id: productA1Id, quantity: 2 });

      const res = await request
        .post("/api/orders")
        .set("Authorization", `Bearer ${customerAToken}`)
        .send({
          store_id: storeAId,
          fulfillment_type: "delivery",
        });

      expect(res.status).toBe(400);
      expect(res.body.errors).toContain("delivery_address is required for delivery orders");
    });

    it("should allow pickup order without delivery_address", async () => {
      const res = await request
        .post("/api/orders")
        .set("Authorization", `Bearer ${customerAToken}`)
        .send({
          store_id: storeAId,
          fulfillment_type: "pickup",
        });

      expect(res.status).toBe(201);
      expect(res.body.order.fulfillment_type).toBe("pickup");
      expect(res.body.order.delivery_address).toBeNull();
      expect(res.body.order.total_amount).toBe("17.00"); // 2 * 8.50 = 17.00
      expect(res.body.order.points_earned).toBe(8); // 2 * 4 = 8
    });

    it("should verify customer cart is cleared after successful order creation", async () => {
      const cartRes = await request
        .get(`/api/cart?store_id=${storeAId}`)
        .set("Authorization", `Bearer ${customerAToken}`);

      expect(cartRes.status).toBe(200);
      expect(cartRes.body.cart.items).toEqual([]);
      expect(cartRes.body.cart.subtotal).toBe("0.00");
    });
  });

  describe("Concurrent Order Creation Safety", () => {
    it("should handle 2 concurrent POST /api/orders requests for same cart safely with SELECT FOR UPDATE", async () => {
      // Add items to cart for Customer A
      await request
        .post("/api/cart/items")
        .set("Authorization", `Bearer ${customerAToken}`)
        .send({ store_id: storeAId, product_id: productA1Id, quantity: 2 });

      // Fire 2 concurrent order creation requests
      const results = await Promise.all([
        request.post("/api/orders").set("Authorization", `Bearer ${customerAToken}`).send({ store_id: storeAId, fulfillment_type: "pickup" }),
        request.post("/api/orders").set("Authorization", `Bearer ${customerAToken}`).send({ store_id: storeAId, fulfillment_type: "pickup" }),
      ]);

      const successCount = results.filter((r) => r.status === 201).length;
      const failedCount = results.filter((r) => r.status === 400).length;

      // Exactly ONE request must succeed; second request must see empty cart!
      expect(successCount).toBe(1);
      expect(failedCount).toBe(1);
    });
  });

  describe("Delivery Rider Authorization & Store Isolation", () => {
    let orderAId: string;

    beforeAll(async () => {
      await request
        .post("/api/cart/items")
        .set("Authorization", `Bearer ${customerAToken}`)
        .send({ store_id: storeAId, product_id: productA1Id, quantity: 1 });

      const res = await request
        .post("/api/orders")
        .set("Authorization", `Bearer ${customerAToken}`)
        .send({ store_id: storeAId, fulfillment_type: "pickup" });

      orderAId = res.body.order.id;
    });

    it("should reject delivery rider without assigned store_id with 403", async () => {
      const res = await request
        .get("/api/orders")
        .set("Authorization", `Bearer ${riderNoStoreToken}`);

      expect(res.status).toBe(403);
      expect(res.body.error).toContain("Delivery rider is not assigned to a store");
    });

    it("should allow delivery rider of Store A to view Store A's orders", async () => {
      const res = await request
        .get(`/api/orders/${orderAId}`)
        .set("Authorization", `Bearer ${riderAToken}`);

      expect(res.status).toBe(200);
      expect(res.body.order.id).toBe(orderAId);
    });

    it("should reject delivery rider of Store B attempting to view Store A's order with 403", async () => {
      const res = await request
        .get(`/api/orders/${orderAId}`)
        .set("Authorization", `Bearer ${riderBToken}`);

      expect(res.status).toBe(403);
      expect(res.body.error).toContain("belonging to another store");
    });
  });

  describe("Order Status State Machine Transitions", () => {
    let orderId: string;

    beforeAll(async () => {
      await request
        .post("/api/cart/items")
        .set("Authorization", `Bearer ${customerBToken}`)
        .send({ store_id: storeAId, product_id: productA1Id, quantity: 1 });

      const res = await request
        .post("/api/orders")
        .set("Authorization", `Bearer ${customerBToken}`)
        .send({ store_id: storeAId, fulfillment_type: "pickup" });

      orderId = res.body.order.id;
    });

    it("should allow valid state transitions: pending -> accepted -> preparing -> out_for_delivery -> completed", async () => {
      // 1. pending -> accepted
      const res1 = await request
        .patch(`/api/orders/${orderId}/status`)
        .set("Authorization", `Bearer ${staffAToken}`)
        .send({ status: "accepted" });
      expect(res1.status).toBe(200);
      expect(res1.body.order.status).toBe("accepted");

      // 2. accepted -> preparing
      const res2 = await request
        .patch(`/api/orders/${orderId}/status`)
        .set("Authorization", `Bearer ${staffAToken}`)
        .send({ status: "preparing" });
      expect(res2.status).toBe(200);
      expect(res2.body.order.status).toBe("preparing");

      // 3. preparing -> out_for_delivery
      const res3 = await request
        .patch(`/api/orders/${orderId}/status`)
        .set("Authorization", `Bearer ${riderAToken}`)
        .send({ status: "out_for_delivery" });
      expect(res3.status).toBe(200);
      expect(res3.body.order.status).toBe("out_for_delivery");

      // 4. out_for_delivery -> completed
      const res4 = await request
        .patch(`/api/orders/${orderId}/status`)
        .set("Authorization", `Bearer ${staffAToken}`)
        .send({ status: "completed" });
      expect(res4.status).toBe(200);
      expect(res4.body.order.status).toBe("completed");
    });

    it("should reject moving backward or invalid transitions from completed status", async () => {
      const res = await request
        .patch(`/api/orders/${orderId}/status`)
        .set("Authorization", `Bearer ${staffAToken}`)
        .send({ status: "preparing" });

      expect(res.status).toBe(400);
      expect(res.body.error).toContain("Invalid status transition from 'completed' to 'preparing'");
    });
  });
});
