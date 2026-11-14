import mongoose from "mongoose";

const mealPlanSchema = new mongoose.Schema({
  hostelId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "Hostel",
    required: true,
  },

  planType: {
    type: String,
    enum: ["30 meals", "60 meals", "60 veg meals"],
    required: true,
  },

  monthlyPrice: {
    type: Number,
    required: true,
  },

  limits: {
    veg: { type: Number, default: 0 },
    egg: { type: Number, default: 0 },
    paneer: { type: Number, default: 0 },
    chicken: { type: Number, default: 0 },
    fish: { type: Number, default: 0 },
    mutton: { type: Number, default: 0 },
  },

  // Controls whether this plan is available for students
  isEnabled: {
    type: Boolean,
    default: true,
  },

  createdAt: {
    type: Date,
    default: Date.now,
  },
});

// One plan of each type per hostel
mealPlanSchema.index(
  { hostelId: 1, planType: 1 },
  { unique: true }
);

export default mongoose.model("MealPlan", mealPlanSchema);