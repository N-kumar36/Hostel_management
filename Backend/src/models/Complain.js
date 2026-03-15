import mongoose from "mongoose";

const complainSchema = new mongoose.Schema({
  studentId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  hostelId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Hostel',
    required: true
  },
  category: {
    type: String,
    enum: ['Food Quality', 'Hygiene Issue', 'Staff Behavior', 'Meal Timing', 'Others'],
    required: true
  },
  description: {
    type: String,
    required: true
  },
  status: {
    type: String,
    enum: ['Pending', 'In Progress', 'Resolved'],
    default: 'Pending'
  },
  imageUrl: {
    type: String, // Path to the uploaded photo
    default: null
  }
}, { timestamps: true });

export default mongoose.model("Complain", complainSchema);