import { Router } from "express";
import { LoyaltyController } from "./loyalty.controller.js";
import { authenticate, requireRole } from "../../middleware/auth.middleware.js";

const loyaltyRouter = Router();

// Protect all loyalty routes with Bearer JWT and role restrictions (Customer & Super Admin only)
loyaltyRouter.use(authenticate, requireRole("customer", "super_admin"));

loyaltyRouter.get("/wallet", LoyaltyController.getWallet);
loyaltyRouter.get("/transactions", LoyaltyController.getTransactions);

export default loyaltyRouter;
