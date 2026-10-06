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

import { protect } from "../middleware/auth.middleware.js";

const router = express.Router();

/*
|--------------------------------------------------------------------------
| STUDENT
|--------------------------------------------------------------------------
*/

router.get("/", protect, getStudentPolls);

router.get("/:pollId", protect, getPollById);

router.post("/:pollId/vote", protect, voteOnPoll);

router.get("/:pollId/results", protect, getPollResults);

/*
|--------------------------------------------------------------------------
| ADMIN
|--------------------------------------------------------------------------
*/

router.post("/admin/create", protect, createPoll);

router.delete("/admin/:pollId", protect, deletePoll);

router.post(
  "/admin/:pollId/decision",
  protect,
  declareDecision
);

export default router;