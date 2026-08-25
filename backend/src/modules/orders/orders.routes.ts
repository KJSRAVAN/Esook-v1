import { Router } from "express";
import { OrdersController } from "./orders.controller.js";
import { authenticate, requireRole } from "../../middleware/auth.middleware.js";

const ordersRouter = Router();

// Protect all order routes with Bearer JWT authentication
ordersRouter.use(authenticate);

// Customer Order Creation (Customer only)
ordersRouter.post("/", requireRole("customer"), OrdersController.createOrder);

// Order Listing (Customer, Store Staff, Manager, Rider, Super Admin)
ordersRouter.get("/", OrdersController.listOrders);

// Order Retrieval by ID (Customer, Store Staff, Manager, Rider, Super Admin)
ordersRouter.get("/:id", OrdersController.getOrderById);

// Order Status Update (Store Staff, Store Manager, Delivery Rider, Super Admin)
ordersRouter.patch(
  "/:id/status",
  requireRole("store_staff", "store_manager", "delivery_rider", "super_admin"),
  OrdersController.updateOrderStatus
);

export default ordersRouter;
