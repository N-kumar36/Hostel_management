import express from "express";
import {
    createFine,
    getMyFines,
    payFine,
    updateFineStatus,
    getPendingFines,
    updateFineStatusDelete,
    convertFineToSubscription,
    convertMealPackToGuestMeal
} from "../controllers/fine.controller.js";
import { protect } from "../middleware/authMiddleware.js";
import { handleImageUpload } from "../middleware/uploadMiddleware.js";

const router = express.Router();

// manager
router.post("/create", protect, createFine);

router.put("/:id/status", protect, updateFineStatus);
router.get("/pending", protect, getPendingFines);
router.delete("/:id", protect, updateFineStatusDelete);

router.post("/:id/convert-to-subscription", protect, convertFineToSubscription);
router.post("/:id/convert-to-guest", protect, convertMealPackToGuestMeal);

// user
router.get("/my-fines", protect, getMyFines);
router.put("/pay/:id", protect, handleImageUpload, payFine);

export default router;