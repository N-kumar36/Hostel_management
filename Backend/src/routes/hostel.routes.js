import { Router } from "express";
import { getHostels, createHostel } from "../controllers/hostel.controller.js";
import { protect } from "../middleware/authMiddleware.js";


const router = Router();

// get Hosltels - to fetch all hostels for dropdown
router.get("/get", getHostels);

// createHostel - to create a new hostel
router.post("/create", createHostel);

export default router;
