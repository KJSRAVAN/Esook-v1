export interface CreateStoreInput {
  name: string;
  area: string;
  address?: string | undefined;
  phone_number?: string | undefined;
  is_active?: boolean | undefined;
}

export interface UpdateStoreInput {
  name?: string | undefined;
  area?: string | undefined;
  address?: string | undefined;
  phone_number?: string | undefined;
  is_active?: boolean | undefined;
}

export function validateCreateStore(data: unknown): {
  valid: boolean;
  errors: string[];
  sanitized?: CreateStoreInput;
} {
  const errors: string[] = [];
  if (!data || typeof data !== "object") {
    return { valid: false, errors: ["Invalid payload format"] };
  }

  const payload = data as Record<string, unknown>;
  const name = typeof payload.name === "string" ? payload.name.trim() : "";
  const area = typeof payload.area === "string" ? payload.area.trim() : "";
  const address = typeof payload.address === "string" ? payload.address.trim() : undefined;
  const phone_number = typeof payload.phone_number === "string" ? payload.phone_number.trim() : undefined;
  const is_active = typeof payload.is_active === "boolean" ? payload.is_active : true;

  if (!name) {
    errors.push("Store name is required");
  }
  if (!area) {
    errors.push("Area is required");
  }

  if (errors.length > 0) {
    return { valid: false, errors };
  }

  return {
    valid: true,
    errors: [],
    sanitized: { name, area, address, phone_number, is_active },
  };
}

export function validateUpdateStore(data: unknown): {
  valid: boolean;
  errors: string[];
  sanitized?: UpdateStoreInput;
} {
  const errors: string[] = [];
  if (!data || typeof data !== "object") {
    return { valid: false, errors: ["Invalid payload format"] };
  }

  const payload = data as Record<string, unknown>;
  const sanitized: UpdateStoreInput = {};

  if (payload.name !== undefined) {
    if (typeof payload.name === "string" && payload.name.trim()) {
      sanitized.name = payload.name.trim();
    } else {
      errors.push("Store name cannot be empty");
    }
  }

  if (payload.area !== undefined) {
    if (typeof payload.area === "string" && payload.area.trim()) {
      sanitized.area = payload.area.trim();
    } else {
      errors.push("Area cannot be empty");
    }
  }

  if (payload.address !== undefined) {
    sanitized.address = typeof payload.address === "string" ? payload.address.trim() : undefined;
  }

  if (payload.phone_number !== undefined) {
    sanitized.phone_number = typeof payload.phone_number === "string" ? payload.phone_number.trim() : undefined;
  }

  if (payload.is_active !== undefined) {
    if (typeof payload.is_active === "boolean") {
      sanitized.is_active = payload.is_active;
    } else {
      errors.push("is_active must be a boolean");
    }
  }

  if (errors.length > 0) {
    return { valid: false, errors };
  }

  return { valid: true, errors: [], sanitized };
}
