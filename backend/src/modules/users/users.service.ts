import bcrypt from "bcryptjs";
import { query } from "../../db/index.js";
import type { UserRole } from "../../utils/jwt.js";
import type { CreateUserInput, UpdateUserInput } from "./users.validation.js";

const BCRYPT_SALT_ROUNDS = 12;

export interface UserDetail {
  id: string;
  phone_number: string;
  email?: string | null;
  full_name: string;
  role: UserRole;
  store_id?: string | null;
  store_name?: string | null;
  address?: string | null;
  is_active: boolean;
  created_at: Date;
  updated_at: Date;
}

export class UsersService {
  /**
   * Super Admin: Create a new user (staff, manager, rider, or admin).
   */
  static async createUser(input: CreateUserInput): Promise<UserDetail> {
    // 1. Check duplicate phone_number or email
    const existingPhone = await query<{ id: string }>(
      `SELECT id FROM users WHERE phone_number = $1`,
      [input.phone_number]
    );

    if (existingPhone.rows.length > 0) {
      const err = new Error("An account with this phone number already exists");
      (err as unknown as { status: number }).status = 409;
      throw err;
    }

    if (input.email) {
      const existingEmail = await query<{ id: string }>(
        `SELECT id FROM users WHERE email = $1`,
        [input.email]
      );

      if (existingEmail.rows.length > 0) {
        const err = new Error("An account with this email address already exists");
        (err as unknown as { status: number }).status = 409;
        throw err;
      }
    }

    // 2. Validate store exists if store_id provided
    if (input.store_id) {
      const storeRes = await query<{ id: string }>(
        `SELECT id FROM stores WHERE id = $1`,
        [input.store_id]
      );
      if (storeRes.rows.length === 0) {
        const err = new Error("Assigned store does not exist");
        (err as unknown as { status: number }).status = 404;
        throw err;
      }
    }

    // 3. Hash password if provided
    let passwordHash: string | null = null;
    if (input.password) {
      passwordHash = await bcrypt.hash(input.password, BCRYPT_SALT_ROUNDS);
    }

    // 4. Insert user
    const res = await query<UserDetail>(
      `INSERT INTO users (phone_number, email, password_hash, full_name, role, store_id, is_active)
       VALUES ($1, $2, $3, $4, $5, $6, TRUE)
       RETURNING id, phone_number, email, full_name, role, store_id, is_active, created_at, updated_at`,
      [
        input.phone_number,
        input.email || null,
        passwordHash,
        input.full_name,
        input.role,
        input.store_id || null,
      ]
    );

    const user = res.rows[0]!;

    if (user.store_id) {
      const storeNameRes = await query<{ name: string }>(
        `SELECT name FROM stores WHERE id = $1`,
        [user.store_id]
      );
      user.store_name = storeNameRes.rows[0]?.name || null;
    }

    return user;
  }

  /**
   * Super Admin: List users with optional filters (role, store_id, is_active).
   */
  static async listUsers(
    roleFilter?: string,
    storeIdFilter?: string,
    isActiveFilter?: boolean
  ): Promise<UserDetail[]> {
    let sql = `
      SELECT u.id, u.phone_number, u.email, u.full_name, u.role, u.store_id, u.address, u.is_active,
             u.created_at, u.updated_at,
             s.name AS store_name
      FROM users u
      LEFT JOIN stores s ON s.id = u.store_id
      WHERE 1=1
    `;
    const params: unknown[] = [];

    if (roleFilter) {
      params.push(roleFilter);
      sql += ` AND u.role = $${params.length}`;
    }

    if (storeIdFilter) {
      params.push(storeIdFilter);
      sql += ` AND u.store_id = $${params.length}`;
    }

    if (typeof isActiveFilter === "boolean") {
      params.push(isActiveFilter);
      sql += ` AND u.is_active = $${params.length}`;
    }

    sql += ` ORDER BY u.created_at DESC`;

    const res = await query<UserDetail>(sql, params);
    return res.rows;
  }

  /**
   * Super Admin: Get single user by ID.
   */
  static async getUserById(userId: string): Promise<UserDetail> {
    const res = await query<UserDetail>(
      `SELECT u.id, u.phone_number, u.email, u.full_name, u.role, u.store_id, u.address, u.is_active,
              u.created_at, u.updated_at,
              s.name AS store_name
       FROM users u
       LEFT JOIN stores s ON s.id = u.store_id
       WHERE u.id = $1`,
      [userId]
    );

    const user = res.rows[0];
    if (!user) {
      const err = new Error("User not found");
      (err as unknown as { status: number }).status = 404;
      throw err;
    }

    return user;
  }

  /**
   * Super Admin: Update user status or assigned store.
   */
  static async updateUser(userId: string, input: UpdateUserInput): Promise<UserDetail> {
    const existing = await this.getUserById(userId);

    const updates: string[] = [];
    const params: unknown[] = [];

    if (typeof input.is_active === "boolean") {
      params.push(input.is_active);
      updates.push(`is_active = $${params.length}`);
    }

    if (input.full_name) {
      params.push(input.full_name);
      updates.push(`full_name = $${params.length}`);
    }

    if (input.store_id !== undefined) {
      if (input.store_id !== null) {
        const storeRes = await query<{ id: string }>(
          `SELECT id FROM stores WHERE id = $1`,
          [input.store_id]
        );
        if (storeRes.rows.length === 0) {
          const err = new Error("Assigned store does not exist");
          (err as unknown as { status: number }).status = 404;
          throw err;
        }
      }
      params.push(input.store_id);
      updates.push(`store_id = $${params.length}`);
    }

    if (updates.length === 0) {
      return existing;
    }

    params.push(userId);
    const sql = `
      UPDATE users
      SET ${updates.join(", ")}, updated_at = CURRENT_TIMESTAMP
      WHERE id = $${params.length}
    `;

    await query(sql, params);
    return this.getUserById(userId);
  }
}
