import { Router } from "express";
import { protect } from "../middleware/authMiddleware.js";
import { voteMeal, cancelVote, checkVoteStatus, getVotesByDateAndSlot, checkUserVotesForWeek,  getVoteHistory } from "../controllers/vote.controller.js";
import { toggleServeStatus } from "../controllers/serveMeal/toggleServeController.js";

const router = Router();
router.post("/post", protect, voteMeal);
router.delete("/cancel", protect, cancelVote);
router.patch("/status/:mealId", protect, checkVoteStatus);
router.get("/history", protect, getVoteHistory);



// manager access
router.get("/get-votes", protect, getVotesByDateAndSlot);
router.post("/check-status", protect, checkUserVotesForWeek);
router.post("/serve", protect, toggleServeStatus);

export default router;
