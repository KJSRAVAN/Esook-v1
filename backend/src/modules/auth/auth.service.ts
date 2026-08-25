import bcrypt from "bcryptjs";
import crypto from "node:crypto";
import { query } from "../../db/index.js";
import { signAccessToken, type UserRole } from "../../utils/jwt.js";
import { env } from "../../config/env.js";
import type {
  CustomerSignupInput,
  LoginInput,
  RequestMagicLinkInput,
  VerifyMagicLinkInput,
} from "./auth.validation.js";

const BCRYPT_SALT_ROUNDS = 12;
const MAGIC_LINK_EXPIRY_MINUTES = 15;

export interface UserResponse {
  id: string;
  phone_number: string;
  email?: string | null;
  full_name: string;
  role: UserRole;
  store_id?: string | null;
  address?: string | null;
  is_active: boolean;
  created_at?: Date;
}

export interface AuthSuccessResult {
  user: UserResponse;
  token: string;
}

export class AuthService {
  /**
   * Customer self-signup.
   * Role is strictly forced to 'customer' server-side.
   */
  static async signupCustomer(
    input: CustomerSignupInput
  ): Promise<AuthSuccessResult> {
    const existing = await query<{ id: string }>(
      "SELECT id FROM users WHERE phone_number = $1",
      [input.phone_number]
    );

    if (existing.rows.length > 0) {
      const err = new Error("An account with this phone number already exists");
      (err as unknown as { status: number }).status = 409;
      throw err;
    }

    const password_hash = await bcrypt.hash(input.password, BCRYPT_SALT_ROUNDS);

    const result = await query<UserResponse>(
      `INSERT INTO users (phone_number, password_hash, full_name, role, address)
       VALUES ($1, $2, $3, 'customer', $4)
       RETURNING id, phone_number, full_name, role, address, is_active, created_at`,
      [input.phone_number, password_hash, input.full_name, input.address || null]
    );

    const user = result.rows[0]!;
    const token = signAccessToken({
      id: user.id,
      role: user.role,
      store_id: null,
    });

    return { user, token };
  }

  /**
   * Shared password login for Customer, Store Staff, Store Manager, Delivery Rider.
   * Uses generic error messages for nonexistent, wrong password, passwordless, or inactive accounts
   * to prevent phone number enumeration attacks.
   */
  static async login(input: LoginInput): Promise<AuthSuccessResult> {
    const result = await query<{
      id: string;
      phone_number: string;
      email: string | null;
      full_name: string;
      role: UserRole;
      store_id: string | null;
      password_hash: string | null;
      is_active: boolean;
    }>(
      `SELECT id, phone_number, email, full_name, role, store_id, password_hash, is_active
       FROM users WHERE phone_number = $1`,
      [input.phone_number]
    );

    const userRow = result.rows[0];

    // Generic 401 error for nonexistent, passwordless, or inactive accounts to prevent enumeration
    if (!userRow || !userRow.password_hash || !userRow.is_active) {
      const err = new Error("Invalid phone number or password");
      (err as unknown as { status: number }).status = 401;
      throw err;
    }

    const match = await bcrypt.compare(input.password, userRow.password_hash);
    if (!match) {
      const err = new Error("Invalid phone number or password");
      (err as unknown as { status: number }).status = 401;
      throw err;
    }

    const user: UserResponse = {
      id: userRow.id,
      phone_number: userRow.phone_number,
      email: userRow.email,
      full_name: userRow.full_name,
      role: userRow.role,
      store_id: userRow.store_id,
      is_active: userRow.is_active,
    };

    const token = signAccessToken({
      id: user.id,
      role: user.role,
      store_id: user.store_id,
    });

    return { user, token };
  }

  /**
   * Super Admin Magic Link Request (Step 1).
   * Generates single-use random token, stores SHA-256 hash in DB with 15m expiry.
   */
  static async requestMagicLink(
    input: RequestMagicLinkInput
  ): Promise<{ message: string }> {
    const result = await query<{ id: string }>(
      `SELECT id FROM users WHERE email = $1 AND role = 'super_admin' AND is_active = TRUE`,
      [input.email]
    );

    const user = result.rows[0];

    // Always return identical message regardless of email registration status to prevent enumeration
    if (user) {
      const rawToken = crypto.randomBytes(32).toString("hex");
      const tokenHash = crypto
        .createHash("sha256")
        .update(rawToken)
        .digest("hex");
      const expiresAt = new Date(
        Date.now() + MAGIC_LINK_EXPIRY_MINUTES * 60 * 1000
      );

      await query(
        `INSERT INTO magic_link_tokens (user_id, token_hash, expires_at)
         VALUES ($1, $2, $3)`,
        [user.id, tokenHash, expiresAt]
      );

      const magicLink = `${env.APP_URL}/admin/verify?token=${rawToken}`;

      // Console log for local dev. Production integration point for SES/SendGrid.
      console.log(
        `[DEV MAGIC LINK] Email: ${input.email} | Verification Link: ${magicLink}`
      );
    }

    return {
      message:
        "If that email is registered as an admin, a login link has been sent.",
    };
  }

  /**
   * Super Admin Magic Link Verification (Step 2).
   * Atomically claims and burns single-use token in a single PostgreSQL UPDATE query.
   * Race-safe: guaranteed that only one concurrent request can successfully claim a token.
   */
  static async verifyMagicLink(
    input: VerifyMagicLinkInput
  ): Promise<AuthSuccessResult> {
    const tokenHash = crypto
      .createHash("sha256")
      .update(input.token)
      .digest("hex");

    // Database-atomic redemption operation
    const updateResult = await query<{ user_id: string }>(
      `UPDATE magic_link_tokens
       SET used_at = CURRENT_TIMESTAMP
       WHERE token_hash = $1
         AND used_at IS NULL
         AND expires_at > CURRENT_TIMESTAMP
       RETURNING user_id`,
      [tokenHash]
    );

    const redeemedRow = updateResult.rows[0];
    if (!redeemedRow) {
      const err = new Error("This magic link is invalid or has expired");
      (err as unknown as { status: number }).status = 401;
      throw err;
    }

    const userResult = await query<{
      id: string;
      phone_number: string;
      email: string;
      full_name: string;
      role: UserRole;
      store_id: string | null;
      is_active: boolean;
    }>(
      `SELECT id, phone_number, email, full_name, role, store_id, is_active
       FROM users WHERE id = $1`,
      [redeemedRow.user_id]
    );

    const userRow = userResult.rows[0];

    if (!userRow || !userRow.is_active) {
      const err = new Error("Account is disabled. Please contact support.");
      (err as unknown as { status: number }).status = 403;
      throw err;
    }

    const user: UserResponse = {
      id: userRow.id,
      phone_number: userRow.phone_number,
      email: userRow.email,
      full_name: userRow.full_name,
      role: userRow.role,
      store_id: userRow.store_id,
      is_active: userRow.is_active,
    };

    const jwtToken = signAccessToken({
      id: user.id,
      role: user.role,
      store_id: user.store_id,
    });

    return { user, token: jwtToken };
  }

  /**
   * Fetch authenticated user profile.
   */
  static async getCurrentUser(userId: string): Promise<UserResponse> {
    const result = await query<UserResponse>(
      `SELECT id, phone_number, email, full_name, role, store_id, address, is_active, created_at
       FROM users WHERE id = $1`,
      [userId]
    );

    const user = result.rows[0];
    if (!user || !user.is_active) {
      const err = new Error("User not found or account disabled");
      (err as unknown as { status: number }).status = 404;
      throw err;
    }

    return user;
  }
}
