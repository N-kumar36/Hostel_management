import express from "express";
import { createComplain, getHostelComplains } from "../controllers/complain.controller.js";
import { protect } from "../middleware/authMiddleware.js";
import { handleImageUpload } from "../middleware/uploadMiddleware.js";
import { isApproved } from "../middleware/statusMiddleware.js";

const router = express.Router();

// POST /api/complains/create
router.post("/create", protect, isApproved , handleImageUpload, createComplain);

// GET /api/complains/all
router.get("/all", protect, isApproved,  getHostelComplains);

export default router;