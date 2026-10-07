import express from "express";

import {
  getStudentPolls,
  getPollById,
  voteOnPoll,
  getPollResults,
  createPoll,
  deletePoll,
  declareDecision,
} from "../controllers/poll.controller.js";

// IMPORTANT:
// Your existing project uses authMiddleware.js
import { protect } from "../middleware/authMiddleware.js";

const router = express.Router();

/*
|--------------------------------------------------------------------------
| STUDENT / AUTHENTICATED USERS
|--------------------------------------------------------------------------
*/

// Get all polls
router.get("/", protect, getStudentPolls);

// Get one poll
router.get("/:pollId", protect, getPollById);

// Vote
router.post("/:pollId/vote", protect, voteOnPoll);

// Get results
router.get("/:pollId/results", protect, getPollResults);

/*
|--------------------------------------------------------------------------
| ADMIN
|--------------------------------------------------------------------------
|
| The existing protect middleware handles authentication.
| The controller additionally receives the authenticated user.
|
*/

router.post(
  "/admin/create",
  protect,
  createPoll
);

router.delete(
  "/admin/:pollId",
  protect,
  deletePoll
);

router.post(
  "/admin/:pollId/decision",
  protect,
  declareDecision
);

export default router;