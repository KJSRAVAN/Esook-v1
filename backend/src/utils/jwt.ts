import jwt from "jsonwebtoken";
import { env } from "../config/env.js";

export type UserRole =
  | "customer"
  | "store_staff"
  | "store_manager"
  | "delivery_rider"
  | "super_admin";

const VALID_ROLES: Set<UserRole> = new Set([
  "customer",
  "store_staff",
  "store_manager",
  "delivery_rider",
  "super_admin",
]);

export interface AuthUserPayload {
  sub: string;
  role: UserRole;
  store_id: string | null;
}

const JWT_EXPIRY = "24h";

/**
 * Sign JWT access token with payload containing ONLY sub, role, store_id.
 * Never includes passwords, email, phone number, or address.
 */
export function signAccessToken(user: {
  id: string;
  role: UserRole;
  store_id?: string | null | undefined;
}): string {
  const payload: AuthUserPayload = {
    sub: user.id,
    role: user.role,
    store_id: user.store_id ?? null,
  };
  return jwt.sign(payload, env.JWT_SECRET, { expiresIn: JWT_EXPIRY });
}

/**
 * Verify JWT access token and explicitly validate claims.
 * Rejects malformed sub, role, or store_id claims.
 */
export function verifyAccessToken(token: string): AuthUserPayload {
  const decoded = jwt.verify(token, env.JWT_SECRET) as Record<string, unknown>;

  if (typeof decoded.sub !== "string" || !decoded.sub.trim()) {
    throw new Error("Invalid token claim: sub must be a non-empty string");
  }

  if (
    typeof decoded.role !== "string" ||
    !VALID_ROLES.has(decoded.role as UserRole)
  ) {
    throw new Error("Invalid token claim: role is invalid");
  }

  if (decoded.store_id !== null && typeof decoded.store_id !== "string") {
    throw new Error("Invalid token claim: store_id must be a string or null");
  }

  return {
    sub: decoded.sub,
    role: decoded.role as UserRole,
    store_id: (decoded.store_id as string | null) ?? null,
  };
}
