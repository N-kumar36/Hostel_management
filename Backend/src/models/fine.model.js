import mongoose from "mongoose";

const fineSchema = new mongoose.Schema({
  studentId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  managerId: { type: mongoose.Schema.Types.ObjectId, ref: 'User'},
  hostelId: { type: mongoose.Schema.Types.ObjectId, ref: 'Hostel', required: true },
  title: { type: String, required: true },
  amount: { type: Number, required: true },
  description: { type: String },

  // NEW: Identifies this fine as a meal package bill
  isMealPackage: {
    type: Boolean,
    default: false
  },
  MealPlanID: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'MealPlan',
    default: null
  },

  subscriptionId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'StudentSubscription',
    default: null
  },

  paymentMethod: {
    type: String,
    enum: ['Offline', 'Online'],
    default: null
  },

  

  status: {
    type: String,
    enum: ['pending', 'processing', 'success', 'reject'],
    default: 'pending'
  },
  paymentScreenshot: { type: String },
  date: { type: Date, default: Date.now }
});

export default mongoose.model("Fine", fineSchema);