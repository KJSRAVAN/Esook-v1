import { describe, it, expect, beforeAll, afterAll } from "vitest";
import supertest from "supertest";
import bcrypt from "bcryptjs";
import crypto from "node:crypto";
import jwt from "jsonwebtoken";
import app from "../../../app.js";
import { query } from "../../../db/index.js";
import { signAccessToken, verifyAccessToken } from "../../../utils/jwt.js";
import { authenticate, requireOwnStore } from "../../../middleware/auth.middleware.js";
import { env } from "../../../config/env.js";

const request = supertest(app);

describe("Authentication & Authorization Module Security Fixes", () => {
  let createdUserPhone: string;
  let createdUserId: string;
  let createdStoreId: string;

  beforeAll(async () => {
    // Create a dummy store for store staff / manager testing
    const testArea = `Riyadh - Test Area ${Date.now()}`;
    const storeRes = await query<{ id: string }>(
      `INSERT INTO stores (name, area) VALUES ('Test Supermarket', $1) RETURNING id`,
      [testArea]
    );
    createdStoreId = storeRes.rows[0]!.id;
  });

  afterAll(async () => {
    // Clean up created test data
    if (createdUserId) {
      await query(`DELETE FROM users WHERE id = $1`, [createdUserId]);
    }
    if (createdStoreId) {
      await query(`DELETE FROM stores WHERE id = $1`, [createdStoreId]);
    }
  });

  describe("Customer Signup & Login", () => {
    it("should register customer and hash password", async () => {
      createdUserPhone = `+9665${Math.floor(10000000 + Math.random() * 90000000)}`;

      const res = await request.post("/api/auth/signup").send({
        phone_number: createdUserPhone,
        full_name: "Test Customer",
        password: "password123",
        role: "super_admin", // Client role escalation attempt - must be ignored!
      });

      expect(res.status).toBe(201);
      expect(res.body.user.role).toBe("customer");
      createdUserId = res.body.user.id;
    });

    it("should return generic 'Invalid phone number or password' error for inactive accounts", async () => {
      const inactivePhone = `+9665${Math.floor(10000000 + Math.random() * 90000000)}`;
      const passHash = await bcrypt.hash("password123", 10);
      await query(
        `INSERT INTO users (phone_number, full_name, password_hash, role, is_active)
         VALUES ($1, 'Inactive User', $2, 'customer', FALSE)`,
        [inactivePhone, passHash]
      );

      const res = await request.post("/api/auth/login").send({
        phone_number: inactivePhone,
        password: "password123",
      });

      // Must return standard generic error to prevent enumeration
      expect(res.status).toBe(401);
      expect(res.body.error).toBe("Invalid phone number or password");

      await query(`DELETE FROM users WHERE phone_number = $1`, [inactivePhone]);
    });
  });

  describe("JWT Claim Validation & Malformed Tokens", () => {
    it("should reject JWT with missing/empty sub claim", () => {
      const malformedToken = jwt.sign({ sub: "", role: "customer", store_id: null }, env.JWT_SECRET);
      expect(() => verifyAccessToken(malformedToken)).toThrow("sub must be a non-empty string");
    });

    it("should reject JWT with invalid role claim", () => {
      const malformedToken = jwt.sign({ sub: "user-123", role: "hacker", store_id: null }, env.JWT_SECRET);
      expect(() => verifyAccessToken(malformedToken)).toThrow("role is invalid");
    });

    it("should reject JWT with non-string/non-null store_id claim", () => {
      const malformedToken = jwt.sign({ sub: "user-123", role: "customer", store_id: 12345 }, env.JWT_SECRET);
      expect(() => verifyAccessToken(malformedToken)).toThrow("store_id must be a string or null");
    });
  });

  describe("requireOwnStore Authorization Middleware", () => {
    it("should reject store staff without store_id assigned", () => {
      const staffToken = signAccessToken({
        id: "staff-no-store",
        role: "store_staff",
        store_id: null,
      });

      const req: any = {
        headers: { authorization: `Bearer ${staffToken}` },
        params: { storeId: createdStoreId },
      };
      let statusResult = 200;
      let jsonResult: any = {};
      const res: any = {
        status: (code: number) => {
          statusResult = code;
          return { json: (payload: any) => { jsonResult = payload; } };
        },
      };

      authenticate(req, res, () => {
        requireOwnStore(req, res, () => {});
      });

      expect(statusResult).toBe(403);
      expect(jsonResult.error).toContain("not associated with any store");
    });

    it("should reject store staff requesting mismatched target store", () => {
      const staffToken = signAccessToken({
        id: "staff-1",
        role: "store_staff",
        store_id: createdStoreId,
      });

      const req: any = {
        headers: { authorization: `Bearer ${staffToken}` },
        params: { storeId: "00000000-0000-0000-0000-000000000000" },
      };
      let statusResult = 200;
      let jsonResult: any = {};
      const res: any = {
        status: (code: number) => {
          statusResult = code;
          return { json: (payload: any) => { jsonResult = payload; } };
        },
      };

      authenticate(req, res, () => {
        requireOwnStore(req, res, () => {});
      });

      expect(statusResult).toBe(403);
      expect(jsonResult.error).toContain("restricted to assigned store only");
    });
  });

  describe("Atomic Single-Use Magic Link Flow & Race Conditions", () => {
    let adminEmail: string;
    let adminId: string;

    beforeAll(async () => {
      adminEmail = `admin_atomic_${Date.now()}@esook.sa`;
      const adminPhone = `+9665${Math.floor(10000000 + Math.random() * 90000000)}`;
      const res = await query<{ id: string }>(
        `INSERT INTO users (phone_number, email, full_name, role, password_hash)
         VALUES ($1, $2, 'Super Admin Atomic Test', 'super_admin', NULL)
         RETURNING id`,
        [adminPhone, adminEmail]
      );
      adminId = res.rows[0]!.id;
    });

    afterAll(async () => {
      if (adminId) {
        await query(`DELETE FROM users WHERE id = $1`, [adminId]);
      }
    });

    it("should allow only one concurrent request to claim a magic link token", async () => {
      const rawToken = crypto.randomBytes(32).toString("hex");
      const tokenHash = crypto.createHash("sha256").update(rawToken).digest("hex");
      const expiresAt = new Date(Date.now() + 15 * 60 * 1000);

      await query(
        `INSERT INTO magic_link_tokens (user_id, token_hash, expires_at) VALUES ($1, $2, $3)`,
        [adminId, tokenHash, expiresAt]
      );

      // Fire 5 concurrent redemption requests simultaneously
      const results = await Promise.all([
        request.post("/api/auth/admin/verify-magic-link").send({ token: rawToken }),
        request.post("/api/auth/admin/verify-magic-link").send({ token: rawToken }),
        request.post("/api/auth/admin/verify-magic-link").send({ token: rawToken }),
        request.post("/api/auth/admin/verify-magic-link").send({ token: rawToken }),
        request.post("/api/auth/admin/verify-magic-link").send({ token: rawToken }),
      ]);

      const successCount = results.filter((r) => r.status === 200).length;
      const failedCount = results.filter((r) => r.status === 401).length;

      // Exactly ONE request must succeed; all others must fail!
      expect(successCount).toBe(1);
      expect(failedCount).toBe(4);
    });
  });

  describe("Unexpected Internal Error Masking", () => {
    it("should handle malformed JSON bodies safely without exposing stack traces", async () => {
      const res = await request
        .post("/api/auth/signup")
        .set("Content-Type", "application/json")
        .send("NOT_JSON");

      expect(res.status).toBe(400);
      expect(res.body.error).toBeDefined();
      expect(res.body.error).not.toContain("at "); // No stack trace leaked!
    });
  });
});
