// src/routes/user.routes.js
import express from "express";
import { updateProfilePicture, getStudentPaymentHistory, updateProfile, deleteProfile, getProfile  } from "../controllers/user.controller.js";
import { protect } from "../middleware/authMiddleware.js";
import { checkPermission } from "../middleware/isManager.js";
import { handleImageUpload } from "../middleware/uploadMiddleware.js";

const router = express.Router();

// Flow: 1. Check Auth -> 2. Process Image -> 3. Update DB
router.put("/update-profile-pic", protect, handleImageUpload, updateProfilePicture);
router.get("/all-payment-history", protect, getStudentPaymentHistory );

// admin APIs Router
router.get("/:id", protect, getProfile)
router.put("/profile/:id", protect, updateProfile);
router.delete("/profile/:id", protect, deleteProfile);


export default router;