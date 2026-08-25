export interface AddCartItemInput {
  store_id: string;
  product_id: string;
  quantity: number;
}

export interface UpdateCartItemInput {
  store_id: string;
  product_id: string;
  quantity: number;
}

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function isValidUuid(id: string): boolean {
  return typeof id === "string" && UUID_REGEX.test(id);
}

export function validateAddCartItem(data: unknown): {
  valid: boolean;
  errors: string[];
  sanitized?: AddCartItemInput;
} {
  const errors: string[] = [];
  if (!data || typeof data !== "object") {
    return { valid: false, errors: ["Invalid payload format"] };
  }

  const payload = data as Record<string, unknown>;
  const store_id = typeof payload.store_id === "string" ? payload.store_id.trim() : "";
  const product_id = typeof payload.product_id === "string" ? payload.product_id.trim() : "";
  const quantity = Number(payload.quantity);

  if (!store_id || !isValidUuid(store_id)) {
    errors.push("Valid store_id UUID is required");
  }
  if (!product_id || !isValidUuid(product_id)) {
    errors.push("Valid product_id UUID is required");
  }
  if (isNaN(quantity) || quantity <= 0 || !Number.isInteger(quantity)) {
    errors.push("Quantity must be a positive integer");
  }

  if (errors.length > 0) {
    return { valid: false, errors };
  }

  return {
    valid: true,
    errors: [],
    sanitized: { store_id, product_id, quantity },
  };
}

export function validateUpdateCartItem(
  productIdParam: string,
  data: unknown
): {
  valid: boolean;
  errors: string[];
  sanitized?: UpdateCartItemInput;
} {
  const errors: string[] = [];
  if (!data || typeof data !== "object") {
    return { valid: false, errors: ["Invalid payload format"] };
  }

  const payload = data as Record<string, unknown>;
  const store_id = typeof payload.store_id === "string" ? payload.store_id.trim() : "";
  const product_id = String(productIdParam).trim();
  const quantity = Number(payload.quantity);

  if (!store_id || !isValidUuid(store_id)) {
    errors.push("Valid store_id UUID is required");
  }
  if (!product_id || !isValidUuid(product_id)) {
    errors.push("Valid product_id UUID is required");
  }
  if (isNaN(quantity) || quantity <= 0 || !Number.isInteger(quantity)) {
    errors.push("Quantity must be a positive integer");
  }

  if (errors.length > 0) {
    return { valid: false, errors };
  }

  return {
    valid: true,
    errors: [],
    sanitized: { store_id, product_id, quantity },
  };
}
