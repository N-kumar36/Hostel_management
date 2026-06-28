import { Router } from "express";
import { protect } from "../middleware/authMiddleware.js";
import { checkPermission } from "../middleware/isManager.js"; // Updated import
import { isApproved } from "../middleware/statusMiddleware.js";
import { 
  createMeal, 
  updateMeal, 
 
  getAllMeals,
  getTodayMeals, 
  getWeeklyMeals,
  getMealStatus,
  autoGenerateMeals
} from "../controllers/meal.controller.js";

const router = Router();

// --- Student Access (Any logged-in user) ---
router.get("/today", protect, isApproved, getTodayMeals);
router.get("/week", protect, isApproved, getWeeklyMeals);
router.patch("/Status/:studentId", protect, isApproved, getMealStatus);

// --- Manager Access (Requires specific 'mealEdit' permission) ---
// We use checkPermission("mealEdit") to verify the specific right
router.get("/all", protect, getAllMeals);
router.post("/create", protect, checkPermission("mealEdit"), createMeal);
router.post("/auto-generate", protect, checkPermission("mealEdit"), autoGenerateMeals); // This route can be protected by a different permission if needed
router.put("/update/:mealId", protect, checkPermission("mealEdit"), updateMeal);


export default router;