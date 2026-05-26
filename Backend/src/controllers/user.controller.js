// src/controllers/user.controller.js
import mongoose from "mongoose"; // Fixed: Added this line
import User from '../models/User.js';
import Fine from '../models/fine.model.js';
import StudentSubscription from "../models/StudentSubscription.js";
import Meal from "../models/Meal.js";





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









/**
 * 📊 INTERNAL UTILITY: Retrieves the exact absolute sequence number of a target meal 
 * in the system's timeline, filtering out completely cancelled entries.
 */
const getMealSequenceNumber = async (hostelId, targetDateStr, targetSlot) => {
  const allMeals = await Meal.find({ hostelId });

  // Sort meals chronologically by true calendar dates
  allMeals.sort((a, b) => {
    const [dA, mA, yA] = a.date.split("/").map(Number);
    const [dB, mB, yB] = b.date.split("/").map(Number);
    return new Date(yA, mA - 1, dA) - new Date(yB, mB - 1, dB);
  });

  let activeCounter = 0;
  for (let meal of allMeals) {
    if (!meal.morning.isCancelled) {
      activeCounter++;
      if (meal.date === targetDateStr && targetSlot === "morning") return activeCounter;
    }
    if (!meal.night.isCancelled) {
      activeCounter++;
      if (meal.date === targetDateStr && targetSlot === "night") return activeCounter;
    }
  }
  return activeCounter;
};

/**
 * 📊 INTERNAL UTILITY: Finds the calendar Date object corresponding to an absolute meal sequence number.
 */
const getMealDateBySequenceNumber = async (hostelId, targetSeqNum) => {
  const allMeals = await Meal.find({ hostelId });

  allMeals.sort((a, b) => {
    const [dA, mA, yA] = a.date.split("/").map(Number);
    const [dB, mB, yB] = b.date.split("/").map(Number);
    return new Date(yA, mA - 1, dA) - new Date(yB, mB - 1, dB);
  });

  let activeCounter = 0;
  for (let meal of allMeals) {
    if (!meal.morning.isCancelled) {
      activeCounter++;
      if (activeCounter === targetSeqNum) {
        const [d, m, y] = meal.date.split("/").map(Number);
        return new Date(y, m - 1, d, 0, 0, 0);
      }
    }
    if (!meal.night.isCancelled) {
      activeCounter++;
      if (activeCounter === targetSeqNum) {
        const [d, m, y] = meal.date.split("/").map(Number);
        return new Date(y, m - 1, d, 23, 59, 59);
      }
    }
  }
  return null;
};

/**
 * @desc    Get payment history, dynamically resolving if a fine falls within the 
 *          explicit duration window of Meal #1 to Meal #60 for the active package.
 * @route   GET /api/user/all-payment-history
 */
export const getStudentPaymentHistory = async (req, res) => {
  try {
    const hostelId = req.user.hostelId;

    if (!hostelId) {
      return res.status(400).json({ success: false, message: "Hostel ID context reference is missing." });
    }

    // 1. Fetch all logged fines matching this hostel context
    const paymentHistory = await Fine.find({ hostelId })
      .populate("studentId", "name email photoURL regNum")
      .populate("MealPlanID", "name price")
      .sort({ date: -1 });

    // 2. Map and augment the payment history records list asynchronously
    const processedData = await Promise.all(paymentHistory.map(async (fine) => {
      const fineDoc = fine.toObject();
      const studentId = fineDoc.studentId?._id || fineDoc.studentId;

      if (!studentId) {
        fineDoc.belongsToCurrentCycle = false;
        fineDoc.cycleDescription = "Previous Cycle / Unresolved Student Identity";
        return fineDoc;
      }

      // 3. Find the student's current operational subscription package (Active or Pending)
      const currentSubscription = await StudentSubscription.findOne({
        studentId,
        hostelId,
        status: { $in: ["active", "pending"] },
        createdAt: { $lte: new Date(fineDoc.date) }
      }).sort({ createdAt: -1 });

      if (!currentSubscription) {
        fineDoc.belongsToCurrentCycle = false;
        fineDoc.cycleDescription = "Previous Cycle Balance (No active package found)";
        return fineDoc;
      }

      // 4. RULE CHECK A: Base Subscription Plan Initialization Fee
      if (fineDoc.isMealPackage) {
        const subInitTime = new Date(currentSubscription.createdAt).getTime();
        const billInitTime = new Date(fineDoc.date).getTime();

        if (Math.abs(billInitTime - subInitTime) < 10000) {
          fineDoc.belongsToCurrentCycle = true;
          fineDoc.cycleDescription = "Current Cycle Base Subscription Bill";
          return fineDoc;
        }
      }

      // 5. ✨ NEW TIMELINE DURATION LOGIC VERIFICATION:
      // Find absolute meal sequence indices for the current subscription block bounds
      const subCreatedAtDate = new Date(currentSubscription.createdAt);
      const subDateFormatted = `${String(subCreatedAtDate.getDate()).padStart(2, '0')}/${String(subCreatedAtDate.getMonth() + 1).padStart(2, '0')}/${subCreatedAtDate.getFullYear()}`;

      // Absolute meal number when this package went live (Meal #1 of the block)
      const cycleStartMealAbsIndex = await getMealSequenceNumber(hostelId, subDateFormatted, "morning");
      // Absolute meal number when this package reaches its limit (Meal #60 of the block)
      const cycleEndMealAbsIndex = cycleStartMealAbsIndex + 59;

      // Convert these bounds to real calendar dates
      const cycleStartDate = await getMealDateBySequenceNumber(hostelId, cycleStartMealAbsIndex);
      let cycleEndDate = await getMealDateBySequenceNumber(hostelId, cycleEndMealAbsIndex);

      // Fallback if 60 meals haven't been generated in the system yet: set a future boundary date safely
      if (!cycleEndDate && cycleStartDate) {
        cycleEndDate = new Date(cycleStartDate.getTime());
        cycleEndDate.setDate(cycleEndDate.getDate() + 30); // Project 30 days outward
      }

      // 6. Compare the fine's record creation date directly against this duration window
      if (cycleStartDate && cycleEndDate) {
        const fineTimestamp = new Date(fineDoc.date);

        // ✨ DURATION CHECK: Is the fine date inside the Meal 1 to Meal 60 window?
        if (fineTimestamp.getTime() >= cycleStartDate.getTime() && fineTimestamp.getTime() <= cycleEndDate.getTime()) {
          fineDoc.belongsToCurrentCycle = true;
          fineDoc.cycleDescription = "Current Mess Fine (Falls inside Meal 1-60 Cycle Duration)";
          return fineDoc;
        }
      }

      // Default Fallback: If it falls outside the active calendar duration boundaries, classify it as historical debt
      fineDoc.belongsToCurrentCycle = false;
      fineDoc.cycleDescription = "Previous Cycle Balance (Outside active 1-60 block duration)";
      return fineDoc;
    }));

    // Find live master index token reference code
    const runningActiveSub = await StudentSubscription.findOne({ hostelId, status: "active" }).select("_id");

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