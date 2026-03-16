import { Router } from "express";
import { protect } from "../middleware/authMiddleware.js";
import { assignManager, getCurrentManager, pendingStudent, pendingApprove, pendingReject, getAllHostelStudent, getStudentSummary } from "../controllers/manager.controller.js";
import { upsertWeeklyRoutine, getWeeklyRoutine } from "../controllers/WeeklyRoutine.controller.js";
const router = Router();

// For testing purposes, we'll just use protect. 
// In a real app, only a "Super Admin" should be able to assign managers.
router.post("/assign", protect, assignManager);
router.get("/current", protect, getCurrentManager);

// manager manage

router.get("/pending", protect, pendingStudent);
router.patch("/approve/:id", protect, pendingApprove);
router.patch("/reject/:id", protect, pendingReject);
router.get("/get-student", protect, getAllHostelStudent);
router.post("/create-routine", protect, upsertWeeklyRoutine);
router.get("/get-routine", protect, getWeeklyRoutine);
router.get("/Status/:studentId", protect, getStudentSummary );

export default router;