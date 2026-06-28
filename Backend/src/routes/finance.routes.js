import router from "express";
import { protect } from "../middleware/authMiddleware.js";
import { isApproved } from "../middleware/statusMiddleware.js";

import { getFinanceData, getFinanceAuditReport } from "../controllers/finance.controller.js";




const financeRoutes = router.Router();


financeRoutes.get("/meal-cycle-bounds", protect, isApproved, getFinanceData);
financeRoutes.get("/audit-statement", protect, isApproved, getFinanceAuditReport);





export default financeRoutes;