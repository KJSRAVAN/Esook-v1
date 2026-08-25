import { describe, it, expect, beforeAll, afterAll } from "vitest";
import supertest from "supertest";
import app from "../../../app.js";
import { query } from "../../../db/index.js";
import { signAccessToken } from "../../../utils/jwt.js";

const request = supertest(app);

describe("Store Management & Discovery Module", () => {
  let adminToken: string;
  let customerToken: string;
  let createdStoreId: string;
  let inactiveStoreId: string;
  let testArea: string;

  beforeAll(async () => {
    adminToken = signAccessToken({
      id: "admin-uuid-1",
      role: "super_admin",
      store_id: null,
    });

    customerToken = signAccessToken({
      id: "customer-uuid-1",
      role: "customer",
      store_id: null,
    });

    testArea = `Riyadh - Olaya ${Date.now()}`;
  });

  afterAll(async () => {
    if (createdStoreId) {
      await query(`DELETE FROM stores WHERE id = $1`, [createdStoreId]);
    }
    if (inactiveStoreId) {
      await query(`DELETE FROM stores WHERE id = $1`, [inactiveStoreId]);
    }
  });

  it("should allow super_admin to create a store", async () => {
    const res = await request
      .post("/api/stores")
      .set("Authorization", `Bearer ${adminToken}`)
      .send({
        name: "eSOuQ Olaya Flagship",
        area: testArea,
        address: "King Fahd Road, Olaya",
        phone_number: "+966112345678",
      });

    expect(res.status).toBe(201);
    expect(res.body.store).toBeDefined();
    expect(res.body.store.name).toBe("eSOuQ Olaya Flagship");
    expect(res.body.store.is_active).toBe(true);

    createdStoreId = res.body.store.id;
  });

  it("should reject non-admin from creating a store", async () => {
    const res = await request
      .post("/api/stores")
      .set("Authorization", `Bearer ${customerToken}`)
      .send({
        name: "Unauthorized Store",
        area: `Jeddah - Area ${Date.now()}`,
      });

    expect(res.status).toBe(403);
  });

  it("should reject creating duplicate active store in the same area (case-insensitive)", async () => {
    const res = await request
      .post("/api/stores")
      .set("Authorization", `Bearer ${adminToken}`)
      .send({
        name: "Duplicate Olaya Store",
        area: testArea.toLowerCase(), // case-insensitive duplicate check!
      });

    expect(res.status).toBe(409);
    expect(res.body.error).toContain("active store already serves this area");
  });

  it("should list active stores for customers", async () => {
    const res = await request.get("/api/stores");

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body.stores)).toBe(true);
    const storeIds = res.body.stores.map((s: any) => s.id);
    expect(storeIds).toContain(createdStoreId);
  });

  it("should allow super_admin to deactivate a store", async () => {
    // Create another store to deactivate
    const insecArea = `Dammam - Coastal ${Date.now()}`;
    const createRes = await request
      .post("/api/stores")
      .set("Authorization", `Bearer ${adminToken}`)
      .send({
        name: "Dammam Branch",
        area: insecArea,
      });

    inactiveStoreId = createRes.body.store.id;

    // Deactivate store
    const updateRes = await request
      .patch(`/api/stores/${inactiveStoreId}`)
      .set("Authorization", `Bearer ${adminToken}`)
      .send({ is_active: false });

    expect(updateRes.status).toBe(200);
    expect(updateRes.body.store.is_active).toBe(false);
  });

  it("should exclude inactive store from customer store listing", async () => {
    const res = await request.get("/api/stores");

    expect(res.status).toBe(200);
    const storeIds = res.body.stores.map((s: any) => s.id);
    expect(storeIds).not.toContain(inactiveStoreId);
  });

  it("should exclude inactive store from customer lookup by ID", async () => {
    const res = await request.get(`/api/stores/${inactiveStoreId}`);
    expect(res.status).toBe(404);
  });

  it("should allow customer to find active store by area (case-insensitive)", async () => {
    const res = await request.get(`/api/stores/area/${encodeURIComponent(testArea.toUpperCase())}`);

    expect(res.status).toBe(200);
    expect(res.body.store.id).toBe(createdStoreId);
  });
});
