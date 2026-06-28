import mongoose from "mongoose";

const userSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true
    },
    phone: { type: String, required: true },
    password: { type: String, required: true },

    // Academic Details
    regNum: { type: String, required: true },      // Added for Flutter RegisterPage
    department: { type: String },  // Added for Flutter RegisterPage
    year: { type: String },        // Added for Flutter RegisterPage


    // Hostel Association
    hostelId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Hostel",
      required: true,
    },

    roomNumber: { type: String },

    // Access Control
    role: {
      type: String,
      enum: ["student", "manager", "admin"],
      default: "student"
    },

    // Pending add to hostel
    status: {
      type: String,
      enum: ["unverified", "active", "passout", "left_hostel"],
      default: "unverified"
    },

    photoURL: { type: String, default: "" },
  },
  { timestamps: true } 
);

export default mongoose.model("User", userSchema);