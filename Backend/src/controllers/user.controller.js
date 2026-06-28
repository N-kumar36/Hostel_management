import mongoose from "mongoose";
import User from '../models/User.js';
import Fine from '../models/fine.model.js';
import StudentSubscription from "../models/StudentSubscription.js";
import Meal from "../models/Meal.js";

import { ProfileToFirebase } from "../ConfigMultar/multar.control.js";

export const updateProfilePicture = async (req, res) => {
  try {

    if (!req.file) {
      return res.status(400).json({ success: false, message: "No image provided" });
    }

    console.log("Uploading profile pic for user ID:", req.user.id);

    const imageUrl = await ProfileToFirebase(req.file);

    const updatedUser = await User.findByIdAndUpdate(
      req.user.id,
      { photoURL: imageUrl },
      { new: true, runValidators: true }
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


// admin APIs
export const getProfile = async (req, res) => {
  try {
    const { id } = req.params;
    console.log("GetProfile manager requested ID:", id);

    if (!id) {
      return res.status(400).json({ success: false, message: "Id not Provided" });
    }

    const findUser = await User.findById(id).select("-password").populate("hostelId");

    if (!findUser) {
      return res.status(404).json({ success: false, message: "User Not found" });
    }

    return res.status(200).json({
      success: true,
      message: "Profile Found Successfully",
      data: findUser
    });

  } catch (error) {
    console.error("GetProfile function error: " + error);
    return res.status(500).json({ success: false, message: error.message });
  }
};

export const getStudentPaymentHistory = async (req, res) => {
  try {
    const hostelId = req.user.hostelId;

    if (!hostelId) {
      return res.status(400).json({ success: false, message: "Hostel ID context reference is missing." });
    }

    const allMeals = await Meal.find({ hostelId }).lean();
    allMeals.sort((a, b) => {
      const [dA, mA, yA] = a.date.split("/").map(Number);
      const [dB, mB, yB] = b.date.split("/").map(Number);
      return new Date(yA, mA - 1, dA) - new Date(yB, mB - 1, dB);
    });


    const mealTimelineMap = {};
    const sequenceToDateMap = {};
    let globalMealCounter = 0;

    for (let meal of allMeals) {
      const [d, m, y] = meal.date.split("/").map(Number);
      const normalizedDate = `${d}/${m}/${y}`;

      if (!meal.morning?.isCancelled) {
        globalMealCounter++;
        mealTimelineMap[`${normalizedDate}_morning`] = globalMealCounter;
        sequenceToDateMap[globalMealCounter] = new Date(y, m - 1, d, 0, 0, 0);
      }
      if (!meal.night?.isCancelled) {
        globalMealCounter++;
        mealTimelineMap[`${normalizedDate}_night`] = globalMealCounter;
        sequenceToDateMap[globalMealCounter] = new Date(y, m - 1, d, 23, 59, 59);
      }
    }

    // 1. Fetch all logged fines matching this hostel context
    const paymentHistory = await Fine.find({ hostelId })
      .populate("studentId", "name email photoURL regNum")
      .populate("MealPlanID", "name price")
      .sort({ date: -1 })
      .lean();

    // 2. Fetch active/pending subscriptions
    const activeSubscriptions = await StudentSubscription.find({
      hostelId,
      status: { $in: ["active", "pending"] }
    }).sort({ createdAt: -1 }).lean();

    // 3. Process records synchronously using sequence duration logic maps
    const processedData = paymentHistory.map((fineDoc) => {
      const studentId = fineDoc.studentId?._id || fineDoc.studentId;

      if (!studentId) {
        fineDoc.belongsToCurrentCycle = false;
        fineDoc.skipRecord = true;
        return fineDoc;
      }

      const fineStatus = (fineDoc.status || "").toLowerCase();
      if (!['pending', 'processing', 'success'].includes(fineStatus)) {
        fineDoc.skipRecord = true;
        return fineDoc;
      }

      // Find the matching student subscription loop instance
      const currentSubscription = activeSubscriptions.find(sub =>
        sub.studentId.toString() === studentId.toString() &&
        new Date(sub.createdAt) <= new Date(fineDoc.date)
      );

      // If no active subscription is active on this day, it's automatically an old due
      if (!currentSubscription) {
        if (fineStatus === 'success') {
          fineDoc.skipRecord = true;
          return fineDoc;
        }
        fineDoc.belongsToCurrentCycle = false;
        fineDoc.cycleDescription = "Previous Mess Balance (No active package)";
        return fineDoc;
      }

      // RULE 1: Base Subscription Package Bill is ALWAYS current
      if (fineDoc.isMealPackage) {
        fineDoc.belongsToCurrentCycle = true;
        fineDoc.cycleDescription = "Current Mess Base Package Bill";
        return fineDoc;
      }

      // RULE 2: Tracing Guest Meals / Extra Fines under the 1 to 60 Meal Sequence Boundary Window
      const desc = fineDoc.description || "";
      const dateMatch = desc.match(/(\d{2}\/\d{2}\/\d{4})/);
      const targetSlot = desc.toLowerCase().includes("morning") ? "morning" : "night";

      if (dateMatch) {
        const [fd, fm, fy] = dateMatch[1].split("/").map(Number);
        const normalizedFineDateStr = `${fd}/${fm}/${fy}`;

        // Find absolute meal timeline number when the guest meal fine happened
        const fineMealAbsSequence = mealTimelineMap[`${normalizedFineDateStr}_${targetSlot}`];

        if (fineMealAbsSequence) {
          const subCreatedAtDate = new Date(currentSubscription.createdAt);
          const subDateFormatted = `${subCreatedAtDate.getDate()}/${subCreatedAtDate.getMonth() + 1}/${subCreatedAtDate.getFullYear()}`;

          // Find Meal #1 for this package block
          const cycleStartMealIndex = mealTimelineMap[`${subDateFormatted}_morning`] || fineMealAbsSequence;
          // Calculate Meal #60 destination index marker boundary
          const cycleEndMealIndex = cycleStartMealIndex + 59;

          // Convert sequence markers to exact calendar dates
          const cycleStartDate = sequenceToDateMap[cycleStartMealIndex];
          let cycleEndDate = sequenceToDateMap[cycleEndMealIndex];

          // Fallback project: if 60 meals aren't added to the db yet, map 30 days ahead safely
          if (!cycleEndDate && cycleStartDate) {
            cycleEndDate = new Date(cycleStartDate.getTime());
            cycleEndDate.setDate(cycleEndDate.getDate() + 30);
          }

          if (cycleStartDate && cycleEndDate) {
            const fineTimestamp = new Date(fineDoc.date);

            if (fineTimestamp.getTime() >= cycleStartDate.getTime() && fineTimestamp.getTime() <= cycleEndDate.getTime()) {
              fineDoc.belongsToCurrentCycle = true;
              fineDoc.cycleDescription = "Current Mess Extra Fine (Within Meal 1-60 lifespan)";
              return fineDoc;
            }
          }
        }
      }

      if (fineStatus === 'success') {
        fineDoc.skipRecord = true;
        return fineDoc;
      }

      fineDoc.belongsToCurrentCycle = false;
      fineDoc.cycleDescription = "Previous Mess Balance (Exceeded 60-meal block boundaries)";
      return fineDoc;
    }).filter(fine => !fine.skipRecord);

    const runningActiveSub = await StudentSubscription.findOne({ hostelId, status: "active" }).select("_id").lean();

    return res.status(200).json({
      success: true,
      activeSubscriptionId: runningActiveSub ? runningActiveSub._id.toString() : null,
      data: processedData
    });

  } catch (error) {
    console.error("Payment History Tracing Matrix Failed:", error);
    return res.status(500).json({ success: false, message: "Internal Server Error: " + error.message });
  }
};


export const updateProfile = async (req, res) => {
  try {
    const { id } = req.params;
    const requesterId = req.user._id; // Extracted safely from your 'protect' middleware layer
    const hostelId = req.user.hostelId;

    const { name, email, phone, regNum, roomNumber, department, year, role, status } = req.body;

    //  Fetch the target user's current record first to verify their existing privileges
    const targetUser = await User.findById(id);
    if (!targetUser) {
      return res.status(404).json({ success: false, message: "User not found" });
    }

    //  GUARDRAIL 1: Prevent users from modifying their own role parameters
    if (id.toString() === requesterId.toString()) {
      if (role && role !== targetUser.role) {
        return res.status(403).json({
          success: false,
          message: "Security Violation: You cannot alter your own operational authorization role."
        });
      }
    }

    //  GUARDRAIL 2: Minimum Admin Count Enforcement Requirement Check
    const isTargetCurrentlyAdmin = targetUser.role?.toLowerCase() === 'admin';
    const isChangingAdminRoleOrStatus = (role && role.toLowerCase() !== 'admin') || (status && status !== 'active');

    if (isTargetCurrentlyAdmin && isChangingAdminRoleOrStatus) {
      // Count how many alternative active admins exist inside this specific hostel
      const activeAdminsCount = await User.countDocuments({
        hostelId: hostelId,
        role: { $regex: /^admin$/i }, // Case-insensitive matching string parameter match
        status: "active"
      });

      // If this user is the last remaining admin, reject the update operation
      if (activeAdminsCount <= 1) {
        return res.status(422).json({
          success: false,
          message: "Action Blocked: A hostel must retain at least 1 active Admin on record. Please assign another Admin before removing this one."
        });
      }
    }

    //  Commit Schema Save Changes safely since checks passed successfully
    const updatedUser = await User.findByIdAndUpdate(
      id,
      { name, email, regNum, phone, roomNumber, department, year, role, status },
      { new: true, runValidators: true }
    );

    return res.status(200).json({
      success: true,
      message: "Profile schema properties committed successfully",
      data: updatedUser
    });

  } catch (error) {
    console.error("Profile Update Error:", error);
    return res.status(500).json({
      success: false,
      message: "Internal Server Error: " + error.message
    });
  }
};

export const deleteProfile = async (req, res) => {
  try {
    const { id } = req.params;

    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ success: false, message: "Invalid user ID format" });
    }

    const deletedUser = await User.findByIdAndDelete(id);

    if (!deletedUser) {
      return res.status(404).json({ success: false, message: "User not found" });
    }

    return res.status(200).json({ success: true, message: "Profile deleted successfully", data: deletedUser });

  } catch (error) {
    console.error("Profile Delete Error:", error);
    return res.status(500).json({ success: false, message: "Internal Server Error:" + error.message });
  }
}