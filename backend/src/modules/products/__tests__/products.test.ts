import { describe, it, expect, beforeAll, afterAll } from "vitest";
import supertest from "supertest";
import app from "../../../app.js";
import { query } from "../../../db/index.js";
import { signAccessToken } from "../../../utils/jwt.js";

const request = supertest(app);

describe("Product Catalog & Cross-Store Isolation Module", () => {
  let storeAId: string;
  let storeBId: string;
  let inactiveStoreId: string;

  let staffAToken: string;
  let staffBToken: string;
  let managerAToken: string;
  let adminToken: string;

  let productAId: string;
  let unavailableProductId: string;

  beforeAll(async () => {
    // 1. Create 2 active stores and 1 inactive store
    const resA = await query<{ id: string }>(
      `INSERT INTO stores (name, area, is_active) VALUES ('Supermarket A', $1, TRUE) RETURNING id`,
      [`Riyadh - Area A ${Date.now()}`]
    );
    storeAId = resA.rows[0]!.id;

    const resB = await query<{ id: string }>(
      `INSERT INTO stores (name, area, is_active) VALUES ('Supermarket B', $1, TRUE) RETURNING id`,
      [`Riyadh - Area B ${Date.now()}`]
    );
    storeBId = resB.rows[0]!.id;

    const resInactive = await query<{ id: string }>(
      `INSERT INTO stores (name, area, is_active) VALUES ('Inactive Supermarket', $1, FALSE) RETURNING id`,
      [`Riyadh - Area Inactive ${Date.now()}`]
    );
    inactiveStoreId = resInactive.rows[0]!.id;

    // 2. Generate tokens for staff, manager, and super admin
    staffAToken = signAccessToken({
      id: "staff-a-uuid",
      role: "store_staff",
      store_id: storeAId,
    });

    staffBToken = signAccessToken({
      id: "staff-b-uuid",
      role: "store_staff",
      store_id: storeBId,
    });

    managerAToken = signAccessToken({
      id: "manager-a-uuid",
      role: "store_manager",
      store_id: storeAId,
    });

    adminToken = signAccessToken({
      id: "admin-uuid",
      role: "super_admin",
      store_id: null,
    });
  });

  afterAll(async () => {
    if (storeAId) await query(`DELETE FROM stores WHERE id = $1`, [storeAId]);
    if (storeBId) await query(`DELETE FROM stores WHERE id = $1`, [storeBId]);
    if (inactiveStoreId) await query(`DELETE FROM stores WHERE id = $1`, [inactiveStoreId]);
  });

  describe("Product Creation & Validation", () => {
    it("should allow store staff to create a product for their own store", async () => {
      const res = await request
        .post("/api/products")
        .set("Authorization", `Bearer ${staffAToken}`)
        .send({
          name: "Fresh Milk 1L",
          description: "Whole cow milk",
          price: 6.5,
          loyalty_points_per_unit: 5,
        });

      expect(res.status).toBe(201);
      expect(res.body.product).toBeDefined();
      expect(res.body.product.store_id).toBe(storeAId); // Derived from staff JWT!
      expect(res.body.product.price).toBe("6.50");
      expect(res.body.product.loyalty_points_per_unit).toBe(5);

      productAId = res.body.product.id;
    });

    it("should reject product creation with negative price or negative loyalty points", async () => {
      const res1 = await request
        .post("/api/products")
        .set("Authorization", `Bearer ${staffAToken}`)
        .send({
          name: "Invalid Price Product",
          price: -10,
        });

      expect(res1.status).toBe(400);
      expect(res1.body.errors).toContain("Price must be a non-negative number");

      const res2 = await request
        .post("/api/products")
        .set("Authorization", `Bearer ${staffAToken}`)
        .send({
          name: "Invalid Points Product",
          price: 5,
          loyalty_points_per_unit: -2,
        });

      expect(res2.status).toBe(400);
      expect(res2.body.errors).toContain("loyalty_points_per_unit must be a non-negative integer");
    });

    it("should reject staff attempting to force creation for another store", async () => {
      const res = await request
        .post("/api/products")
        .set("Authorization", `Bearer ${staffAToken}`)
        .send({
          store_id: storeBId, // Attempt to create for store B!
          name: "Cross Store Attempt",
          price: 15.0,
        });

      expect(res.status).toBe(201);
      // Product must be assigned to store A (derived from req.user.store_id), NOT store B!
      expect(res.body.product.store_id).toBe(storeAId);
    });
  });

  describe("Cross-Store Isolation & Product Updates", () => {
    it("should allow store manager to update an own-store product", async () => {
      const res = await request
        .patch(`/api/products/${productAId}`)
        .set("Authorization", `Bearer ${managerAToken}`)
        .send({
          price: 7.0,
          loyalty_points_per_unit: 10,
        });

      expect(res.status).toBe(200);
      expect(res.body.product.price).toBe("7.00");
      expect(res.body.product.loyalty_points_per_unit).toBe(10);
    });

    it("should reject store staff trying to update a product belonging to another store", async () => {
      const res = await request
        .patch(`/api/products/${productAId}`)
        .set("Authorization", `Bearer ${staffBToken}`) // Staff B operating on Product A!
        .send({
          price: 0.01,
        });

      expect(res.status).toBe(403);
      expect(res.body.error).toContain("belonging to another store");
    });
  });

  describe("Customer Product Catalog & Availability Filtering", () => {
    beforeAll(async () => {
      // Create an unavailable product in Store A
      const res = await request
        .post("/api/products")
        .set("Authorization", `Bearer ${staffAToken}`)
        .send({
          name: "Out of Stock Cheese",
          price: 12.0,
          is_available: false,
        });
      unavailableProductId = res.body.product.id;
    });

    it("should allow customer to view available product", async () => {
      const res = await request.get(`/api/products/${productAId}`);
      expect(res.status).toBe(200);
      expect(res.body.product.id).toBe(productAId);
    });

    it("should hide unavailable product from customer catalog", async () => {
      const res = await request.get(`/api/products/${unavailableProductId}`);
      expect(res.status).toBe(404);

      // Also verify unavailable product is excluded from customer store catalog list
      const listRes = await request.get(`/api/products/store/${storeAId}`);
      expect(listRes.status).toBe(200);
      const productIds = listRes.body.products.map((p: any) => p.id);
      expect(productIds).toContain(productAId);
      expect(productIds).not.toContain(unavailableProductId);
    });

    it("should allow staff of the store to view unavailable products in their store catalog", async () => {
      const res = await request
        .get(`/api/products/store/${storeAId}`)
        .set("Authorization", `Bearer ${staffAToken}`);

      expect(res.status).toBe(200);
      const productIds = res.body.products.map((p: any) => p.id);
      expect(productIds).toContain(unavailableProductId);
    });

    it("should prevent customers from accessing inactive store catalog", async () => {
      const res = await request.get(`/api/products/store/${inactiveStoreId}`);
      expect(res.status).toBe(404);
      expect(res.body.error).toContain("Store not found or unavailable");
    });
  });

  describe("Database Level Constraint Integrity", () => {
    it("should verify PostgreSQL composite unique constraint uq_products_id_store", async () => {
      const dbRes = await query<{ count: string }>(
        `SELECT count(*) FROM pg_constraint WHERE conname = 'uq_products_id_store'`
      );
      expect(Number(dbRes.rows[0]?.count)).toBeGreaterThan(0);
    });
  });
});
