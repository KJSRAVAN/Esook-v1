export interface CreateProductInput {
  store_id: string;
  name: string;
  description?: string | undefined;
  price: number;
  category?: string | undefined;
  image_url?: string | undefined;
  is_available?: boolean | undefined;
  loyalty_points_per_unit?: number | undefined;
}

export interface UpdateProductInput {
  name?: string | undefined;
  description?: string | undefined;
  price?: number | undefined;
  category?: string | undefined;
  image_url?: string | undefined;
  is_available?: boolean | undefined;
  loyalty_points_per_unit?: number | undefined;
}

export function validateCreateProduct(data: unknown): {
  valid: boolean;
  errors: string[];
  sanitized?: CreateProductInput;
} {
  const errors: string[] = [];
  if (!data || typeof data !== "object") {
    return { valid: false, errors: ["Invalid payload format"] };
  }

  const payload = data as Record<string, unknown>;

  const store_id = typeof payload.store_id === "string" ? payload.store_id.trim() : "";
  const name = typeof payload.name === "string" ? payload.name.trim() : "";
  const description = typeof payload.description === "string" ? payload.description.trim() : undefined;
  const price = typeof payload.price === "number" ? payload.price : Number(payload.price);
  const category = typeof payload.category === "string" ? payload.category.trim() : undefined;
  const image_url = typeof payload.image_url === "string" ? payload.image_url.trim() : undefined;
  const is_available = typeof payload.is_available === "boolean" ? payload.is_available : true;
  const loyalty_points_per_unit =
    payload.loyalty_points_per_unit !== undefined
      ? Number(payload.loyalty_points_per_unit)
      : 0;

  if (!store_id) {
    errors.push("store_id is required");
  }
  if (!name) {
    errors.push("Product name is required");
  }
  if (isNaN(price) || price < 0) {
    errors.push("Price must be a non-negative number");
  }
  if (
    isNaN(loyalty_points_per_unit) ||
    loyalty_points_per_unit < 0 ||
    !Number.isInteger(loyalty_points_per_unit)
  ) {
    errors.push("loyalty_points_per_unit must be a non-negative integer");
  }

  if (errors.length > 0) {
    return { valid: false, errors };
  }

  return {
    valid: true,
    errors: [],
    sanitized: {
      store_id,
      name,
      description,
      price,
      category,
      image_url,
      is_available,
      loyalty_points_per_unit,
    },
  };
}

export function validateUpdateProduct(data: unknown): {
  valid: boolean;
  errors: string[];
  sanitized?: UpdateProductInput;
} {
  const errors: string[] = [];
  if (!data || typeof data !== "object") {
    return { valid: false, errors: ["Invalid payload format"] };
  }

  const payload = data as Record<string, unknown>;
  const sanitized: UpdateProductInput = {};

  if (payload.name !== undefined) {
    if (typeof payload.name === "string" && payload.name.trim()) {
      sanitized.name = payload.name.trim();
    } else {
      errors.push("Product name cannot be empty");
    }
  }

  if (payload.description !== undefined) {
    sanitized.description =
      typeof payload.description === "string" ? payload.description.trim() : undefined;
  }

  if (payload.price !== undefined) {
    const p = Number(payload.price);
    if (isNaN(p) || p < 0) {
      errors.push("Price must be a non-negative number");
    } else {
      sanitized.price = p;
    }
  }

  if (payload.category !== undefined) {
    sanitized.category =
      typeof payload.category === "string" ? payload.category.trim() : undefined;
  }

  if (payload.image_url !== undefined) {
    sanitized.image_url =
      typeof payload.image_url === "string" ? payload.image_url.trim() : undefined;
  }

  if (payload.is_available !== undefined) {
    if (typeof payload.is_available === "boolean") {
      sanitized.is_available = payload.is_available;
    } else {
      errors.push("is_available must be a boolean");
    }
  }

  if (payload.loyalty_points_per_unit !== undefined) {
    const pts = Number(payload.loyalty_points_per_unit);
    if (isNaN(pts) || pts < 0 || !Number.isInteger(pts)) {
      errors.push("loyalty_points_per_unit must be a non-negative integer");
    } else {
      sanitized.loyalty_points_per_unit = pts;
    }
  }

  if (errors.length > 0) {
    return { valid: false, errors };
  }

  return { valid: true, errors: [], sanitized };
}
