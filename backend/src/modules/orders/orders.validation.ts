export type FulfillmentType = "delivery" | "pickup";

export type OrderStatus =
  | "pending"
  | "accepted"
  | "preparing"
  | "out_for_delivery"
  | "completed"
  | "cancelled"
  | "rejected";

export interface CreateOrderInput {
  store_id: string;
  fulfillment_type: FulfillmentType;
  delivery_address?: string | undefined;
}

export interface UpdateOrderStatusInput {
  status: OrderStatus;
}

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const VALID_FULFILLMENT_TYPES: Set<FulfillmentType> = new Set(["delivery", "pickup"]);
const VALID_ORDER_STATUSES: Set<OrderStatus> = new Set([
  "pending",
  "accepted",
  "preparing",
  "out_for_delivery",
  "completed",
  "cancelled",
  "rejected",
]);

export function isValidUuid(id: string): boolean {
  return typeof id === "string" && UUID_REGEX.test(id);
}

export function validateCreateOrder(data: unknown): {
  valid: boolean;
  errors: string[];
  sanitized?: CreateOrderInput;
} {
  const errors: string[] = [];
  if (!data || typeof data !== "object") {
    return { valid: false, errors: ["Invalid payload format"] };
  }

  const payload = data as Record<string, unknown>;
  const store_id = typeof payload.store_id === "string" ? payload.store_id.trim() : "";
  const fulfillment_type =
    typeof payload.fulfillment_type === "string"
      ? (payload.fulfillment_type.trim() as FulfillmentType)
      : ("" as FulfillmentType);
  const delivery_address =
    typeof payload.delivery_address === "string"
      ? payload.delivery_address.trim()
      : undefined;

  if (!store_id || !isValidUuid(store_id)) {
    errors.push("Valid store_id UUID is required");
  }

  if (!VALID_FULFILLMENT_TYPES.has(fulfillment_type)) {
    errors.push("fulfillment_type must be either 'delivery' or 'pickup'");
  }

  if (fulfillment_type === "delivery") {
    if (!delivery_address) {
      errors.push("delivery_address is required for delivery orders");
    }
  }

  if (errors.length > 0) {
    return { valid: false, errors };
  }

  return {
    valid: true,
    errors: [],
    sanitized: {
      store_id,
      fulfillment_type,
      delivery_address: fulfillment_type === "delivery" ? delivery_address : undefined,
    },
  };
}

export function validateUpdateOrderStatus(data: unknown): {
  valid: boolean;
  errors: string[];
  sanitized?: UpdateOrderStatusInput;
} {
  const errors: string[] = [];
  if (!data || typeof data !== "object") {
    return { valid: false, errors: ["Invalid payload format"] };
  }

  const payload = data as Record<string, unknown>;
  const status = typeof payload.status === "string" ? (payload.status.trim() as OrderStatus) : ("" as OrderStatus);

  if (!VALID_ORDER_STATUSES.has(status)) {
    errors.push("Invalid order status value");
  }

  if (errors.length > 0) {
    return { valid: false, errors };
  }

  return {
    valid: true,
    errors: [],
    sanitized: { status },
  };
}
