import mongoose from "mongoose";

const managerSchema = new mongoose.Schema({
  hostelId: { type: mongoose.Schema.Types.ObjectId, ref: "Hostel", required: true },
  userId: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
  //  Removed the month field
  permissions: {
    mealEdit: { type: Boolean, default: false },
    serveMeal: { type: Boolean, default: false },
    fineManage: { type: Boolean, default: false }
  },
  isActive: { type: Boolean, default: true }
}, { timestamps: true });

// Ensure a user can only be assigned to a hostel once
managerSchema.index({ hostelId: 1, userId: 1 }, { unique: true });

export default mongoose.model("ManagerAssignment", managerSchema);