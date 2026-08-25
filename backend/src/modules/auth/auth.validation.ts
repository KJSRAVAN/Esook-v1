export interface CustomerSignupInput {
  phone_number: string;
  full_name: string;
  password: string;
  address?: string | undefined;
}

export interface LoginInput {
  phone_number: string;
  password: string;
}

export interface RequestMagicLinkInput {
  email: string;
}

export interface VerifyMagicLinkInput {
  token: string;
}

export function validateCustomerSignup(data: unknown): {
  valid: boolean;
  errors: string[];
  sanitized?: CustomerSignupInput;
} {
  const errors: string[] = [];
  if (!data || typeof data !== "object") {
    return { valid: false, errors: ["Invalid payload format"] };
  }

  const payload = data as Record<string, unknown>;

  const phone_number = typeof payload.phone_number === "string" ? payload.phone_number.trim() : "";
  const full_name = typeof payload.full_name === "string" ? payload.full_name.trim() : "";
  const password = typeof payload.password === "string" ? payload.password : "";
  const address = typeof payload.address === "string" ? payload.address.trim() : undefined;

  if (!phone_number) {
    errors.push("phone_number is required");
  }
  if (!full_name) {
    errors.push("full_name is required");
  }
  if (!password) {
    errors.push("password is required");
  } else if (password.length < 8) {
    errors.push("password must be at least 8 characters");
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
      password,
      address,
    },
  };
}

export function validateLogin(data: unknown): {
  valid: boolean;
  errors: string[];
  sanitized?: LoginInput;
} {
  const errors: string[] = [];
  if (!data || typeof data !== "object") {
    return { valid: false, errors: ["Invalid payload format"] };
  }

  const payload = data as Record<string, unknown>;
  const phone_number = typeof payload.phone_number === "string" ? payload.phone_number.trim() : "";
  const password = typeof payload.password === "string" ? payload.password : "";

  if (!phone_number) {
    errors.push("phone_number is required");
  }
  if (!password) {
    errors.push("password is required");
  }

  if (errors.length > 0) {
    return { valid: false, errors };
  }

  return {
    valid: true,
    errors: [],
    sanitized: {
      phone_number,
      password,
    },
  };
}

export function validateRequestMagicLink(data: unknown): {
  valid: boolean;
  errors: string[];
  sanitized?: RequestMagicLinkInput;
} {
  const errors: string[] = [];
  if (!data || typeof data !== "object") {
    return { valid: false, errors: ["Invalid payload format"] };
  }

  const payload = data as Record<string, unknown>;
  const email = typeof payload.email === "string" ? payload.email.trim().toLowerCase() : "";

  if (!email || !email.includes("@")) {
    errors.push("Valid email is required");
  }

  if (errors.length > 0) {
    return { valid: false, errors };
  }

  return {
    valid: true,
    errors: [],
    sanitized: { email },
  };
}

export function validateVerifyMagicLink(data: unknown): {
  valid: boolean;
  errors: string[];
  sanitized?: VerifyMagicLinkInput;
} {
  const errors: string[] = [];
  if (!data || typeof data !== "object") {
    return { valid: false, errors: ["Invalid payload format"] };
  }

  const payload = data as Record<string, unknown>;
  const token = typeof payload.token === "string" ? payload.token.trim() : "";

  if (!token) {
    errors.push("Magic link token is required");
  }

  if (errors.length > 0) {
    return { valid: false, errors };
  }

  return {
    valid: true,
    errors: [],
    sanitized: { token },
  };
}
