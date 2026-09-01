import express from "express";
import cors from "cors";
import router from "./router.js";
import { errorHandler } from "./middleware/error.middleware.js";

const app = express();

app.use(cors({ credentials: true, origin: true }));
app.use(express.json());

app.use("/api", router);

app.use(errorHandler);

export default app;
