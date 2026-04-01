// src/controllers/user.controller.js
import User from '../models/User.js';
import Fine from '../models/fine.model.js';


import { ProfileToFirebase } from "../ConfigMultar/multar.control.js";

export const updateProfilePicture = async (req, res) => {
  try {
    // req.file is populated by the handleImageUpload middleware
    if (!req.file) {
      return res.status(400).json({ success: false, message: "No image provided" });
    }

    console.log("Uploading profile pic for user ID:", req.user.id);

    // 1. Upload to Firebase
    const imageUrl = await ProfileToFirebase(req.file);

    // 2. Update MongoDB - Using 'photoURL' as per your userSchema
    const updatedUser = await User.findByIdAndUpdate(
      req.user.id, 
      { photoURL: imageUrl }, 
      { new: true, runValidators: true } // 'new: true' returns the updated doc
    ).select("-password");

    if (!updatedUser) {
      return res.status(404).json({ success: false, message: "User not found" });
    }

    res.status(200).json({
      success: true,
      message: "Profile picture updated successfully!",
      data: updatedUser
    });
  } catch (error) {
    console.error("Upload error:", error.message);
    res.status(500).json({ success: false, message: error.message });
  }
};



export const getStudentPaymentHistory = async (req, res) => {
  try {
    const hostelId = req.user.hostelId; // Assuming hostel ID is available from auth middleware

    if (!hostelId) {
      return res.status(400).json({ success: false, message: "Hostel ID is required." });
    }

    // Calculate the date exactly 30 days ago from right now
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    // Fetch the fines matching the hostelId and within the date range
    const paymentHistory = await Fine.find({
      hostelId: hostelId,
      date: { $gte: thirtyDaysAgo } // $gte means "greater than or equal to"
    })
      .populate("studentId", "name email photoURL regNum") // Fetch student details
      .populate("MealPlanID", "name price")                // Fetch meal plan details (optional)
      .sort({ date: -1 }); // Sort by newest first (-1)

    // Return the formatted response
    res.status(200).json({
      success: true,
      count: paymentHistory.length,
      data: paymentHistory,
    });

  } catch (error) {
    console.error("Error fetching payment history:", error.message);
    res.status(500).json({ success: false, message: "Server Error" });
  }
};