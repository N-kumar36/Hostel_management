import mongoose from "mongoose";

const pollVoteSchema = new mongoose.Schema(
  {
    pollId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Poll",
      required: true,
      index: true,
    },

    studentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },

    optionId: {
      type: mongoose.Schema.Types.ObjectId,
      required: true,
    },

    votedAt: {
      type: Date,
      default: Date.now,
    },
  },
  {
    timestamps: true,
  }
);

// One student can vote only once in one poll.
pollVoteSchema.index(
  {
    pollId: 1,
    studentId: 1,
  },
  {
    unique: true,
  }
);

export default mongoose.model("PollVote", pollVoteSchema);