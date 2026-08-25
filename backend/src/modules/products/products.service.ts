import { query } from "../../db/index.js";
import type { CreateProductInput, UpdateProductInput } from "./products.validation.js";

export interface Product {
  id: string;
  store_id: string;
  name: string;
  description: string | null;
  price: number;
  category: string | null;
  image_url: string | null;
  is_available: boolean;
  loyalty_points_per_unit: number;
  created_at: Date;
  updated_at: Date;
}

export class ProductsService {
  /**
   * Create a new product.
   * Verifies that target store exists and is active.
   */
  static async createProduct(input: CreateProductInput): Promise<Product> {
    const storeRes = await query<{ is_active: boolean }>(
      `SELECT is_active FROM stores WHERE id = $1`,
      [input.store_id]
    );

    if (storeRes.rows.length === 0) {
      const err = new Error("Target store not found");
      (err as unknown as { status: number }).status = 404;
      throw err;
    }

    const result = await query<Product>(
      `INSERT INTO products (store_id, name, description, price, category, image_url, is_available, loyalty_points_per_unit)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING id, store_id, name, description, price, category, image_url, is_available, loyalty_points_per_unit, created_at, updated_at`,
      [
        input.store_id,
        input.name,
        input.description || null,
        input.price,
        input.category || null,
        input.image_url || null,
        input.is_available ?? true,
        input.loyalty_points_per_unit ?? 0,
      ]
    );

    return result.rows[0]!;
  }

  /**
   * List products belonging to a store.
   * Customers cannot access products of an inactive store or see unavailable products.
   * Staff/Managers/Admin can see all products if authorized.
   */
  static async listProductsByStore(
    storeId: string,
    includeUnavailable = false,
    bypassStoreActiveCheck = false
  ): Promise<Product[]> {
    // Verify store status
    const storeRes = await query<{ is_active: boolean }>(
      `SELECT is_active FROM stores WHERE id = $1`,
      [storeId]
    );

    if (storeRes.rows.length === 0) {
      const err = new Error("Store not found or unavailable");
      (err as unknown as { status: number }).status = 404;
      throw err;
    }

    const isStoreActive = storeRes.rows[0]!.is_active;
    if (!isStoreActive && !bypassStoreActiveCheck) {
      const err = new Error("Store not found or unavailable");
      (err as unknown as { status: number }).status = 404;
      throw err;
    }

    const sql = includeUnavailable
      ? `SELECT id, store_id, name, description, price, category, image_url, is_available, loyalty_points_per_unit, created_at, updated_at FROM products WHERE store_id = $1 ORDER BY name ASC`
      : `SELECT id, store_id, name, description, price, category, image_url, is_available, loyalty_points_per_unit, created_at, updated_at FROM products WHERE store_id = $1 AND is_available = TRUE ORDER BY name ASC`;

    const result = await query<Product>(sql, [storeId]);
    return result.rows;
  }

  /**
   * Get single product by ID.
   */
  static async getProductById(
    id: string,
    includeUnavailable = false,
    bypassStoreActiveCheck = false
  ): Promise<Product | null> {
    const result = await query<Product & { store_active: boolean }>(
      `SELECT p.id, p.store_id, p.name, p.description, p.price, p.category, p.image_url,
              p.is_available, p.loyalty_points_per_unit, p.created_at, p.updated_at,
              s.is_active AS store_active
       FROM products p
       JOIN stores s ON s.id = p.store_id
       WHERE p.id = $1`,
      [id]
    );

    const row = result.rows[0];
    if (!row) return null;

    if (!row.store_active && !bypassStoreActiveCheck) {
      return null;
    }

    if (!row.is_available && !includeUnavailable) {
      return null;
    }

    return row;
  }

  /**
   * Update product details.
   */
  static async updateProduct(
    id: string,
    input: UpdateProductInput
  ): Promise<Product> {
    const fields: string[] = [];
    const values: unknown[] = [];
    let paramIdx = 1;

    if (input.name !== undefined) {
      fields.push(`name = $${paramIdx++}`);
      values.push(input.name);
    }
    if (input.description !== undefined) {
      fields.push(`description = $${paramIdx++}`);
      values.push(input.description || null);
    }
    if (input.price !== undefined) {
      fields.push(`price = $${paramIdx++}`);
      values.push(input.price);
    }
    if (input.category !== undefined) {
      fields.push(`category = $${paramIdx++}`);
      values.push(input.category || null);
    }
    if (input.image_url !== undefined) {
      fields.push(`image_url = $${paramIdx++}`);
      values.push(input.image_url || null);
    }
    if (input.is_available !== undefined) {
      fields.push(`is_available = $${paramIdx++}`);
      values.push(input.is_available);
    }
    if (input.loyalty_points_per_unit !== undefined) {
      fields.push(`loyalty_points_per_unit = $${paramIdx++}`);
      values.push(input.loyalty_points_per_unit);
    }

    if (fields.length === 0) {
      const prod = await this.getProductById(id, true, true);
      if (!prod) {
        const error = new Error("Product not found");
        (error as unknown as { status: number }).status = 404;
        throw error;
      }
      return prod;
    }

    values.push(id);
    const sql = `UPDATE products SET ${fields.join(", ")} WHERE id = $${paramIdx} RETURNING id, store_id, name, description, price, category, image_url, is_available, loyalty_points_per_unit, created_at, updated_at`;

    const result = await query<Product>(sql, values);
    if (result.rows.length === 0) {
      const error = new Error("Product not found");
      (error as unknown as { status: number }).status = 404;
      throw error;
    }

    return result.rows[0]!;
  }

  /**
   * Delete product by ID.
   */
  static async deleteProduct(id: string): Promise<boolean> {
    const result = await query(`DELETE FROM products WHERE id = $1`, [id]);
    return (result.rowCount ?? 0) > 0;
  }
}
