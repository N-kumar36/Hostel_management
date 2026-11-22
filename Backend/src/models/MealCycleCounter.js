import mongoose from "mongoose";

const mealCycleCounterSchema = new mongoose.Schema(
  {
    hostelId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Hostel",
      required: true,
      unique: true,
      index: true,
    },

    // Current cycle: 1, 2, 3, 4...
    cycleNumber: {
      type: Number,
      required: true,
      default: 1,
      min: 1,
    },

    // Last allocated normal meal number: 0–60
    mealNumber: {
      type: Number,
      required: true,
      default: 0,
      min: 0,
      max: 60,
    },
  },
  {
    timestamps: true,
  }
);

export default mongoose.models.MealCycleCounter ||
  mongoose.model("MealCycleCounter", mealCycleCounterSchema);