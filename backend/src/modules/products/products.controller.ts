import type { Request, Response } from "express";
import { ProductsService } from "./products.service.js";
import { validateCreateProduct, validateUpdateProduct } from "./products.validation.js";

function handleControllerError(err: unknown, res: Response): Response {
  const status = (err as { status?: number }).status;
  if (status && status >= 400 && status < 500) {
    const message = err instanceof Error ? err.message : "Request failed";
    return res.status(status).json({ error: message });
  }

  console.error("Unexpected Products Controller Error:", err);
  return res.status(500).json({ error: "Internal server error" });
}

export class ProductsController {
  static async create(req: Request, res: Response) {
    try {
      // Store staff and managers MUST use their authenticated store_id
      if (req.user?.role === "store_staff" || req.user?.role === "store_manager") {
        if (!req.user.store_id) {
          return res.status(403).json({ error: "Forbidden: Staff account is not assigned to a store" });
        }
        // Force target store_id to authenticated user's store_id
        req.body.store_id = req.user.store_id;
      }

      const validation = validateCreateProduct(req.body);
      if (!validation.valid || !validation.sanitized) {
        return res.status(400).json({ errors: validation.errors });
      }

      const product = await ProductsService.createProduct(validation.sanitized);
      return res.status(201).json({ product });
    } catch (err: unknown) {
      return handleControllerError(err, res);
    }
  }

  static async listByStore(req: Request, res: Response) {
    try {
      const storeId = String(req.params.storeId);
      if (!storeId) {
        return res.status(400).json({ error: "storeId parameter is required" });
      }

      const user = req.user;
      const isSuperAdmin = user?.role === "super_admin";
      const isStoreStaffOrManager =
        user &&
        (user.role === "store_staff" || user.role === "store_manager") &&
        user.store_id === storeId;

      // Staff/Manager for this store or super admin can see unavailable products & access inactive store
      const canAccessInternalCatalog = Boolean(isSuperAdmin || isStoreStaffOrManager);

      const products = await ProductsService.listProductsByStore(
        storeId,
        canAccessInternalCatalog,
        canAccessInternalCatalog
      );

      return res.status(200).json({ products });
    } catch (err: unknown) {
      return handleControllerError(err, res);
    }
  }

  static async getById(req: Request, res: Response) {
    try {
      const id = String(req.params.id);
      if (!id) {
        return res.status(400).json({ error: "Product ID is required" });
      }

      const user = req.user;
      const isSuperAdmin = user?.role === "super_admin";

      // First query product to check store ownership if staff
      let product = await ProductsService.getProductById(id, true, true);
      if (!product) {
        return res.status(404).json({ error: "Product not found or unavailable" });
      }

      const isStoreStaffOrManager =
        user &&
        (user.role === "store_staff" || user.role === "store_manager") &&
        user.store_id === product.store_id;

      const canAccessInternalCatalog = Boolean(isSuperAdmin || isStoreStaffOrManager);

      if (!canAccessInternalCatalog) {
        // Customer view: check if store and product are available
        product = await ProductsService.getProductById(id, false, false);
        if (!product) {
          return res.status(404).json({ error: "Product not found or unavailable" });
        }
      }

      return res.status(200).json({ product });
    } catch (err: unknown) {
      return handleControllerError(err, res);
    }
  }

  static async update(req: Request, res: Response) {
    try {
      const id = String(req.params.id);
      if (!id) {
        return res.status(400).json({ error: "Product ID is required" });
      }

      // Check cross-store isolation for staff/managers
      const existingProduct = await ProductsService.getProductById(id, true, true);
      if (!existingProduct) {
        return res.status(404).json({ error: "Product not found" });
      }

      if (req.user?.role === "store_staff" || req.user?.role === "store_manager") {
        if (!req.user.store_id || req.user.store_id !== existingProduct.store_id) {
          return res.status(403).json({
            error: "Forbidden: Cannot modify products belonging to another store",
          });
        }
      }

      const validation = validateUpdateProduct(req.body);
      if (!validation.valid || !validation.sanitized) {
        return res.status(400).json({ errors: validation.errors });
      }

      const updatedProduct = await ProductsService.updateProduct(
        id,
        validation.sanitized
      );
      return res.status(200).json({ product: updatedProduct });
    } catch (err: unknown) {
      return handleControllerError(err, res);
    }
  }

  static async delete(req: Request, res: Response) {
    try {
      const id = String(req.params.id);
      if (!id) {
        return res.status(400).json({ error: "Product ID is required" });
      }

      const existingProduct = await ProductsService.getProductById(id, true, true);
      if (!existingProduct) {
        return res.status(404).json({ error: "Product not found" });
      }

      if (req.user?.role === "store_manager") {
        if (!req.user.store_id || req.user.store_id !== existingProduct.store_id) {
          return res.status(403).json({
            error: "Forbidden: Cannot delete products belonging to another store",
          });
        }
      }

      await ProductsService.deleteProduct(id);
      return res.status(200).json({ message: "Product deleted successfully" });
    } catch (err: unknown) {
      return handleControllerError(err, res);
    }
  }
}
