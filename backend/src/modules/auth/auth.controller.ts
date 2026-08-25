import type { Request, Response } from "express";
import { AuthService } from "./auth.service.js";
import {
  validateCustomerSignup,
  validateLogin,
  validateRequestMagicLink,
  validateVerifyMagicLink,
} from "./auth.validation.js";

function handleControllerError(err: unknown, res: Response): Response {
  const status = (err as { status?: number }).status;
  if (status && status >= 400 && status < 500) {
    const message = err instanceof Error ? err.message : "Request failed";
    return res.status(status).json({ error: message });
  }

  // Unexpected internal/database error: log server-side, return generic 500 response without leaking internal details
  console.error("Unexpected Controller Error:", err);
  return res.status(500).json({ error: "Internal server error" });
}

export class AuthController {
  static async signup(req: Request, res: Response) {
    try {
      const validation = validateCustomerSignup(req.body);
      if (!validation.valid || !validation.sanitized) {
        return res.status(400).json({ errors: validation.errors });
      }

      const result = await AuthService.signupCustomer(validation.sanitized);
      return res.status(201).json(result);
    } catch (err: unknown) {
      return handleControllerError(err, res);
    }
  }

  static async login(req: Request, res: Response) {
    try {
      const validation = validateLogin(req.body);
      if (!validation.valid || !validation.sanitized) {
        return res.status(400).json({ errors: validation.errors });
      }

      const result = await AuthService.login(validation.sanitized);
      return res.status(200).json(result);
    } catch (err: unknown) {
      return handleControllerError(err, res);
    }
  }

  static async requestMagicLink(req: Request, res: Response) {
    try {
      const validation = validateRequestMagicLink(req.body);
      if (!validation.valid || !validation.sanitized) {
        return res.status(400).json({ errors: validation.errors });
      }

      const result = await AuthService.requestMagicLink(validation.sanitized);
      return res.status(200).json(result);
    } catch (err: unknown) {
      return handleControllerError(err, res);
    }
  }

  static async verifyMagicLink(req: Request, res: Response) {
    try {
      const validation = validateVerifyMagicLink(req.body);
      if (!validation.valid || !validation.sanitized) {
        return res.status(400).json({ errors: validation.errors });
      }

      const result = await AuthService.verifyMagicLink(validation.sanitized);
      return res.status(200).json(result);
    } catch (err: unknown) {
      return handleControllerError(err, res);
    }
  }

  static async getMe(req: Request, res: Response) {
    try {
      if (!req.user) {
        return res.status(401).json({ error: "Unauthorized" });
      }
      const user = await AuthService.getCurrentUser(req.user.sub);
      return res.status(200).json({ user });
    } catch (err: unknown) {
      return handleControllerError(err, res);
    }
  }
}
