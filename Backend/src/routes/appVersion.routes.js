import express from "express";
import { getAppVersion } from "../controllers/appVersion.controller.js";

const router = express.Router();

// PUBLIC endpoint.
// Do NOT add protect middleware here.
// Old versions must be able to access this endpoint.
router.get("/", getAppVersion);

export default router;