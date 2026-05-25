import ManagerAssignment from "../models/ManagerAssignment.js";
import User from "../models/User.js";
import Fine from '../models/fine.model.js'; // Capitalized to match standard references
import Meal from '../models/Meal.js';  // Replaces separate Vote and GuestMeal collection pointers
import FinePrice from '../models/FinePrice.js';
import UpiDetail from '../models/UpiDetail.js';
import MealPlan from '../models/MealPlan.js';
import Complain from "../models/Complain.js";
import StudentSubscription from "../models/StudentSubscription.js"; // Ensure path is correct
import mongoose from "mongoose";


/**
 * @desc    Assign a user as a hostel manager
 * @route   POST /api/manager/assign
 */
export const assignManager = async (req, res) => {
  try {
    const { userId, hostelId, month, permissions } = req.body;

    const existingAssignment = await ManagerAssignment.findOne({ userId, isActive: true });
    if (existingAssignment) {
      return res.status(400).json({
        success: false,
        message: "This user is already an active manager."
      });
    }

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

    const updatedUser = await User.findByIdAndUpdate(
      userId,
      { role: "manager" },
      { new: true }
    );

    if (!updatedUser) {
      await ManagerAssignment.findByIdAndDelete(assignment._id);
      return res.status(404).json({ success: false, message: "User not found" });
    }

    return res.status(201).json({
      success: true,
      message: "Manager assigned successfully",
      assignment,
      userRole: updatedUser.role
    });

  } catch (err) {
    if (err.code === 11000) {
      return res.status(400).json({
        success: false,
        message: "A manager is already assigned to this hostel for this month."
      });
    }
    return res.status(500).json({ success: false, message: err.message });
  }
};

/**
 * @desc    Get current month's active manager assignment configurations
 * @route   GET /api/manager/current
 */
export const getCurrentManager = async (req, res) => {
  try {
    const month = new Date().toISOString().slice(0, 7);
    const manager = await ManagerAssignment.findOne({
      hostelId: req.user.hostelId,
      month,
      isActive: true
    }).populate("userId", "name email");

    return res.json({ success: true, manager });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

/**
 * @desc    Get a list of all students waiting for hostel registration approvals
 * @route   GET /api/manager/pending-students
 */
export const pendingStudent = async (req, res) => {
  try {
    const students = await User.find({
      hostelId: req.user.hostelId,
      pending: "pending"
    }).select("-password");

    if (!students || students.length === 0) {
      return res.status(404).json({ message: "No pending students found for this hostel" });
    }

    return res.status(200).json(students);
  } catch (error) {
    console.error("Fail to fetch:", error);
    return res.status(500).json({ message: "Server error while fetching students" });
  }
};

/**
 * @desc    Approve a pending student's account registration request
 * @route   PUT /api/manager/approve-student/:id
 */
export const pendingApprove = async (req, res) => {
  try {
    const { id } = req.params;
    const student = await User.findById(id);

    if (!student) return res.status(404).json({ message: "Student not found" });

    if (student.hostelId.toString() !== req.user.hostelId.toString()) {
      return res.status(403).json({ message: "Unauthorized: This student belongs to another hostel" });
    }

    student.pending = "approve";
    await student.save();

    return res.status(200).json({
      success: true,
      message: "Student approved successfully",
      student
    });
  } catch (error) {
    console.error("Approval Error:", error);
    return res.status(500).json({ message: "Server error during approval" });
  }
};

/**
 * @desc    Reject and delete a pending registration request entry
 * @route   DELETE /api/manager/reject-student/:id
 */
export const pendingReject = async (req, res) => {
  try {
    const { id } = req.params;
    const student = await User.findById(id);

    if (!student) return res.status(404).json({ message: "Student not found" });

    if (student.hostelId.toString() !== req.user.hostelId.toString()) {
      return res.status(403).json({ message: "Unauthorized: This student belongs to another Hostel" });
    }

    await User.findByIdAndDelete(id);

    return res.status(200).json({
      success: true,
      message: "Student registration request rejected and deleted",
    });
  } catch (error) {
    console.error("Delete Error:", error);
    return res.status(500).json({ message: "Server error during Student delete" });
  }
};

/**
 * @desc    Get all active, approved students registered in the manager's hostel
 * @route   GET /api/manager/students
 */
export const getAllHostelStudent = async (req, res) => {
  try {
    const student = await User.find({
      hostelId: req.user.hostelId,
      pending: "approve"
    }).select("-password");

    if (!student || student.length === 0) {
      return res.status(404).json({ message: "Hostel Student not found" });
    }

    return res.status(200).json(student);
  } catch (error) {
    console.error("Fail to fetch Hostel student :", error);
    return res.status(500).json({ success: false, message: "fail to Fetch hostel student", error });
  }
};

/**
 * @desc    ✨ FIXED: Gathers summary counts directly from the embedded arrays in the Meal documents
 * @route   GET /api/manager/student-summary/:studentId
 */



export const getStudentSummary = async (req, res) => {
  const { studentId } = req.params;
  const hostelId = req.user.hostelId;

  try {
    // 1. Fetch active subscription data directly from database
    const activeSubscription = await StudentSubscription.findOne({
      studentId,
      hostelId,
      status: "active"
    }).lean();

    // 2. Read all daily meals configured under this manager's hostel scope
    const meals = await Meal.find({ hostelId }).lean();

    let studentOwnVotes = 0;
    let totalServed = 0;
    let totalGuestVotes = 0;

    for (const meal of meals) {
      ['morning', 'night'].forEach(slotKey => {
        const slot = meal[slotKey];
        if (!slot) return;

        const personalVote = (slot.studentVotes || []).find(v => v.userId.toString() === studentId);
        if (personalVote) {
          studentOwnVotes++;
          if (personalVote.isServed) totalServed++;
        }

        const studentGuests = (slot.guestRequests || []).filter(
          g => g.studentId.toString() === studentId && g.status === "approved"
        );
        totalGuestVotes += studentGuests.reduce((sum, g) => sum + g.guestCount, 0);
      });
    }

    const totalVotes = studentOwnVotes + totalGuestVotes;

    // 3. Collect billing analytics from fines collection
    const fines = await Fine.find({ studentId }).lean();

    const pendingFines = fines
      .filter(f => f.status === 'pending')
      .reduce((sum, f) => sum + (f.amount || 0), 0);

    return res.json({
      success: true,
      totalVotes,
      totalServed,
      studentOwnVotes,
      totalGuestVotes,
      pendingFines,
      activeSubscription // ✨ CRITICAL: Return the schema keys cleanly back to Flutter!
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};


/**
 * @desc    Fetch optimized summary action counters for the manager's dashboard panel
 * @route   GET /api/dashboard/counts
 */
export const getDashboardCounts = async (req, res) => {
  try {
    const hostelId = req.user.hostelId;

    // 1. Count pending students
    const pendingStudents = await User.countDocuments({
      hostelId,
      pending: "pending"
    });

    // 2. Count pending complaints
    const pendingComplaints = await Complain.countDocuments({
      hostelId,
      status: "Pending"
    });

    // 3. ✨ NEW: Count unresolved pending fines
    const pendingFines = await Fine.countDocuments({
      hostelId,
      status: "pending" // Matches 'pending' from your schema enum
    });

    // 4. Native aggregation for pending guest counts
    const guestCounts = await Meal.aggregate([
      { $match: { hostelId: new mongoose.Types.ObjectId(hostelId) } },
      {
        $project: {
          totalPending: {
            $add: [
              {
                $size: {
                  $filter: {
                    input: { $ifNull: ["$morning.guestRequests", []] },
                    as: "req",
                    cond: { $eq: ["$$req.status", "pending"] }
                  }
                }
              },
              {
                $size: {
                  $filter: {
                    input: { $ifNull: ["$night.guestRequests", []] },
                    as: "req",
                    cond: { $eq: ["$$req.status", "pending"] }
                  }
                }
              }
            ]
          }
        }
      },
      {
        $group: {
          _id: null,
          totalPendingGuests: { $sum: "$totalPending" }
        }
      }
    ]);

    const pendingGuests = guestCounts.length > 0 ? guestCounts[0].totalPendingGuests : 0;

    console.log("Dashboard Counts:", { pendingStudents, pendingGuests, pendingComplaints, pendingFines });

    return res.status(200).json({
      success: true,
      pendingStudents,
      pendingGuests,
      pendingComplaints,
      pendingFines // ✨ Sent directly to your frontend panel state
    });

  } catch (error) {
    console.error("Dashboard Counts Aggregation Error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * @desc    Save all mess configuration metrics concurrently
 * @route   POST /api/manager/settings
 */
export const saveSattingData = async (req, res) => {
  try {
    const { finePrices, plans, upi } = req.body;
    const hostelId = req.user.hostelId;
    const managerId = req.user._id || req.user.id;

    const priceUpdate = FinePrice.findOneAndUpdate(
      { hostelId },
      { prices: finePrices },
      { upsert: true, new: true }
    );

    const upiUpdate = UpiDetail.findOneAndUpdate(
      { hostelId },
      { managerId, upiId: upi.upiId, merchantName: upi.merchantName },
      { upsert: true, new: true }
    );

    const basicPlanUpdate = MealPlan.findOneAndUpdate(
      { hostelId, planType: "30 meals" },
      { monthlyPrice: plans.basic.price, limits: plans.basic.limits },
      { upsert: true, new: true }
    );

    const premiumPlanUpdate = MealPlan.findOneAndUpdate(
      { hostelId, planType: "60 meals" },
      { monthlyPrice: plans.premium.price, limits: plans.premium.limits },
      { upsert: true, new: true }
    );

    const vegPlanUpdate = MealPlan.findOneAndUpdate(
      { hostelId, planType: "60 veg meals" },
      { monthlyPrice: plans.veg_60.price, limits: plans.veg_60.limits },
      { upsert: true, new: true }
    );

    await Promise.all([
      priceUpdate,
      upiUpdate,
      basicPlanUpdate,
      premiumPlanUpdate,
      vegPlanUpdate
    ]);

    return res.status(200).json({ success: true, message: "Settings saved successfully" });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * @desc    ✨ FIXED: Returns settings directly at the root data level without double data wrappers
 * @route   GET /api/manager/settings
 */
export const getSattingData = async (req, res) => {
  try {
    const hostelId = req.user.hostelId;

    const [finePrices, upi, plans] = await Promise.all([
      FinePrice.findOne({ hostelId }).lean(),
      UpiDetail.findOne({ hostelId }).lean(),
      MealPlan.find({ hostelId }).lean()
    ]);

    // Returns data clean of nested sub-layers to perfectly satisfy your Flutter text input parsing loops
    return res.status(200).json({
      success: true,
      finePrices,
      upi,
      plans
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};





