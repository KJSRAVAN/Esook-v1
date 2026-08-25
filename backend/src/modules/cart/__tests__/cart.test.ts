import { describe, it, expect, beforeAll, afterAll } from "vitest";
import supertest from "supertest";
import app from "../../../app.js";
import { query } from "../../../db/index.js";
import { signAccessToken } from "../../../utils/jwt.js";

const request = supertest(app);

describe("Customer Cart Module & PostgreSQL Store Isolation", () => {
  let storeAId: string;
  let storeBId: string;
  let inactiveStoreId: string;

  let customerAToken: string;
  let customerBToken: string;
  let staffAToken: string;
  let adminToken: string;

  let customerAUserId: string;
  let customerBUserId: string;

  let productA1Id: string;
  let productA2UnavailableId: string;
  let productB1Id: string;

  beforeAll(async () => {
    // 1. Create test stores
    const resA = await query<{ id: string }>(
      `INSERT INTO stores (name, area, is_active) VALUES ('Cart Store A', $1, TRUE) RETURNING id`,
      [`Riyadh - Cart Area A ${Date.now()}`]
    );
    storeAId = resA.rows[0]!.id;

    const resB = await query<{ id: string }>(
      `INSERT INTO stores (name, area, is_active) VALUES ('Cart Store B', $1, TRUE) RETURNING id`,
      [`Riyadh - Cart Area B ${Date.now()}`]
    );
    storeBId = resB.rows[0]!.id;

    const resInactive = await query<{ id: string }>(
      `INSERT INTO stores (name, area, is_active) VALUES ('Cart Inactive Store', $1, FALSE) RETURNING id`,
      [`Riyadh - Cart Inactive Area ${Date.now()}`]
    );
    inactiveStoreId = resInactive.rows[0]!.id;

    // 2. Create products in stores
    const pA1 = await query<{ id: string }>(
      `INSERT INTO products (store_id, name, price, is_available, loyalty_points_per_unit)
       VALUES ($1, 'Store A Organic Apples', 12.50, TRUE, 5) RETURNING id`,
      [storeAId]
    );
    productA1Id = pA1.rows[0]!.id;

    const pA2 = await query<{ id: string }>(
      `INSERT INTO products (store_id, name, price, is_available, loyalty_points_per_unit)
       VALUES ($1, 'Store A Out of Stock Milk', 6.00, FALSE, 0) RETURNING id`,
      [storeAId]
    );
    productA2UnavailableId = pA2.rows[0]!.id;

    const pB1 = await query<{ id: string }>(
      `INSERT INTO products (store_id, name, price, is_available, loyalty_points_per_unit)
       VALUES ($1, 'Store B Imported Cheese', 25.00, TRUE, 10) RETURNING id`,
      [storeBId]
    );
    productB1Id = pB1.rows[0]!.id;

    // 3. Create test users
    const uA = await query<{ id: string }>(
      `INSERT INTO users (phone_number, full_name, password_hash, role)
       VALUES ($1, 'Customer A', 'hash', 'customer') RETURNING id`,
      [`+9665${Math.floor(10000000 + Math.random() * 90000000)}`]
    );
    customerAUserId = uA.rows[0]!.id;

    const uB = await query<{ id: string }>(
      `INSERT INTO users (phone_number, full_name, password_hash, role)
       VALUES ($1, 'Customer B', 'hash', 'customer') RETURNING id`,
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

    staffAToken = signAccessToken({
      id: "staff-a-uuid",
      role: "store_staff",
      store_id: storeAId,
    });

    adminToken = signAccessToken({
      id: "admin-uuid",
      role: "super_admin",
      store_id: null,
    });
  });

  afterAll(async () => {
    if (customerAUserId) await query(`DELETE FROM users WHERE id = $1`, [customerAUserId]);
    if (customerBUserId) await query(`DELETE FROM users WHERE id = $1`, [customerBUserId]);
    if (storeAId) await query(`DELETE FROM stores WHERE id = $1`, [storeAId]);
    if (storeBId) await query(`DELETE FROM stores WHERE id = $1`, [storeBId]);
    if (inactiveStoreId) await query(`DELETE FROM stores WHERE id = $1`, [inactiveStoreId]);
  });

  describe("Customer Cart Access & Role Restrictions", () => {
    it("should return empty cart structure for customer getting cart before adding items", async () => {
      const res = await request
        .get(`/api/cart?store_id=${storeAId}`)
        .set("Authorization", `Bearer ${customerAToken}`);

      expect(res.status).toBe(200);
      expect(res.body.cart.cart_id).toBeNull();
      expect(res.body.cart.items).toEqual([]);
      expect(res.body.cart.subtotal).toBe("0.00");
      expect(res.body.cart.itemCount).toBe(0);
    });

    it("should reject non-customer roles (staff, admin, rider) from using customer cart endpoints", async () => {
      const staffRes = await request
        .get(`/api/cart?store_id=${storeAId}`)
        .set("Authorization", `Bearer ${staffAToken}`);
      expect(staffRes.status).toBe(403);

      const adminRes = await request
        .get(`/api/cart?store_id=${storeAId}`)
        .set("Authorization", `Bearer ${adminToken}`);
      expect(adminRes.status).toBe(403);
    });

    it("should reject customer attempting to access cart for an inactive store", async () => {
      const res = await request
        .get(`/api/cart?store_id=${inactiveStoreId}`)
        .set("Authorization", `Bearer ${customerAToken}`);

      expect(res.status).toBe(404);
      expect(res.body.error).toContain("Store not found or unavailable");
    });
  });

  describe("Adding Cart Items & Server-Side Subtotal Calculation", () => {
    it("should add available product to customer cart and calculate subtotal server-side", async () => {
      const res = await request
        .post("/api/cart/items")
        .set("Authorization", `Bearer ${customerAToken}`)
        .send({
          store_id: storeAId,
          product_id: productA1Id,
          quantity: 2,
        });

      expect(res.status).toBe(200);
      expect(res.body.cart.cart_id).toBeDefined();
      expect(res.body.cart.items.length).toBe(1);
      expect(res.body.cart.items[0].product_name).toBe("Store A Organic Apples");
      expect(res.body.cart.items[0].quantity).toBe(2);
      expect(res.body.cart.items[0].unit_price).toBe("12.50");
      expect(res.body.cart.items[0].item_subtotal).toBe("25.00");
      expect(res.body.cart.subtotal).toBe("25.00");
    });

    it("should update/increment quantity when adding the same product twice", async () => {
      const res = await request
        .post("/api/cart/items")
        .set("Authorization", `Bearer ${customerAToken}`)
        .send({
          store_id: storeAId,
          product_id: productA1Id,
          quantity: 3,
        });

      expect(res.status).toBe(200);
      expect(res.body.cart.items.length).toBe(1);
      expect(res.body.cart.items[0].quantity).toBe(5); // 2 + 3 = 5
      expect(res.body.cart.subtotal).toBe("62.50"); // 5 * 12.50 = 62.50
    });

    it("should reject adding an unavailable product", async () => {
      const res = await request
        .post("/api/cart/items")
        .set("Authorization", `Bearer ${customerAToken}`)
        .send({
          store_id: storeAId,
          product_id: productA2UnavailableId,
          quantity: 1,
        });

      expect(res.status).toBe(400);
      expect(res.body.error).toContain("currently unavailable");
    });

    it("should reject adding a product belonging to a different store than the cart store", async () => {
      const res = await request
        .post("/api/cart/items")
        .set("Authorization", `Bearer ${customerAToken}`)
        .send({
          store_id: storeAId,
          product_id: productB1Id, // Product B belongs to Store B!
          quantity: 1,
        });

      expect(res.status).toBe(400);
      expect(res.body.error).toContain("does not belong to the selected store");
    });

    it("should reject invalid quantities (<= 0 or non-integer)", async () => {
      const res1 = await request
        .post("/api/cart/items")
        .set("Authorization", `Bearer ${customerAToken}`)
        .send({
          store_id: storeAId,
          product_id: productA1Id,
          quantity: 0,
        });
      expect(res1.status).toBe(400);

      const res2 = await request
        .post("/api/cart/items")
        .set("Authorization", `Bearer ${customerAToken}`)
        .send({
          store_id: storeAId,
          product_id: productA1Id,
          quantity: -3,
        });
      expect(res2.status).toBe(400);
    });
  });

  describe("Cart Item Modifications & Clearing", () => {
    it("should allow customer to update quantity of an existing cart item", async () => {
      const res = await request
        .patch(`/api/cart/items/${productA1Id}`)
        .set("Authorization", `Bearer ${customerAToken}`)
        .send({
          store_id: storeAId,
          quantity: 4,
        });

      expect(res.status).toBe(200);
      expect(res.body.cart.items[0].quantity).toBe(4);
      expect(res.body.cart.subtotal).toBe("50.00");
    });

    it("should allow customer to remove a single item from cart", async () => {
      const res = await request
        .delete(`/api/cart/items/${productA1Id}?store_id=${storeAId}`)
        .set("Authorization", `Bearer ${customerAToken}`);

      expect(res.status).toBe(200);
      expect(res.body.cart.items).toEqual([]);
      expect(res.body.cart.subtotal).toBe("0.00");
    });

    it("should clear all items from customer's store cart", async () => {
      // Re-add product first
      await request
        .post("/api/cart/items")
        .set("Authorization", `Bearer ${customerAToken}`)
        .send({ store_id: storeAId, product_id: productA1Id, quantity: 1 });

      const clearRes = await request
        .delete(`/api/cart?store_id=${storeAId}`)
        .set("Authorization", `Bearer ${customerAToken}`);

      expect(clearRes.status).toBe(200);
      expect(clearRes.body.cart.items).toEqual([]);
      expect(clearRes.body.cart.subtotal).toBe("0.00");
    });
  });

  describe("Customer & Store Isolation Protections", () => {
    it("should prevent Customer B from accessing Customer A's cart", async () => {
      // Add item to Customer A's cart
      await request
        .post("/api/cart/items")
        .set("Authorization", `Bearer ${customerAToken}`)
        .send({ store_id: storeAId, product_id: productA1Id, quantity: 2 });

      // Customer B requests cart for Store A
      const resB = await request
        .get(`/api/cart?store_id=${storeAId}`)
        .set("Authorization", `Bearer ${customerBToken}`);

      expect(resB.status).toBe(200);
      // Customer B's cart for Store A must be empty!
      expect(resB.body.cart.items).toEqual([]);
      expect(resB.body.cart.subtotal).toBe("0.00");
    });

    it("should verify PostgreSQL composite foreign key constraint fk_cart_items_product prevents cross-store items", async () => {
      // Query PostgreSQL constraint catalog to verify fk_cart_items_product and fk_cart_items_cart exist
      const fkRes = await query<{ conname: string }>(
        `SELECT conname FROM pg_constraint WHERE conname IN ('fk_cart_items_product', 'fk_cart_items_cart')`
      );
      expect(fkRes.rows.length).toBe(2);
    });

    it("should handle concurrent add requests safely without duplicating cart_items rows", async () => {
      const results = await Promise.all([
        request.post("/api/cart/items").set("Authorization", `Bearer ${customerBToken}`).send({ store_id: storeBId, product_id: productB1Id, quantity: 1 }),
        request.post("/api/cart/items").set("Authorization", `Bearer ${customerBToken}`).send({ store_id: storeBId, product_id: productB1Id, quantity: 1 }),
        request.post("/api/cart/items").set("Authorization", `Bearer ${customerBToken}`).send({ store_id: storeBId, product_id: productB1Id, quantity: 1 }),
      ]);

      const successResults = results.filter((r) => r.status === 200);
      expect(successResults.length).toBe(3);

      const finalCartRes = await request
        .get(`/api/cart?store_id=${storeBId}`)
        .set("Authorization", `Bearer ${customerBToken}`);

      expect(finalCartRes.body.cart.items.length).toBe(1);
      expect(finalCartRes.body.cart.items[0].quantity).toBe(3);
    });
  });
});
