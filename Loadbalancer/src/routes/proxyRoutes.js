import express from "express";
import { proxyRequest } from "../controllers/proxyController.js";
import { chooseServer } from "../middleware/loadBalancer.js"; // Path adjusted to your structure

const router = express.Router();

// First validate/choose via middleware, then execute proxy logic
router.use(chooseServer, proxyRequest);

export default router;