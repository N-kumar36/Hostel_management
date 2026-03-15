import mongoose from "mongoose";

const managerSchema = new mongoose.Schema({
  hostelId: { type: mongoose.Schema.Types.ObjectId, ref: "Hostel", required: true },
  userId: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
  month: { type: String, required: true }, // Format: YYYY-MM
  permissions: {
    mealEdit: { type: Boolean, default: false },
    serveMeal: { type: Boolean, default: false },
    fineManage: { type: Boolean, default: false }
  },
  isActive: { type: Boolean, default: true }
}, { timestamps: true });

export default mongoose.model("ManagerAssignment", managerSchema);