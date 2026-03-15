import { Router } from "express";
import { protect } from "../middleware/authMiddleware.js";
import { checkPermission } from "../middleware/isManager.js"; // Updated import
import { 
  createMeal, 
  updateMeal, 
  cancelMeal, 
  getAllMeals,
  getTodayMeals, 
  getWeeklyMeals,
  getMealStatus
} from "../controllers/meal.controller.js";

const router = Router();

// --- Student Access (Any logged-in user) ---
router.get("/today", protect, getTodayMeals);
router.get("/week", protect, getWeeklyMeals);
router.patch("/Status/:studentId", protect, getMealStatus);

// --- Manager Access (Requires specific 'mealEdit' permission) ---
// We use checkPermission("mealEdit") to verify the specific right
router.get("/all", protect, checkPermission("mealEdit"), getAllMeals);
router.post("/create", protect, checkPermission("mealEdit"), createMeal);
router.put("/update/:mealId", protect, checkPermission("mealEdit"), updateMeal);
router.delete("/:id", protect, checkPermission("mealEdit"), cancelMeal);

export default router;