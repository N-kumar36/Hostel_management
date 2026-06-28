import { Router } from "express";
import { protect } from "../middleware/authMiddleware.js";
import {
    assignManager,
    getCurrentManager,
    getAllStudent,
    pendingStudent,
    pendingApprove,
    pendingReject,
    getAllHostelStudent,
    getStudentSummary,
    saveSattingData,
    getSattingData,
    getDashboardCounts
} from "../controllers/manager.controller.js";
import { upsertWeeklyRoutine, getWeeklyRoutine } from "../controllers/WeeklyRoutine.controller.js";

const router = Router();

// For testing purposes, we'll just use protect. 
// In a real app, only a "Super Admin" should be able to assign managers.
router.post("/assign", protect, assignManager);
router.get("/current", protect, getCurrentManager);

// manager manage
router.get("/getallStudent", protect, getAllStudent)
router.get("/pending", protect, pendingStudent);
router.get("/dashboard-counts", protect, getDashboardCounts);
router.get("/pending", protect, pendingStudent);
router.patch("/approve/:id", protect, pendingApprove);
router.patch("/reject/:id", protect, pendingReject);
router.get("/get-student", protect, getAllHostelStudent);
router.post("/create-routine", protect, upsertWeeklyRoutine);
router.get("/get-routine", protect, getWeeklyRoutine);
router.get("/Status/:studentId", protect, getStudentSummary);



router.route("/sattingData")
    .get(protect, getSattingData)
    .post(protect, saveSattingData);


export default router;