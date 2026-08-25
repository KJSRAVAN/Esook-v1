import { Router } from "express";
import rateLimit from "express-rate-limit";
import { AuthController } from "./auth.controller.js";
import { authenticate } from "../../middleware/auth.middleware.js";

const authRouter = Router();

// Rate limiting for authentication endpoints to prevent brute-force attacks
const authRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  limit: 10, // Max 10 requests per 15 min per IP
  standardHeaders: "draft-7",
  legacyHeaders: false,
  message: { error: "Too many authentication attempts. Please try again later." },
});

// Customer self-signup
authRouter.post("/signup", authRateLimiter, AuthController.signup);

// Shared login (customer, staff, manager, rider)
authRouter.post("/login", authRateLimiter, AuthController.login);

// Super admin magic link flow
authRouter.post(
  "/admin/request-magic-link",
  authRateLimiter,
  AuthController.requestMagicLink
);
authRouter.post(
  "/admin/verify-magic-link",
  authRateLimiter,
  AuthController.verifyMagicLink
);

// Authenticated current user profile
authRouter.get("/me", authenticate, AuthController.getMe);

export default authRouter;
