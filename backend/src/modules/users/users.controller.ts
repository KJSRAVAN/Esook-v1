import type { Request, Response } from "express";
import { UsersService } from "./users.service.js";
import {
  validateCreateUser,
  validateUpdateUser,
  isValidUuid,
} from "./users.validation.js";

function handleControllerError(err: unknown, res: Response): Response {
  const status = (err as { status?: number }).status;
  if (status && status >= 400 && status < 500) {
    const message = err instanceof Error ? err.message : "Request failed";
    return res.status(status).json({ error: message });
  }

  console.error("Unexpected Users Controller Error:", err);
  return res.status(500).json({ error: "Internal server error" });
}

export class UsersController {
  static async createUser(req: Request, res: Response) {
    try {
      const validation = validateCreateUser(req.body);
      if (!validation.valid || !validation.sanitized) {
        return res.status(400).json({ errors: validation.errors });
      }

      const user = await UsersService.createUser(validation.sanitized);
      return res.status(201).json({ user });
    } catch (err: unknown) {
      return handleControllerError(err, res);
    }
  }

  static async listUsers(req: Request, res: Response) {
    try {
      const role = typeof req.query.role === "string" ? req.query.role.trim() : undefined;
      const storeId =
        typeof req.query.store_id === "string" ? req.query.store_id.trim() : undefined;
      const isActive =
        req.query.is_active === "true"
          ? true
          : req.query.is_active === "false"
          ? false
          : undefined;

      const users = await UsersService.listUsers(role, storeId, isActive);
      return res.status(200).json({ users });
    } catch (err: unknown) {
      return handleControllerError(err, res);
    }
  }

  static async getUserById(req: Request, res: Response) {
    try {
      const userId = String(req.params.id);
      if (!userId || !isValidUuid(userId)) {
        return res.status(400).json({ error: "Valid User ID UUID is required" });
      }

      const user = await UsersService.getUserById(userId);
      return res.status(200).json({ user });
    } catch (err: unknown) {
      return handleControllerError(err, res);
    }
  }

  static async updateUser(req: Request, res: Response) {
    try {
      const userId = String(req.params.id);
      if (!userId || !isValidUuid(userId)) {
        return res.status(400).json({ error: "Valid User ID UUID is required" });
      }

      const validation = validateUpdateUser(req.body);
      if (!validation.valid || !validation.sanitized) {
        return res.status(400).json({ errors: validation.errors });
      }

      const user = await UsersService.updateUser(userId, validation.sanitized);
      return res.status(200).json({ user });
    } catch (err: unknown) {
      return handleControllerError(err, res);
    }
  }
}
