import mongoose from "mongoose";

const studentSubscriptionSchema = new mongoose.Schema({
  studentId: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
  hostelId: { type: mongoose.Schema.Types.ObjectId, ref: "Hostel", required: true },
  mealsPlanId: { type: mongoose.Schema.Types.ObjectId, ref: "MealPlan", required: true},
  month: { type: String, required: true }, // e.g., "March 2026"
  planType: { type: String, required: true }, // "30 meals" or "60 meals"
  amount: { type: Number, required: true },

  // These are the limits copied from the MealPlan
  maxLimits: {
    veg: Number,
    egg: Number,
    paneer: Number,
    chicken: Number,
    fish: Number,
    mutton: Number
  },

  // This is what the student actually eats (Starts at 0)
  usage: {
    veg: { type: Number, default: 0 },
    egg: { type: Number, default: 0 },
    paneer: { type: Number, default: 0 },
    chicken: { type: Number, default: 0 },
    fish: { type: Number, default: 0 },
    mutton: { type: Number, default: 0 }
  },

  status: { type: String, enum: ["pending", "active", "completed"], default: "pending" },
  createdAt: { type: Date, default: Date.now }
});

// Ensure a student only has one subscription per month
// studentSubscriptionSchema.index({ studentId: 1, month: 1 }, { unique: true });

export default mongoose.model("StudentSubscription", studentSubscriptionSchema);