import mongoose from "mongoose";

const upiSchema = new mongoose.Schema({
  hostelId: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: "Hostel", 
    required: true, 
    unique: true 
  },
  managerId: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: "User", 
    required: true 
  },
  upiId: { 
    type: String, 
    required: true, 
    trim: true 
  },
  merchantName: { 
    type: String, 
    required: true 
  }, // Name that appears on GPay/PhonePe
  updatedAt: { type: Date, default: Date.now }
});

export default mongoose.model("UpiDetail", upiSchema);