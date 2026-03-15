import express from "express";
import {
    requestGuestMeal,
    getHostelGuestRequests,
    updateRequestStatus,
    getMyGuestMealRequests,
    cancelGuestMealRequest
} from "../controllers/guestMeal.controller.js";
import { protect } from "../middleware/authMiddleware.js";
import { isApproved } from "../middleware/statusMiddleware.js";

const router = express.Router();

// Student Routes
router.post("/request", protect, isApproved, requestGuestMeal);
router.put("/cancel/:id", protect, isApproved, cancelGuestMealRequest);
router.get("/my-requests", protect, isApproved, getMyGuestMealRequests);

// Manager Routes
router.get("/all", protect, isApproved, getHostelGuestRequests);
router.put("/status/:id", protect, isApproved, updateRequestStatus);

export default router;