import { Router } from "express";
import { StoresController } from "./stores.controller.js";
import { authenticate, optionalAuthenticate, requireRole } from "../../middleware/auth.middleware.js";

const storesRouter = Router();

// Customer / Public Store Discovery endpoints (supports optional authentication for super admin)
storesRouter.get("/", optionalAuthenticate, StoresController.list);
storesRouter.get("/area/:area", optionalAuthenticate, StoresController.getByArea);
storesRouter.get("/:id", optionalAuthenticate, StoresController.getById);

// Super Admin Store Management endpoints
storesRouter.post(
  "/",
  authenticate,
  requireRole("super_admin"),
  StoresController.create
);

storesRouter.patch(
  "/:id",
  authenticate,
  requireRole("super_admin"),
  StoresController.update
);

export default storesRouter;
