import Complain from "../models/Complain.js";
// Make sure this path is correct for your project
import { uploadToFirebase } from "../ConfigMultar/multar.control.js";

// ==========================================
// 1. CREATE COMPLAIN (For Students)
// ==========================================
export const createComplain = async (req, res) => {
  try {
    const { category, description } = req.body;
    let imageUrl = null;

    // Handle image upload if a file was attached
    if (req.file) {
      imageUrl = await uploadToFirebase(req.file);
    }

    // Safely get user ID (handles both id and _id depending on your auth middleware)
    const studentId = req.user._id || req.user.id;

    const newComplain = await Complain.create({
      studentId: studentId,
      hostelId: req.user.hostelId,
      category,
      description,
      imageUrl,
    });

    res.status(201).json({ success: true, data: newComplain });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ==========================================
// 2. GET ALL COMPLAINS (For Managers)
// ==========================================
export const getHostelComplains = async (req, res) => {
  try {
    const { hostelId } = req.user;

    const complains = await Complain.find({ hostelId })
      .populate("studentId", "name roomNumber department regNum")
      .sort({ createdAt: -1 }); // Newest first

    res.status(200).json({ success: true, count: complains.length, complains });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// ==========================================
// 3. UPDATE COMPLAIN STATUS (For Managers)
// ==========================================
export const updateComplainStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body; // e.g., "Resolved", "Pending", "Rejected"

    // 1. Validate the status to prevent bad data
    const validStatuses = ["Pending", "Resolved", "Rejected"];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ success: false, message: "Invalid status provided." });
    }

    // 2. Find and update the complain
    const updatedComplain = await Complain.findOneAndUpdate(
      { _id: id, hostelId: req.user.hostelId }, // Ensure manager can only update their own hostel's complains
      { status: status },
      { new: true } // Return the updated document
    );

    if (!updatedComplain) {
      return res.status(404).json({ success: false, message: "Complain not found or unauthorized." });
    }

    res.status(200).json({
      success: true,
      message: `Complain marked as ${status} successfully.`,
      complain: updatedComplain
    });
  } catch (error) {
    console.error("Update Complain Error:", error);
    res.status(500).json({ success: false, message: "Failed to update complain status." });
  }
};