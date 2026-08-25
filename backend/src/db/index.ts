import pg from "pg";
import { env } from "../config/env.js";

const { Pool } = pg;

// Reusable PostgreSQL connection pool
export const pool = new Pool({
  connectionString: env.DATABASE_URL,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

pool.on("error", (err: Error) => {
  console.error("Unexpected error on idle PostgreSQL client:", err.message);
});

/**
 * Execute parameterized SQL queries safely.
 * Never concatenate user input directly into SQL strings.
 */
export async function query<T extends pg.QueryResultRow = pg.QueryResultRow>(
  text: string,
  params?: unknown[]
): Promise<pg.QueryResult<T>> {
  return pool.query<T>(text, params);
}

export interface DbHealthResult {
  connected: boolean;
  timestamp: string;
  error?: string;
}

/**
 * Database connectivity check using SELECT 1.
 * Safe for public health endpoints: never leaks credentials or internal connection details.
 */
export async function checkDatabaseConnection(): Promise<DbHealthResult> {
  const timestamp = new Date().toISOString();
  try {
    await pool.query("SELECT 1;");
    return {
      connected: true,
      timestamp,
    };
  } catch (err: unknown) {
    const errorMessage =
      err instanceof Error ? err.message : "Database connection failed";
    console.error("Database health check error:", errorMessage);
    return {
      connected: false,
      timestamp,
      error: "Database connection failed",
    };
  }
}
