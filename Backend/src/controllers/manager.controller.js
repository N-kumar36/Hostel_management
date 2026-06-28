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



export const getAllStudent = async (req, res) => {
  try {
    const hostelId = req.user.hostelId;

    const activeStudents = await User.find({
      hostelId: hostelId,
      status: { $in: ["active", "approve"] }
    })
      .select("name email regNum department year photoURL role status") // Selects only the fields required by your Flutter page
      .sort({ name: 1 }); // Alphabetical sort order configuration

    return res.status(200).json({
      success: true,
      count: activeStudents.length,
      data: activeStudents
    });

  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Internal server side database query error fetching active hostel registry list.",
      error: error.message
    });
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
      status: { $in: ["pending", "unverified"] }
    })
      .select("-password")
      .sort({ createdAt: -1 });

    if (!students || students.length === 0) {
      return res.status(404).json({
        success: false,
        message: "No pending or unverified students found for this hostel"
      });
    }

    // Standardized format wrapper matching your app framework signatures
    return res.status(200).json({
      success: true,
      count: students.length,
      data: students
    });

  } catch (error) {
    console.error("Fail to fetch pending registry users:", error);
    return res.status(500).json({
      success: false,
      message: "Server error while compiling pending application coordinates: " + error.message
    });
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

    student.status = "active";
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
      // status: "active"
    }).select("_id name email regNum department year photoURL");

    if (!student || student.length === 0) {
      return res.status(404).json({ message: "Hostel Student not found" });
    }

    return res.status(200).json(student);
  } catch (error) {
    console.error("Fail to fetch Hostel student :", error);
    return res.status(500).json({ success: false, message: "fail to Fetch hostel student", error });
  }
};




export const getStudentSummary = async (req, res) => {
  try {
    const { studentId } = req.params;
    const { startDateStr, endDateStr } = req.query;

    if (!startDateStr || !endDateStr) {
      return res.status(400).json({
        success: false,
        message: "Missing parameter criteria boundaries (startDateStr and endDateStr required).",
      });
    }

    // 1. Convert dynamic text timestamps (DD/MM/YYYY) into native UTC bounds
    const [startDay, startMonth, startYear] = startDateStr.split("/");
    const [endDay, endMonth, endYear] = endDateStr.split("/");

    const trueStartDate = new Date(`${startYear}-${startMonth}-${startDay}T00:00:00.000Z`);
    const trueEndDate = new Date(`${endYear}-${endMonth}-${endDay}T23:59:59.999Z`);

    // 2. Fetch Subscription State data block
    const activeSubscription = await StudentSubscription.findOne({
      studentId: studentId,
      createdAt: { $gte: trueStartDate, $lte: trueEndDate }
    });

    // 3. Fetch Payments & Fines History Data Block
    const finesList = await Fine.find({
      studentId: studentId,
      date: { $gte: trueStartDate, $lte: trueEndDate }
    }).sort({ date: -1 });

    const pendingFinesSum = finesList
      .filter(f => f.status === "pending" || f.status === "processing")
      .reduce((sum, f) => sum + (f.amount || 0), 0);

    const finesPaymentHistory = finesList.map(f => ({
      _id: f._id,
      title: f.title || "Mess Bill Charge",
      amount: f.amount || 0,
      status: f.status,
      paymentScreenshot: f.paymentScreenshot || null,
      paymentMethod: f.paymentMethod || "Offline",
      date: f.date
    }));

    // 4.  OPTIMIZATION: Filter records and populate both slots' ServedBy path with user names
    const targetMeals = await Meal.find({ hostelId: req.user.hostelId })
      .sort({ _id: -1 })
      .limit(90)
      .populate("morning.studentVotes.ServedBy", "name")
      .populate("night.studentVotes.ServedBy", "name");

    let studentOwnVotes = 0;
    let totalGuestVotes = 0;
    let totalServed = 0;
    const votedMealsHistory = [];

    targetMeals.forEach(meal => {
      const [d, m, y] = meal.date.split("/");
      const currentMealDate = new Date(`${y}-${m}-${d}T00:00:00.000Z`);

      // Skip current entry if it falls completely outside our cycle timeline
      if (currentMealDate < trueStartDate || currentMealDate > trueEndDate) return;

      ["morning", "night"].forEach(slot => {
        if (meal[slot]) {
          const slotData = meal[slot];

          // Look for matching user vote footprint inside this slot block
          const userVote = slotData.studentVotes ? slotData.studentVotes.find(
            vote => vote.userId && vote.userId.toString() === studentId
          ) : null;

          // Check the separate guestRequests sub-schema collection for true guest tallies
          const approvedGuestRequest = slotData.guestRequests ? slotData.guestRequests.find(
            g => g.studentId && g.studentId.toString() === studentId && g.status === "approved"
          ) : null;

          const guestCount = approvedGuestRequest ? (approvedGuestRequest.guestCount || 0) : 0;

          // Safely extract the populated name string or fallback to "N/A"
          const servedByName = userVote && userVote.ServedBy ? (userVote.ServedBy.name || "Unknown") : "N/A";

          if (userVote) {
            studentOwnVotes++;
            if (userVote.isServed) totalServed++;
            totalGuestVotes += guestCount;

            votedMealsHistory.push({
              date: meal.date,
              mealsNum: slotData.mealsNum || "0",
              manu: slotData.manu || "N/A", // From the top level of the slot configuration wrapper
              itemPreference: userVote.itemPreference || "regular",
              ServedBy: servedByName,
              slot: slot,
              voted: true,
              isServed: userVote.isServed,
              guestCount: guestCount
            });
          } else {
            // Unvoted day trace elements inside cycle timeline boundaries
            votedMealsHistory.push({
              date: meal.date,
              mealsNum: slotData.mealsNum || "0",
              manu: slotData.manu || "N/A",
              itemPreference: "N/A", // No preferences exist since they didn't place a vote
              ServedBy: "N/A",
              slot: slot,
              voted: false,
              isServed: false,
              guestCount: guestCount
            });
          }
        }
      });
    });




    // SORT ARRANGEMENT: Orders chronologically by absolute Meal Number (1, 2, 3...)
    votedMealsHistory.sort((a, b) => {
      const numA = parseInt(a.mealsNum, 10) || 0;
      const numB = parseInt(b.mealsNum, 10) || 0;

      // Sorts in Ascending order (Meal 1, Meal 2, Meal 3 at the bottom)
      return numA - numB;
    });


    // 5. Send optimized payload response
    return res.status(200).json({
      success: true,
      activeSubscription,
      studentOwnVotes,
      totalGuestVotes,
      totalServed,
      pendingFines: pendingFinesSum,
      votedMealsHistory,
      finesPaymentHistory
    });

  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Internal server error generating student cycle statistics framework.",
      error: error.message
    });
  }
};

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

    // 3.  NEW: Count unresolved pending fines
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
      pendingFines //  Sent directly to your frontend panel state
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
 * @desc     FIXED: Returns settings directly at the root data level without double data wrappers
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

    console.log("Fetched Settings Data:", { finePrices, upi, plans });
    // Returns data clean of nested sub-layers to perfectly satisfy your Flutter text input parsing loops
    return res.status(200).json({
      success: true,
      data: {
        finePrices,
        upi,
        plans
      }
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};





