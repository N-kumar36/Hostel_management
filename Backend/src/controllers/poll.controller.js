import mongoose from "mongoose";
import Poll from "../models/poll.model.js";
import PollVote from "../models/pollVote.model.js";

const updatePollStatus = (poll) => {
  const now = new Date();

  if (now < poll.startAt) {
    poll.status = "scheduled";
  } else if (now >= poll.startAt && now < poll.endAt) {
    poll.status = "active";
  } else {
    poll.status = "closed";
  }

  return poll;
};

const getUserId = (req) => {
  return (
    req.user?._id ||
    req.user?.id ||
    req.user?.userId ||
    req.userId ||
    null
  );
};

/*
|--------------------------------------------------------------------------
| STUDENT
|--------------------------------------------------------------------------
*/

export const getStudentPolls = async (req, res) => {
  try {
    const polls = await Poll.find({
      status: { $in: ["scheduled", "active", "closed"] },
    })
      .populate("createdBy", "name email")
      .sort({ startAt: -1 })
      .lean();

    const studentId = getUserId(req);

    let votedPollIds = new Set();

    if (studentId) {
      const votes = await PollVote.find({
        studentId,
        pollId: { $in: polls.map((p) => p._id) },
      })
        .select("pollId optionId")
        .lean();

      votedPollIds = new Set(
        votes.map((vote) => vote.pollId.toString())
      );
    }

    const result = polls.map((poll) => {
      const normalized = updatePollStatus(poll);

      return {
        ...normalized,
        hasVoted: votedPollIds.has(poll._id.toString()),
      };
    });

    return res.status(200).json({
      success: true,
      data: result,
    });
  } catch (error) {
    console.error("Get Student Polls Error:", error);

    return res.status(500).json({
      success: false,
      message: "Unable to load polls.",
    });
  }
};

export const getPollById = async (req, res) => {
  try {
    const { pollId } = req.params;

    if (!mongoose.Types.ObjectId.isValid(pollId)) {
      return res.status(400).json({
        success: false,
        message: "Invalid poll ID.",
      });
    }

    const poll = await Poll.findById(pollId)
      .populate("createdBy", "name email")
      .lean();

    if (!poll) {
      return res.status(404).json({
        success: false,
        message: "Poll not found.",
      });
    }

    const normalized = updatePollStatus(poll);

    const studentId = getUserId(req);

    let vote = null;

    if (studentId) {
      vote = await PollVote.findOne({
        pollId,
        studentId,
      })
        .select("optionId votedAt")
        .lean();
    }

    return res.status(200).json({
      success: true,
      data: {
        ...normalized,
        hasVoted: !!vote,
        votedOptionId: vote?.optionId || null,
        votedAt: vote?.votedAt || null,
      },
    });
  } catch (error) {
    console.error("Get Poll Error:", error);

    return res.status(500).json({
      success: false,
      message: "Unable to load poll.",
    });
  }
};

export const voteOnPoll = async (req, res) => {
  try {
    const { pollId } = req.params;
    const { optionId } = req.body;

    const studentId = getUserId(req);

    if (!studentId) {
      return res.status(401).json({
        success: false,
        message: "Student authentication required.",
      });
    }

    if (!mongoose.Types.ObjectId.isValid(pollId)) {
      return res.status(400).json({
        success: false,
        message: "Invalid poll ID.",
      });
    }

    if (!optionId) {
      return res.status(400).json({
        success: false,
        message: "Please select an option.",
      });
    }

    const poll = await Poll.findById(pollId);

    if (!poll) {
      return res.status(404).json({
        success: false,
        message: "Poll not found.",
      });
    }

    const now = new Date();

    if (now < poll.startAt) {
      return res.status(400).json({
        success: false,
        message: "Voting has not started yet.",
      });
    }

    if (now >= poll.endAt) {
      poll.status = "closed";
      await poll.save();

      return res.status(400).json({
        success: false,
        message: "Voting has ended.",
      });
    }

    const optionExists = poll.options.some(
      (option) => option._id.toString() === optionId.toString()
    );

    if (!optionExists) {
      return res.status(400).json({
        success: false,
        message: "Invalid voting option.",
      });
    }

    try {
      const vote = await PollVote.create({
        pollId,
        studentId,
        optionId,
      });

      poll.status = "active";
      await poll.save();

      return res.status(201).json({
        success: true,
        message: "Vote submitted successfully.",
        data: vote,
      });
    } catch (error) {
      if (error?.code === 11000) {
        return res.status(409).json({
          success: false,
          message: "You have already voted in this poll.",
        });
      }

      throw error;
    }
  } catch (error) {
    console.error("Vote Poll Error:", error);

    return res.status(500).json({
      success: false,
      message: "Unable to submit vote.",
    });
  }
};

/*
|--------------------------------------------------------------------------
| RESULTS
|--------------------------------------------------------------------------
*/

export const getPollResults = async (req, res) => {
  try {
    const { pollId } = req.params;

    if (!mongoose.Types.ObjectId.isValid(pollId)) {
      return res.status(400).json({
        success: false,
        message: "Invalid poll ID.",
      });
    }

    const poll = await Poll.findById(pollId).lean();

    if (!poll) {
      return res.status(404).json({
        success: false,
        message: "Poll not found.",
      });
    }

    const now = new Date();
    const isClosed = now >= poll.endAt;

    if (!isClosed && poll.showResultsAfterClose) {
      return res.status(403).json({
        success: false,
        message: "Results will be available after voting closes.",
      });
    }

    const results = await PollVote.aggregate([
      {
        $match: {
          pollId: new mongoose.Types.ObjectId(pollId),
        },
      },
      {
        $group: {
          _id: "$optionId",
          votes: { $sum: 1 },
        },
      },
    ]);

    const totalVotes = results.reduce(
      (sum, item) => sum + item.votes,
      0
    );

    const formattedResults = poll.options.map((option) => {
      const result = results.find(
        (item) => item._id.toString() === option._id.toString()
      );

      const votes = result?.votes || 0;

      return {
        optionId: option._id,
        text: option.text,
        votes,
        percentage:
          totalVotes > 0
            ? Number(((votes / totalVotes) * 100).toFixed(2))
            : 0,
      };
    });

    const highestVotes = Math.max(
      0,
      ...formattedResults.map((item) => item.votes)
    );

    const winners = formattedResults.filter(
      (item) => item.votes === highestVotes && highestVotes > 0
    );

    return res.status(200).json({
      success: true,
      data: {
        pollId: poll._id,
        title: poll.title,
        totalVotes,
        results: formattedResults,
        winners,
        decision: poll.decision || null,
      },
    });
  } catch (error) {
    console.error("Get Poll Results Error:", error);

    return res.status(500).json({
      success: false,
      message: "Unable to calculate poll results.",
    });
  }
};

/*
|--------------------------------------------------------------------------
| ADMIN
|--------------------------------------------------------------------------
*/

export const createPoll = async (req, res) => {
  try {
    const adminId = getUserId(req);

    if (!adminId) {
      return res.status(401).json({
        success: false,
        message: "Admin authentication required.",
      });
    }

    const {
      title,
      description,
      options,
      startAt,
      endAt,
      showResultsAfterClose,
    } = req.body;

    if (!title || !title.toString().trim()) {
      return res.status(400).json({
        success: false,
        message: "Poll title is required.",
      });
    }

    if (!Array.isArray(options) || options.length < 2) {
      return res.status(400).json({
        success: false,
        message: "At least 2 options are required.",
      });
    }

    const cleanedOptions = options
      .map((option) => {
        if (typeof option === "string") {
          return {
            text: option.trim(),
          };
        }

        return {
          text: option?.text?.toString().trim() || "",
        };
      })
      .filter((option) => option.text.length > 0);

    if (cleanedOptions.length < 2) {
      return res.status(400).json({
        success: false,
        message: "At least 2 valid options are required.",
      });
    }

    const startDate = new Date(startAt);
    const endDate = new Date(endAt);

    if (Number.isNaN(startDate.getTime())) {
      return res.status(400).json({
        success: false,
        message: "Invalid start date/time.",
      });
    }

    if (Number.isNaN(endDate.getTime())) {
      return res.status(400).json({
        success: false,
        message: "Invalid end date/time.",
      });
    }

    if (endDate <= startDate) {
      return res.status(400).json({
        success: false,
        message: "End time must be after start time.",
      });
    }

    const now = new Date();

    let status = "scheduled";

    if (now >= startDate && now < endDate) {
      status = "active";
    }

    if (now >= endDate) {
      return res.status(400).json({
        success: false,
        message: "Poll end time must be in the future.",
      });
    }

    const poll = await Poll.create({
      title: title.toString().trim(),
      description: description?.toString().trim() || "",
      options: cleanedOptions,
      startAt: startDate,
      endAt: endDate,
      status,
      showResultsAfterClose:
        showResultsAfterClose !== false,
      createdBy: adminId,
    });

    return res.status(201).json({
      success: true,
      message: "Poll created successfully.",
      data: poll,
    });
  } catch (error) {
    console.error("Create Poll Error:", error);

    return res.status(500).json({
      success: false,
      message: "Unable to create poll.",
    });
  }
};

export const deletePoll = async (req, res) => {
  try {
    const { pollId } = req.params;

    if (!mongoose.Types.ObjectId.isValid(pollId)) {
      return res.status(400).json({
        success: false,
        message: "Invalid poll ID.",
      });
    }

    const poll = await Poll.findById(pollId);

    if (!poll) {
      return res.status(404).json({
        success: false,
        message: "Poll not found.",
      });
    }

    await PollVote.deleteMany({
      pollId,
    });

    await Poll.deleteOne({
      _id: pollId,
    });

    return res.status(200).json({
      success: true,
      message: "Poll deleted successfully.",
    });
  } catch (error) {
    console.error("Delete Poll Error:", error);

    return res.status(500).json({
      success: false,
      message: "Unable to delete poll.",
    });
  }
};

export const declareDecision = async (req, res) => {
  try {
    const { pollId } = req.params;
    const { optionId } = req.body;

    const adminId = getUserId(req);

    if (!adminId) {
      return res.status(401).json({
        success: false,
        message: "Admin authentication required.",
      });
    }

    if (!mongoose.Types.ObjectId.isValid(pollId)) {
      return res.status(400).json({
        success: false,
        message: "Invalid poll ID.",
      });
    }

    const poll = await Poll.findById(pollId);

    if (!poll) {
      return res.status(404).json({
        success: false,
        message: "Poll not found.",
      });
    }

    const now = new Date();

    if (now < poll.endAt) {
      return res.status(400).json({
        success: false,
        message: "Decision can only be declared after voting closes.",
      });
    }

    const selectedOption = poll.options.find(
      (option) => option._id.toString() === optionId.toString()
    );

    if (!selectedOption) {
      return res.status(400).json({
        success: false,
        message: "Invalid option.",
      });
    }

    poll.status = "closed";

    poll.decision = {
      optionId: selectedOption._id,
      optionText: selectedOption.text,
      declaredBy: adminId,
      declaredAt: new Date(),
    };

    await poll.save();

    return res.status(200).json({
      success: true,
      message: "Final decision declared successfully.",
      data: poll,
    });
  } catch (error) {
    console.error("Declare Decision Error:", error);

    return res.status(500).json({
      success: false,
      message: "Unable to declare decision.",
    });
  }
};