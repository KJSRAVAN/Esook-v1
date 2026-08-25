import type { Request, Response } from "express";
import { CartService } from "./cart.service.js";
import {
  validateAddCartItem,
  validateUpdateCartItem,
  isValidUuid,
} from "./cart.validation.js";

function handleControllerError(err: unknown, res: Response): Response {
  const status = (err as { status?: number }).status;
  if (status && status >= 400 && status < 500) {
    const message = err instanceof Error ? err.message : "Request failed";
    return res.status(status).json({ error: message });
  }

  console.error("Unexpected Cart Controller Error:", err);
  return res.status(500).json({ error: "Internal server error" });
}

export class CartController {
  static async getCart(req: Request, res: Response) {
    try {
      const userId = req.user!.sub;
      const storeId = (req.query.store_id || req.body.store_id) as string;

      if (!storeId || !isValidUuid(storeId)) {
        return res.status(400).json({ error: "Valid store_id query parameter is required" });
      }

      const cart = await CartService.getCart(userId, storeId);
      return res.status(200).json({ cart });
    } catch (err: unknown) {
      return handleControllerError(err, res);
    }
  }

  static async addItem(req: Request, res: Response) {
    try {
      const userId = req.user!.sub;
      const validation = validateAddCartItem(req.body);

      if (!validation.valid || !validation.sanitized) {
        return res.status(400).json({ errors: validation.errors });
      }

      const cart = await CartService.addCartItem(userId, validation.sanitized);
      return res.status(200).json({ cart });
    } catch (err: unknown) {
      return handleControllerError(err, res);
    }
  }

  static async updateItemQuantity(req: Request, res: Response) {
    try {
      const userId = req.user!.sub;
      const productId = String(req.params.productId);
      const validation = validateUpdateCartItem(productId, req.body);

      if (!validation.valid || !validation.sanitized) {
        return res.status(400).json({ errors: validation.errors });
      }

      const cart = await CartService.updateCartItemQuantity(userId, validation.sanitized);
      return res.status(200).json({ cart });
    } catch (err: unknown) {
      return handleControllerError(err, res);
    }
  }

  static async removeItem(req: Request, res: Response) {
    try {
      const userId = req.user!.sub;
      const productId = String(req.params.productId);
      const storeId = (req.query.store_id || req.body.store_id) as string;

      if (!storeId || !isValidUuid(storeId)) {
        return res.status(400).json({ error: "Valid store_id is required" });
      }
      if (!productId || !isValidUuid(productId)) {
        return res.status(400).json({ error: "Valid productId parameter is required" });
      }

      const cart = await CartService.removeCartItem(userId, storeId, productId);
      return res.status(200).json({ cart });
    } catch (err: unknown) {
      return handleControllerError(err, res);
    }
  }

  static async clearCart(req: Request, res: Response) {
    try {
      const userId = req.user!.sub;
      const storeId = (req.query.store_id || req.body.store_id) as string;

      if (!storeId || !isValidUuid(storeId)) {
        return res.status(400).json({ error: "Valid store_id is required" });
      }

      const cart = await CartService.clearCart(userId, storeId);
      return res.status(200).json({ cart });
    } catch (err: unknown) {
      return handleControllerError(err, res);
    }
  }
}
