// src/controllers/user.controller.js
import User from '../models/User.js';
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