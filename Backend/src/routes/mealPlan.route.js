import { Router } from "express";
import { protect } from "../middleware/authMiddleware.js";
import { checkPermission } from "../middleware/isManager.js"; // Updated import
import { isApproved } from "../middleware/statusMiddleware.js";
import { getMealPlans } from "../controllers/mealPlan.controller.js";
import { selectPackage, getAllSubscriptions } from "../controllers/StudentSubscription.controller.js";


const router = Router();

router.get("/get", protect, getMealPlans);

router.post("/select", protect, selectPackage);

router.get("/getAllSubscriptions", protect, getAllSubscriptions);

export default router;