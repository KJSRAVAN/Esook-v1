import { describe, it, expect, beforeAll, afterAll } from "vitest";
import supertest from "supertest";
import app from "../../../app.js";
import { query } from "../../../db/index.js";
import { signAccessToken } from "../../../utils/jwt.js";

const request = supertest(app);

describe("Users & Staff Management Module (Super Admin)", () => {
  let storeId: string;
  let adminToken: string;
  let staffToken: string;
  let customerToken: string;

  let createdStaffPhone: string;
  let createdStaffUserId: string;

  beforeAll(async () => {
    // 1. Create a store for testing staff assignment
    const storeRes = await query<{ id: string }>(
      `INSERT INTO stores (name, area, is_active) VALUES ('User Mgmt Store', $1, TRUE) RETURNING id`,
      [`Riyadh - User Mgmt Area ${Date.now()}`]
    );
    storeId = storeRes.rows[0]!.id;

    // 2. Tokens
    adminToken = signAccessToken({
      id: "admin-user-mgmt-uuid",
      role: "super_admin",
      store_id: null,
    });

    staffToken = signAccessToken({
      id: "staff-user-mgmt-uuid",
      role: "store_staff",
      store_id: storeId,
    });

    customerToken = signAccessToken({
      id: "customer-user-mgmt-uuid",
      role: "customer",
      store_id: null,
    });

    createdStaffPhone = `+9665${Math.floor(10000000 + Math.random() * 90000000)}`;
  });

  afterAll(async () => {
    if (createdStaffUserId) {
      await query(`DELETE FROM users WHERE id = $1`, [createdStaffUserId]);
    }
    if (storeId) {
      await query(`DELETE FROM stores WHERE id = $1`, [storeId]);
    }
  });

  describe("Role Access Control & Security", () => {
    it("should reject non-admin users (customer, staff) from creating users with 403", async () => {
      const res = await request
        .post("/api/users")
        .set("Authorization", `Bearer ${customerToken}`)
        .send({
          phone_number: "+966512345678",
          full_name: "Illegal Staff",
          role: "store_staff",
          password: "password123",
          store_id: storeId,
        });

      expect(res.status).toBe(403);
    });

    it("should reject staff from listing users with 403", async () => {
      const res = await request
        .get("/api/users")
        .set("Authorization", `Bearer ${staffToken}`);

      expect(res.status).toBe(403);
    });
  });

  describe("Privileged Account Creation by Super Admin", () => {
    it("should reject creating store_staff without store_id with 400", async () => {
      const res = await request
        .post("/api/users")
        .set("Authorization", `Bearer ${adminToken}`)
        .send({
          phone_number: "+966599999999",
          full_name: "Unassigned Staff",
          role: "store_staff",
          password: "password123",
        });

      expect(res.status).toBe(400);
      expect(res.body.errors).toContain(
        "Valid store_id UUID is required for store staff and managers"
      );
    });

    it("should allow super_admin to create a store_staff user assigned to a store", async () => {
      const res = await request
        .post("/api/users")
        .set("Authorization", `Bearer ${adminToken}`)
        .send({
          phone_number: createdStaffPhone,
          full_name: "Assigned Store Staff",
          role: "store_staff",
          password: "SecretStaffPassword123!",
          store_id: storeId,
        });

      expect(res.status).toBe(201);
      expect(res.body.user.role).toBe("store_staff");
      expect(res.body.user.store_id).toBe(storeId);
      expect(res.body.user.is_active).toBe(true);

      createdStaffUserId = res.body.user.id;
    });

    it("should allow super_admin to list users filtered by role and store_id", async () => {
      const res = await request
        .get(`/api/users?role=store_staff&store_id=${storeId}`)
        .set("Authorization", `Bearer ${adminToken}`);

      expect(res.status).toBe(200);
      expect(Array.isArray(res.body.users)).toBe(true);
      const found = res.body.users.find((u: { id: string }) => u.id === createdStaffUserId);
      expect(found).toBeDefined();
    });
  });

  describe("Account Enable / Disable & Login Protection", () => {
    it("should verify newly created staff can login successfully", async () => {
      const res = await request.post("/api/auth/login").send({
        phone_number: createdStaffPhone,
        password: "SecretStaffPassword123!",
      });

      expect(res.status).toBe(200);
      expect(res.body.token).toBeDefined();
      expect(res.body.user.role).toBe("store_staff");
    });

    it("should allow super_admin to disable a user account (is_active = false)", async () => {
      const res = await request
        .patch(`/api/users/${createdStaffUserId}`)
        .set("Authorization", `Bearer ${adminToken}`)
        .send({ is_active: false });

      expect(res.status).toBe(200);
      expect(res.body.user.is_active).toBe(false);
    });

    it("should reject disabled user from logging in with 401 Unauthorized", async () => {
      const res = await request.post("/api/auth/login").send({
        phone_number: createdStaffPhone,
        password: "SecretStaffPassword123!",
      });

      expect(res.status).toBe(401);
      expect(res.body.error).toContain("Invalid phone number or password");
    });

    it("should allow super_admin to re-enable a disabled user account", async () => {
      const res = await request
        .patch(`/api/users/${createdStaffUserId}`)
        .set("Authorization", `Bearer ${adminToken}`)
        .send({ is_active: true });

      expect(res.status).toBe(200);
      expect(res.body.user.is_active).toBe(true);
    });

    it("should allow re-enabled user to login successfully", async () => {
      const res = await request.post("/api/auth/login").send({
        phone_number: createdStaffPhone,
        password: "SecretStaffPassword123!",
      });

      expect(res.status).toBe(200);
      expect(res.body.token).toBeDefined();
    });
  });
});
