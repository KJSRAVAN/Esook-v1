import { Router } from "express";
import { ProductsController } from "./products.controller.js";
import { authenticate, optionalAuthenticate, requireRole } from "../../middleware/auth.middleware.js";

const productsRouter = Router();

// Public / Customer Product Discovery routes (supports optional authentication for store staff)
productsRouter.get("/store/:storeId", optionalAuthenticate, ProductsController.listByStore);
productsRouter.get("/:id", optionalAuthenticate, ProductsController.getById);

// Staff / Manager / Super Admin Protected Product Management routes
productsRouter.post(
  "/",
  authenticate,
  requireRole("store_staff", "store_manager", "super_admin"),
  ProductsController.create
);

productsRouter.patch(
  "/:id",
  authenticate,
  requireRole("store_staff", "store_manager", "super_admin"),
  ProductsController.update
);

productsRouter.delete(
  "/:id",
  authenticate,
  requireRole("store_manager", "super_admin"),
  ProductsController.delete
);

export default productsRouter;
