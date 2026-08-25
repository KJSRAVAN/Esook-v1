import type { Request, Response, NextFunction } from "express";
import { verifyAccessToken, type AuthUserPayload, type UserRole } from "../utils/jwt.js";

declare global {
  namespace Express {
    interface Request {
      user?: AuthUserPayload;
    }
  }
}

/**
 * Middleware: Verify Bearer JWT in Authorization header.
 * Attaches decoded payload { sub, role, store_id } to req.user.
 */
export function authenticate(req: Request, res: Response, next: NextFunction) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return res
      .status(401)
      .json({ error: "Unauthorized: Missing or invalid authorization header" });
  }

  const token = authHeader.split(" ")[1];
  if (!token) {
    return res.status(401).json({ error: "Unauthorized: Missing token" });
  }

  try {
    const decoded = verifyAccessToken(token);
    req.user = decoded;
    next();
  } catch (_err) {
    return res
      .status(401)
      .json({ error: "Unauthorized: Invalid or expired token" });
  }
}

/**
 * Middleware: Optional Bearer JWT verification.
 * If Authorization header is present, populates req.user; otherwise proceeds as anonymous.
 */
export function optionalAuthenticate(req: Request, _res: Response, next: NextFunction) {
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith("Bearer ")) {
    const token = authHeader.split(" ")[1];
    if (token) {
      try {
        req.user = verifyAccessToken(token);
      } catch (_err) {
        // Ignore invalid token on public routes
      }
    }
  }
  next();
}

/**
 * Middleware: Enforce server-side role check.
 */
export function requireRole(...allowedRoles: UserRole[]) {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!req.user || !allowedRoles.includes(req.user.role)) {
      return res
        .status(403)
        .json({ error: "Forbidden: Insufficient role permissions" });
    }
    next();
  };
}

/**
 * Middleware: Restrict store staff/manager to their assigned store_id.
 * Super admin bypasses store restrictions.
 * Never trusts frontend-supplied store_id override.
 */
export function requireOwnStore(req: Request, res: Response, next: NextFunction) {
  if (!req.user) {
    return res.status(401).json({ error: "Unauthorized" });
  }

  // Super admin bypasses store ownership restrictions
  if (req.user.role === "super_admin") {
    return next();
  }

  // Store staff and managers MUST have a valid store_id assigned
  if (req.user.role === "store_staff" || req.user.role === "store_manager") {
    if (!req.user.store_id) {
      return res
        .status(403)
        .json({ error: "Forbidden: Staff account is not associated with any store" });
    }

    const targetStoreId = (req.params.storeId ||
      req.query.store_id ||
      req.body.store_id) as string | undefined;

    // If target store is explicitly supplied, it MUST match the user's assigned store_id
    if (targetStoreId && targetStoreId !== req.user.store_id) {
      return res
        .status(403)
        .json({ error: "Forbidden: Access restricted to assigned store only" });
    }

    return next();
  }

  // Customers and delivery riders cannot perform store-scoped staff operations
  return res.status(403).json({ error: "Forbidden: Store access required" });
}
