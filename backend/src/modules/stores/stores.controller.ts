import type { Request, Response } from "express";
import { StoresService } from "./stores.service.js";
import { validateCreateStore, validateUpdateStore } from "./stores.validation.js";

function handleControllerError(err: unknown, res: Response): Response {
  const status = (err as { status?: number }).status;
  if (status && status >= 400 && status < 500) {
    const message = err instanceof Error ? err.message : "Request failed";
    return res.status(status).json({ error: message });
  }

  console.error("Unexpected Stores Controller Error:", err);
  return res.status(500).json({ error: "Internal server error" });
}

export class StoresController {
  static async create(req: Request, res: Response) {
    try {
      const validation = validateCreateStore(req.body);
      if (!validation.valid || !validation.sanitized) {
        return res.status(400).json({ errors: validation.errors });
      }

      const store = await StoresService.createStore(validation.sanitized);
      return res.status(201).json({ store });
    } catch (err: unknown) {
      return handleControllerError(err, res);
    }
  }

  static async update(req: Request, res: Response) {
    try {
      const id = String(req.params.id);
      if (!id) {
        return res.status(400).json({ error: "Store ID is required" });
      }

      const validation = validateUpdateStore(req.body);
      if (!validation.valid || !validation.sanitized) {
        return res.status(400).json({ errors: validation.errors });
      }

      const store = await StoresService.updateStore(id, validation.sanitized);
      return res.status(200).json({ store });
    } catch (err: unknown) {
      return handleControllerError(err, res);
    }
  }

  static async list(req: Request, res: Response) {
    try {
      // Super admin can request all stores via query ?all=true
      const isSuperAdmin = req.user?.role === "super_admin";
      const includeInactive = isSuperAdmin && req.query.all === "true";

      const stores = await StoresService.listStores(includeInactive);
      return res.status(200).json({ stores });
    } catch (err: unknown) {
      return handleControllerError(err, res);
    }
  }

  static async getById(req: Request, res: Response) {
    try {
      const id = String(req.params.id);
      if (!id) {
        return res.status(400).json({ error: "Store ID is required" });
      }

      const isSuperAdmin = req.user?.role === "super_admin";
      const store = await StoresService.getStoreById(id, isSuperAdmin);

      if (!store) {
        return res.status(404).json({ error: "Store not found or unavailable" });
      }

      return res.status(200).json({ store });
    } catch (err: unknown) {
      return handleControllerError(err, res);
    }
  }

  static async getByArea(req: Request, res: Response) {
    try {
      const area = String(req.params.area);
      if (!area) {
        return res.status(400).json({ error: "Area parameter is required" });
      }

      const store = await StoresService.getStoreByArea(area);
      if (!store) {
        return res
          .status(404)
          .json({ error: "No active store found for this area" });
      }

      return res.status(200).json({ store });
    } catch (err: unknown) {
      return handleControllerError(err, res);
    }
  }
}
