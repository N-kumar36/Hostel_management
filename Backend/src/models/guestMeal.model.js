import mongoose from "mongoose";

const guestMealSchema = new mongoose.Schema({
  studentId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  hostelId: { type: mongoose.Schema.Types.ObjectId, ref: 'Hostel', required: true },
  guestCount: { type: Number, required: true, min: 1 },
  mealDate: { type: String, required: true }, // Format: YYYY-MM-DD
  mealTime: { 
    type: String, 
    enum: ['Morning', 'Night'], 
    required: true 
  },
  status: { 
    type: String, 
    enum: ['pending', 'approved', 'rejected'], 
    default: 'pending' 
  },
  createdAt: { type: Date, default: Date.now }
});

export default mongoose.model("GuestMeal", guestMealSchema);