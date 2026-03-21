import { Router } from "express";
import { protect } from "../middleware/authMiddleware.js";
import { getHostelUpi } from "../controllers/upi.controller.js";

const router = Router();


router.get("/get", protect, getHostelUpi );


export default router;
