import type { UserRole } from "../../utils/jwt.js";

export interface CreateUserInput {
  phone_number: string;
  full_name: string;
  role: UserRole;
  password?: string | undefined;
  email?: string | undefined;
  store_id?: string | undefined;
}

export interface UpdateUserInput {
  is_active?: boolean | undefined;
  store_id?: string | undefined;
  full_name?: string | undefined;
}

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const PHONE_REGEX = /^\+?[1-9]\d{7,14}$/;
const VALID_ROLES: Set<UserRole> = new Set([
  "customer",
  "store_staff",
  "store_manager",
  "delivery_rider",
  "super_admin",
]);

export function isValidUuid(id: string): boolean {
  return typeof id === "string" && UUID_REGEX.test(id);
}

export function validateCreateUser(data: unknown): {
  valid: boolean;
  errors: string[];
  sanitized?: CreateUserInput;
} {
  const errors: string[] = [];
  if (!data || typeof data !== "object") {
    return { valid: false, errors: ["Invalid payload format"] };
  }

  const payload = data as Record<string, unknown>;
  const phone_number = typeof payload.phone_number === "string" ? payload.phone_number.trim() : "";
  const full_name = typeof payload.full_name === "string" ? payload.full_name.trim() : "";
  const role = typeof payload.role === "string" ? (payload.role.trim() as UserRole) : ("" as UserRole);
  const password = typeof payload.password === "string" ? payload.password.trim() : undefined;
  const email = typeof payload.email === "string" ? payload.email.trim().toLowerCase() : undefined;
  const store_id = typeof payload.store_id === "string" ? payload.store_id.trim() : undefined;

  if (!phone_number || !PHONE_REGEX.test(phone_number)) {
    errors.push("Valid phone_number in E.164 format is required");
  }

  if (!full_name || full_name.length < 2) {
    errors.push("full_name must be at least 2 characters");
  }

  if (!VALID_ROLES.has(role)) {
    errors.push("Invalid role specified");
  }

  if (role === "store_staff" || role === "store_manager") {
    if (!store_id || !isValidUuid(store_id)) {
      errors.push("Valid store_id UUID is required for store staff and managers");
    }
  }

  if (role !== "super_admin" && (!password || password.length < 6)) {
    errors.push("password must be at least 6 characters");
  }

  if (store_id && !isValidUuid(store_id)) {
    errors.push("store_id must be a valid UUID");
  }

  if (errors.length > 0) {
    return { valid: false, errors };
  }

  return {
    valid: true,
    errors: [],
    sanitized: {
      phone_number,
      full_name,
      role,
      password,
      email,
      store_id,
    },
  };
}

export function validateUpdateUser(data: unknown): {
  valid: boolean;
  errors: string[];
  sanitized?: UpdateUserInput;
} {
  const errors: string[] = [];
  if (!data || typeof data !== "object") {
    return { valid: false, errors: ["Invalid payload format"] };
  }

  const payload = data as Record<string, unknown>;
  const is_active = typeof payload.is_active === "boolean" ? payload.is_active : undefined;
  const store_id = typeof payload.store_id === "string" ? payload.store_id.trim() : undefined;
  const full_name = typeof payload.full_name === "string" ? payload.full_name.trim() : undefined;

  if (store_id !== undefined && store_id !== "" && !isValidUuid(store_id)) {
    errors.push("store_id must be a valid UUID");
  }

  if (full_name !== undefined && full_name.length < 2) {
    errors.push("full_name must be at least 2 characters");
  }

  if (is_active === undefined && store_id === undefined && full_name === undefined) {
    errors.push("At least one field to update must be provided");
  }

  if (errors.length > 0) {
    return { valid: false, errors };
  }

  return {
    valid: true,
    errors: [],
    sanitized: {
      is_active,
      store_id: store_id === "" ? undefined : store_id,
      full_name,
    },
  };
}
