import type { Request, Response } from "express";
import { LoyaltyService } from "./loyalty.service.js";

function handleControllerError(err: unknown, res: Response): Response {
  const status = (err as { status?: number }).status;
  if (status && status >= 400 && status < 500) {
    const message = err instanceof Error ? err.message : "Request failed";
    return res.status(status).json({ error: message });
  }

  console.error("Unexpected Loyalty Controller Error:", err);
  return res.status(500).json({ error: "Internal server error" });
}

export class LoyaltyController {
  static async getWallet(req: Request, res: Response) {
    try {
      const user = req.user!;
      let targetUserId = user.sub;

      // Super admin can inspect customer wallet via query ?user_id=...
      if (
        user.role === "super_admin" &&
        typeof req.query.user_id === "string" &&
        req.query.user_id.trim()
      ) {
        targetUserId = req.query.user_id.trim();
      }

      const wallet = await LoyaltyService.getWallet(targetUserId);
      return res.status(200).json({ wallet });
    } catch (err: unknown) {
      return handleControllerError(err, res);
    }
  }

  static async getTransactions(req: Request, res: Response) {
    try {
      const user = req.user!;
      let targetUserId = user.sub;

      // Super admin can inspect customer transactions via query ?user_id=...
      if (
        user.role === "super_admin" &&
        typeof req.query.user_id === "string" &&
        req.query.user_id.trim()
      ) {
        targetUserId = req.query.user_id.trim();
      }

      const transactions = await LoyaltyService.getTransactions(targetUserId);
      return res.status(200).json({ transactions });
    } catch (err: unknown) {
      return handleControllerError(err, res);
    }
  }
}
