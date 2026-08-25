import dotenv from "dotenv";
import path from "node:path";
import fs from "node:fs";

// Safely locate and load .env file from current working dir or workspace root
const cwdEnv = path.resolve(process.cwd(), ".env");
const parentEnv = path.resolve(process.cwd(), "..", ".env");

if (fs.existsSync(cwdEnv)) {
  dotenv.config({ path: cwdEnv });
} else if (fs.existsSync(parentEnv)) {
  dotenv.config({ path: parentEnv });
} else {
  dotenv.config();
}

export interface EnvConfig {
  NODE_ENV: string;
  PORT: number;
  DATABASE_URL: string;
  JWT_SECRET: string;
  APP_URL: string;
}

export function validateEnv(): EnvConfig {
  const missingVars: string[] = [];

  if (!process.env.DATABASE_URL) {
    missingVars.push("DATABASE_URL");
  }

  if (!process.env.JWT_SECRET) {
    missingVars.push("JWT_SECRET");
  }

  if (missingVars.length > 0) {
    console.error(
      `[FATAL] Startup failed due to missing required environment variable(s): ${missingVars.join(", ")}`
    );
    throw new Error(
      `Missing required environment variable(s): ${missingVars.join(", ")}`
    );
  }

  return {
    NODE_ENV: process.env.NODE_ENV || "development",
    PORT: Number(process.env.PORT) || 4000,
    DATABASE_URL: process.env.DATABASE_URL!,
    JWT_SECRET: process.env.JWT_SECRET!,
    APP_URL: process.env.APP_URL || "http://localhost:4000",
  };
}

export const env = validateEnv();
