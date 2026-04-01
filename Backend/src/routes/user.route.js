// src/routes/user.routes.js
import express from "express";
import { updateProfilePicture, getStudentPaymentHistory  } from "../controllers/user.controller.js";
import { protect } from "../middleware/authMiddleware.js";
import { handleImageUpload } from "../middleware/uploadMiddleware.js";

const router = express.Router();

// Flow: 1. Check Auth -> 2. Process Image -> 3. Update DB
router.put("/update-profile-pic", protect, handleImageUpload, updateProfilePicture);
router.get("/all-payment-history", protect, getStudentPaymentHistory );


export default router;