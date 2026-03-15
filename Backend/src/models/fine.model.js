import mongoose from "mongoose";

const fineSchema = new mongoose.Schema({
  studentId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  managerId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  hostelId: { type: mongoose.Schema.Types.ObjectId, ref: 'Hostel', required: true },
  title: { type: String, required: true }, // e.g., "Late Entry", "Damaged Property"
  amount: { type: Number, required: true },
  description: { type: String },
  status: { 
    type: String, 
    enum: ['pending', 'processing', 'success'], 
    default: 'pending' 
  },
  paymentScreenshot: { type: String }, // URL from Firebase
  date: { type: Date, default: Date.now }
});

export default mongoose.model("Fine", fineSchema);