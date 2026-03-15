import mongoose from "mongoose";

const mealTimeSchema = new mongoose.Schema(
  {
    manu: {
      type: String,
      enum: ["veg", "egg", "paneer", "chicken", "fish", "mutton"],
      required: true,
    },
    mealsNum: {
      type: String,
    },
    // Added separate lockTime for this specific meal
    lockTime: {
      type: Date,
      required: true,
    },
    isLocked: {
      type: Boolean,
      default: false,
    },
    isCancelled: {
      type: Boolean,
      default: false,
    },
  },
  { _id: false }
);

const mealSchema = new mongoose.Schema(
  {
    hostelId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Hostel",
      required: true,
    },

    date: {
      type: String, // DD/MM/YYYY
      required: true,
    },

    morning: {
      type: mealTimeSchema,
      required: true,
    },

    night: {
      type: mealTimeSchema,
      required: true,
    },
  },
  { timestamps: true }
);

// Ensures only one meal document exists per hostel per day
mealSchema.index({ hostelId: 1, date: 1 }, { unique: true });

export default mongoose.model("Meal", mealSchema);