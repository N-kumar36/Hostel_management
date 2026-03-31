import mongoose from "mongoose";

const dayMealSchema = new mongoose.Schema(
  {
    morning: {
      type: String,
      enum: ["veg", "egg", "paneer", "chicken", "fish", "mutton"],
      default: "veg",
      required: true,
    },
    night: {
      type: String,
      enum: ["veg", "egg", "paneer", "chicken", "fish", "mutton"],
      default: "veg",
      required: true,
    },
  },
  { _id: false }
);

const weeklyRoutineSchema = new mongoose.Schema(
  {
    hostelId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Hostel",
      required: true,
      unique: true, // one routine per hostel
    },

    routine: {
      type: Map,
      of: dayMealSchema,
      required: true,
    },
  },
  { timestamps: true }
);

export default mongoose.model("WeeklyRoutine", weeklyRoutineSchema);