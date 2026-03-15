import express from "express";
import {
    requestGuestMeal,
    getHostelGuestRequests,
    updateRequestStatus,
    getMyGuestMealRequests,
    cancelGuestMealRequest
} from "../controllers/guestMeal.controller.js";
import { protect } from "../middleware/authMiddleware.js";

const router = express.Router();

// Student Routes
router.post("/request", protect, requestGuestMeal);
router.put("/cancel/:id", protect, cancelGuestMealRequest);
router.get("/my-requests", protect, getMyGuestMealRequests);

// Manager Routes
router.get("/all", protect, getHostelGuestRequests);
router.put("/status/:id", protect, updateRequestStatus);

export default router;