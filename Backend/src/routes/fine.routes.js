import express from "express";
import { createFine, getMyFines, payFine, generateBulkFines, verifyFinePayment, getPendingFines } from "../controllers/fine.controller.js";
import { protect } from "../middleware/authMiddleware.js";
import { handleImageUpload } from "../middleware/uploadMiddleware.js";

const router = express.Router();

// manager
router.post("/create", protect, createFine);
router.post("/generate-bulk", protect, generateBulkFines);
router.put("/verify/:id", protect, verifyFinePayment);
router.get("/pending", protect, getPendingFines);


// user
router.get("/my-fines", protect, getMyFines);
router.put("/pay/:id", protect, handleImageUpload, payFine);

export default router;