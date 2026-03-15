import { Router } from "express";
import { protect } from "../middleware/authMiddleware.js";
import { saveUpiDetails, getHostelUpi } from "../controllers/upi.controller.js";

const router = Router();

router.post("/save", protect, saveUpiDetails);
router.get("/get", protect, getHostelUpi );


export default router;
