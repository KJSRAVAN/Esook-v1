import type { Request, Response } from "express";
import { OrdersService } from "./orders.service.js";
import {
  validateCreateOrder,
  validateUpdateOrderStatus,
  isValidUuid,
} from "./orders.validation.js";

function handleControllerError(err: unknown, res: Response): Response {
  const status = (err as { status?: number }).status;
  if (status && status >= 400 && status < 500) {
    const message = err instanceof Error ? err.message : "Request failed";
    return res.status(status).json({ error: message });
  }

  console.error("Unexpected Orders Controller Error:", err);
  return res.status(500).json({ error: "Internal server error" });
}

export class OrdersController {
  static async createOrder(req: Request, res: Response) {
    try {
      const customerId = req.user!.sub;
      const validation = validateCreateOrder(req.body);

      if (!validation.valid || !validation.sanitized) {
        return res.status(400).json({ errors: validation.errors });
      }

      const order = await OrdersService.createOrder(customerId, validation.sanitized);
      return res.status(201).json({ order });
    } catch (err: unknown) {
      return handleControllerError(err, res);
    }
  }

  static async listOrders(req: Request, res: Response) {
    try {
      const user = req.user!;
      const storeIdFilter =
        typeof req.query.store_id === "string" ? req.query.store_id.trim() : undefined;

      const orders = await OrdersService.listOrders(
        user.sub,
        user.role,
        user.store_id,
        storeIdFilter
      );

      return res.status(200).json({ orders });
    } catch (err: unknown) {
      return handleControllerError(err, res);
    }
  }

  static async getOrderById(req: Request, res: Response) {
    try {
      const user = req.user!;
      const orderId = String(req.params.id);

      if (!orderId || !isValidUuid(orderId)) {
        return res.status(400).json({ error: "Valid Order ID is required" });
      }

      const order = await OrdersService.getOrderById(
        orderId,
        user.sub,
        user.role,
        user.store_id
      );

      return res.status(200).json({ order });
    } catch (err: unknown) {
      return handleControllerError(err, res);
    }
  }

  static async updateOrderStatus(req: Request, res: Response) {
    try {
      const user = req.user!;
      const orderId = String(req.params.id);

      if (!orderId || !isValidUuid(orderId)) {
        return res.status(400).json({ error: "Valid Order ID is required" });
      }

      const validation = validateUpdateOrderStatus(req.body);
      if (!validation.valid || !validation.sanitized) {
        return res.status(400).json({ errors: validation.errors });
      }

      const order = await OrdersService.updateOrderStatus(
        orderId,
        validation.sanitized,
        user.sub,
        user.role,
        user.store_id
      );

      return res.status(200).json({ order });
    } catch (err: unknown) {
      return handleControllerError(err, res);
    }
  }
}
