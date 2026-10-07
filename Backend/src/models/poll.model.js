import mongoose from "mongoose";

const pollOptionSchema = new mongoose.Schema(
  {
    text: {
      type: String,
      required: true,
      trim: true,
    },
  },
  {
    _id: true,
  }
);

const pollSchema = new mongoose.Schema(
  {
    title: {
      type: String,
      required: true,
      trim: true,
      maxlength: 200,
    },

    description: {
      type: String,
      default: "",
      trim: true,
      maxlength: 2000,
    },

    options: {
      type: [pollOptionSchema],
      required: true,
      validate: {
        validator: function (options) {
          return Array.isArray(options) && options.length >= 2;
        },
        message: "A poll must have at least 2 options.",
      },
    },

    startAt: {
      type: Date,
      required: true,
    },

    endAt: {
      type: Date,
      required: true,
    },

    status: {
      type: String,
      enum: ["scheduled", "active", "closed"],
      default: "scheduled",
      index: true,
    },

    showResultsAfterClose: {
      type: Boolean,
      default: true,
    },

    decision: {
      optionId: {
        type: mongoose.Schema.Types.ObjectId,
        default: null,
      },

      optionText: {
        type: String,
        default: null,
      },

      declaredBy: {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
        default: null,
      },

      declaredAt: {
        type: Date,
        default: null,
      },
    },

    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
  },
  {
    timestamps: true,
  }
);

// Useful indexes
pollSchema.index({
  status: 1,
  startAt: 1,
  endAt: 1,
});

pollSchema.index({
  createdAt: -1,
});

export default mongoose.model("Poll", pollSchema);