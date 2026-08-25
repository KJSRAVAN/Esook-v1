import { Router } from "express";
import { UsersController } from "./users.controller.js";
import { authenticate, requireRole } from "../../middleware/auth.middleware.js";

const usersRouter = Router();

// Protect all user management endpoints (Super Admin only)
usersRouter.use(authenticate, requireRole("super_admin"));

usersRouter.post("/", UsersController.createUser);
usersRouter.get("/", UsersController.listUsers);
usersRouter.get("/:id", UsersController.getUserById);
usersRouter.patch("/:id", UsersController.updateUser);

export default usersRouter;
