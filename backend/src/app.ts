import express, { type Request, type Response } from "express";
import { checkDatabaseConnection } from "./db/index.js";
import authRouter from "./modules/auth/auth.routes.js";
import storesRouter from "./modules/stores/stores.routes.js";
import productsRouter from "./modules/products/products.routes.js";
import cartRouter from "./modules/cart/cart.routes.js";
import ordersRouter from "./modules/orders/orders.routes.js";
import loyaltyRouter from "./modules/loyalty/loyalty.routes.js";
import usersRouter from "./modules/users/users.routes.js";

const app = express();

app.use(express.json());

// Mount API modules
app.use("/api/auth", authRouter);
app.use("/api/stores", storesRouter);
app.use("/api/products", productsRouter);
app.use("/api/cart", cartRouter);
app.use("/api/orders", ordersRouter);
app.use("/api/loyalty", loyaltyRouter);
app.use("/api/users", usersRouter);

// Basic health check endpoint
app.get("/health", (_req: Request, res: Response) => {
  res.json({
    status: "ok",
  });
});

// Database health check endpoint
app.get("/health/db", async (_req: Request, res: Response) => {
  const dbHealth = await checkDatabaseConnection();

  if (dbHealth.connected) {
    res.status(200).json({
      status: "ok",
      database: "connected",
      timestamp: dbHealth.timestamp,
    });
  } else {
    res.status(503).json({
      status: "error",
      database: "disconnected",
      timestamp: dbHealth.timestamp,
    });
  }
});

// Catch-all 404 handler
app.use((_req: Request, res: Response) => {
  res.status(404).json({ error: "Route not found" });
});

// Global error handler — prevents leaking stack traces or internal DB details to clients
app.use((err: unknown, _req: Request, res: Response, _next: express.NextFunction) => {
  const status =
    (err as { status?: number; statusCode?: number }).status ||
    (err as { statusCode?: number }).statusCode;

  if (status && status >= 400 && status < 500) {
    const message = err instanceof Error ? err.message : "Bad request";
    return res.status(status).json({ error: message });
  }

  console.error("Unhandled Internal Application Error:", err);
  return res.status(500).json({ error: "Internal server error" });
});

export default app;