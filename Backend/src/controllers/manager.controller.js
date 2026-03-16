// controllers/manager.controller.js
import ManagerAssignment from "../models/ManagerAssignment.js";
import User from "../models/User.js";
import Fine from '../models/fine.model.js';
import Vote from '../models/Vote.js';

export const assignManager = async (req, res) => {
  try {
    const { userId, hostelId, month, permissions } = req.body;

    // 1. Check if this user is already assigned as a manager somewhere
    const existingAssignment = await ManagerAssignment.findOne({ userId, isActive: true });
    if (existingAssignment) {
      return res.status(400).json({
        success: false,
        message: "This user is already an active manager."
      });
    }

    // 2. Create the Assignment
    const assignment = await ManagerAssignment.create({
      userId,
      hostelId,
      month,
      permissions: {
        mealEdit: permissions?.mealEdit || false,
        serveMeal: permissions?.serveMeal || false,
        fineManage: permissions?.fineManage || false
      },
      isActive: true
    });

    // 3. Update the User Role
    const updatedUser = await User.findByIdAndUpdate(
      userId,
      { role: "manager" },
      { new: true }
    );

    if (!updatedUser) {
      // Cleanup: if user doesn't exist, remove the assignment we just made
      await ManagerAssignment.findByIdAndDelete(assignment._id);
      return res.status(404).json({ success: false, message: "User not found" });
    }

    res.status(201).json({
      success: true,
      message: "Manager assigned successfully",
      assignment,
      userRole: updatedUser.role
    });

  } catch (err) {
    // Handle MongoDB Unique Index errors (e.g., if you have a unique index on hostelId + month)
    if (err.code === 11000) {
      return res.status(400).json({
        success: false,
        message: "A manager is already assigned to this hostel for this month."
      });
    }
    res.status(500).json({ success: false, message: err.message });
  }
};
export const getCurrentManager = async (req, res) => {
  try {
    const month = new Date().toISOString().slice(0, 7);
    const manager = await ManagerAssignment.findOne({
      hostelId: req.user.hostelId,
      month,
      isActive: true
    }).populate("userId", "name email");

    res.json({ success: true, manager });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};
export const pendingStudent = async (req, res) => {
  try {
    // 1. Use .find() to get a list, not just one user
    // 2. req.user.hostelId must be populated by your auth middleware
    const students = await User.find({
      hostelId: req.user.hostelId,
      pending: "pending" // Querying for the 'pending' status
    }).select("-password"); // Security: Don't send passwords to the frontend

    // 3. Check if we found any students
    if (!students || students.length === 0) {
      return res.status(404).json({ message: "No pending students found for this hostel" });
    }

    // 4. Send the result back to Flutter
    res.status(200).json(students);

  } catch (error) {
    console.error("Fail to fetch:", error);
    res.status(500).json({ message: "Server error while fetching students" });
  }
};
export const pendingApprove = async (req, res) => {
  try {
    const { id } = req.params; // Get student ID from URL parameters

    console.log("pending api is calld", id);

    // 1. Find the student
    const student = await User.findById(id);

    if (!student) {
      return res.status(404).json({ message: "Student not found" });
    }

    // 2. Security Check: Ensure manager is approving a student from their own hostel
    if (student.hostelId.toString() !== req.user.hostelId.toString()) {
      return res.status(403).json({ message: "Unauthorized: This student belongs to another hostel" });
    }

    // 3. Update status to "approve" (matching your Schema enum)
    student.pending = "approve";
    await student.save();

    res.status(200).json({
      success: true,
      message: "Student approved successfully",
      student
    });

  } catch (error) {
    console.error("Approval Error:", error);
    res.status(500).json({ message: "Server error during approval" });
  }
};
export const pendingReject = async (req, res) => {
  try {
    const { id } = req.params;

    console.log("Reject api was called", id);

    // 1. Find the student first
    const student = await User.findById(id);
    
    if (!student) {
      return res.status(404).json({ message: "Student not found" });
    }

    // 2. Security Check: Ensure manager only deletes students from their own hostel
    if (student.hostelId.toString() !== req.user.hostelId.toString()) {
      return res.status(403).json({ 
        message: "Unauthorized: This student belongs to another Hostel" 
      });
    }

    // 3. Delete the student (Wait for the database to finish)
    await User.findByIdAndDelete(id); 

    res.status(200).json({
      success: true, // Fixed typo
      message: "Student registration request rejected and deleted",
    });
    
  } catch (error) {
    console.error("Delete Error:", error);
    res.status(500).json({ message: "Server error during Student delete" });
  }
}
export const getAllHostelStudent = async (req, res) => {
  try {
    const student = await User.find({
      hostelId: req.user.hostelId,
      pending: "approve"
    }).select("-password");

    if (!student || student.length === 0) {
      return res.status(404).json({message: "Hostel Student not found"}); 
    }

    res.status(200).json(student);
    
  } catch (error) {
    console.error("Fail to fetch Hostel student :", error);
    res.status(500).json({success: false, message: "fail to Fetch hostel student", error});
    
  }
}

export const getStudentSummary = async (req, res) => {
  const { studentId } = req.params;

  try {
    // 1. Total Votes: Count every meal record (Personal + Guest)
    // In your schema, the existence of a document MEANS they voted.
    const totalVotes = await Vote.countDocuments({ 
      userId: studentId 
    });

    // 2. Total Served: Count meals actually consumed (Personal + Guest)
    const totalServed = await Vote.countDocuments({ 
      userId: studentId, 
      isServed: true 
    });

    // 3. Breakdown for UI
    // Student's own meals (isGuest is false)
    const studentOwnVotes = await Vote.countDocuments({ 
      userId: studentId, 
      isGuest: false
    });
    
    // Guest meals only
    const totalGuestVotes = await Vote.countDocuments({ 
      userId: studentId, 
      isGuest: true
    });

    // 4. Fine Calculations (Using studentId to match your Fine model)
    const fines = await Fine.find({ studentId }); 
    
    const pendingFines = fines
      .filter(f => f.status === 'pending')
      .reduce((sum, f) => sum + f.amount, 0);
      
    const paidFines = fines
      .filter(f => f.status === 'success')
      .reduce((sum, f) => sum + f.amount, 0);

    res.json({
      success: true,
      totalVotes,       // Sum of studentOwnVotes + totalGuestVotes
      totalServed,      
      studentOwnVotes,  
      totalGuestVotes,  
      pendingFines,
      paidFines
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};