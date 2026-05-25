import { Router } from "express";
import { protect } from "../middleware/authMiddleware.js";
import { checkPermission } from "../middleware/isManager.js"; // Updated import
import { isApproved } from "../middleware/statusMiddleware.js";
import { getMealPlans } from "../controllers/mealPlan.controller.js";
import { selectPackage, getAllSubscriptions, getManagerSubscriptions, updateSubscriptionByManager, deleteSubscriptionByManager } from "../controllers/StudentSubscription.controller.js";


const router = Router();

router.get("/get", protect, getMealPlans);
router.post("/select", protect, selectPackage);


router.get("/getAllSubscriptions", protect, getAllSubscriptions);



router.get("/manager/getAllSubscriptions", protect,  getManagerSubscriptions); // Updated route with permission check
router.put("/manager/updateSubscription/:id", protect, updateSubscriptionByManager); // Manager can update subscription status
router.delete("/manager/deleteSubscription/:id", protect, deleteSubscriptionByManager); // Manager can delete a subscription



export default router;