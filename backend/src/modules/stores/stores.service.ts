import { query } from "../../db/index.js";
import type { CreateStoreInput, UpdateStoreInput } from "./stores.validation.js";

export interface Store {
  id: string;
  name: string;
  area: string;
  address: string | null;
  phone_number: string | null;
  is_active: boolean;
  created_at: Date;
  updated_at: Date;
}

export class StoresService {
  /**
   * Super Admin: Create a new store.
   * Handles unique active area constraint violation gracefully.
   */
  static async createStore(input: CreateStoreInput): Promise<Store> {
    try {
      const result = await query<Store>(
        `INSERT INTO stores (name, area, address, phone_number, is_active)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING id, name, area, address, phone_number, is_active, created_at, updated_at`,
        [
          input.name,
          input.area,
          input.address || null,
          input.phone_number || null,
          input.is_active ?? true,
        ]
      );
      return result.rows[0]!;
    } catch (err: unknown) {
      if (
        typeof err === "object" &&
        err !== null &&
        "code" in err &&
        (err as { code: string }).code === "23505"
      ) {
        const error = new Error("An active store already serves this area");
        (error as unknown as { status: number }).status = 409;
        throw error;
      }
      throw err;
    }
  }

  /**
   * Super Admin: Update store details or activate/deactivate.
   */
  static async updateStore(
    id: string,
    input: UpdateStoreInput
  ): Promise<Store> {
    const fields: string[] = [];
    const values: unknown[] = [];
    let paramIdx = 1;

    if (input.name !== undefined) {
      fields.push(`name = $${paramIdx++}`);
      values.push(input.name);
    }
    if (input.area !== undefined) {
      fields.push(`area = $${paramIdx++}`);
      values.push(input.area);
    }
    if (input.address !== undefined) {
      fields.push(`address = $${paramIdx++}`);
      values.push(input.address || null);
    }
    if (input.phone_number !== undefined) {
      fields.push(`phone_number = $${paramIdx++}`);
      values.push(input.phone_number || null);
    }
    if (input.is_active !== undefined) {
      fields.push(`is_active = $${paramIdx++}`);
      values.push(input.is_active);
    }

    if (fields.length === 0) {
      const store = await this.getStoreById(id, true);
      if (!store) {
        const error = new Error("Store not found");
        (error as unknown as { status: number }).status = 404;
        throw error;
      }
      return store;
    }

    values.push(id);
    const sql = `UPDATE stores SET ${fields.join(", ")} WHERE id = $${paramIdx} RETURNING id, name, area, address, phone_number, is_active, created_at, updated_at`;

    try {
      const result = await query<Store>(sql, values);
      if (result.rows.length === 0) {
        const error = new Error("Store not found");
        (error as unknown as { status: number }).status = 404;
        throw error;
      }
      return result.rows[0]!;
    } catch (err: unknown) {
      if (
        typeof err === "object" &&
        err !== null &&
        "code" in err &&
        (err as { code: string }).code === "23505"
      ) {
        const error = new Error("An active store already serves this area");
        (error as unknown as { status: number }).status = 409;
        throw error;
      }
      throw err;
    }
  }

  /**
   * List stores.
   * If includeInactive is false (customer/public view), returns ONLY active stores.
   */
  static async listStores(includeInactive = false): Promise<Store[]> {
    const sql = includeInactive
      ? `SELECT id, name, area, address, phone_number, is_active, created_at, updated_at FROM stores ORDER BY name ASC`
      : `SELECT id, name, area, address, phone_number, is_active, created_at, updated_at FROM stores WHERE is_active = TRUE ORDER BY name ASC`;

    const result = await query<Store>(sql);
    return result.rows;
  }

  /**
   * Get specific store by ID.
   * If includeInactive is false, returns store only if active.
   */
  static async getStoreById(
    id: string,
    includeInactive = false
  ): Promise<Store | null> {
    const sql = includeInactive
      ? `SELECT id, name, area, address, phone_number, is_active, created_at, updated_at FROM stores WHERE id = $1`
      : `SELECT id, name, area, address, phone_number, is_active, created_at, updated_at FROM stores WHERE id = $1 AND is_active = TRUE`;

    const result = await query<Store>(sql, [id]);
    return result.rows[0] || null;
  }

  /**
   * Customer: Find active store serving a specific area (case-insensitive).
   */
  static async getStoreByArea(area: string): Promise<Store | null> {
    const result = await query<Store>(
      `SELECT id, name, area, address, phone_number, is_active, created_at, updated_at
       FROM stores
       WHERE LOWER(area) = LOWER($1) AND is_active = TRUE`,
      [area]
    );
    return result.rows[0] || null;
  }
}
