import { Router } from "express";
import { CartController } from "./cart.controller.js";
import { authenticate, requireRole } from "../../middleware/auth.middleware.js";

const cartRouter = Router();

// Customer-only authentication and role protection for all cart routes
cartRouter.use(authenticate, requireRole("customer"));

cartRouter.get("/", CartController.getCart);
cartRouter.post("/items", CartController.addItem);
cartRouter.patch("/items/:productId", CartController.updateItemQuantity);
cartRouter.delete("/items/:productId", CartController.removeItem);
cartRouter.delete("/", CartController.clearCart);

export default cartRouter;
