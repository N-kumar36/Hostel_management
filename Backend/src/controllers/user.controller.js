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
 * @desc    Get fast payment history filtering out past success fines
 * @route   GET /api/user/all-payment-history
 */
export const getStudentPaymentHistory = async (req, res) => {
  try {
    const hostelId = req.user.hostelId;

    if (!hostelId) {
      return res.status(400).json({ success: false, message: "Hostel ID context reference is missing." });
    }

    // ⚡ OPTIMIZATION 1: Load all meals into memory once and sort chronologically
    const allMeals = await Meal.find({ hostelId }).lean();
    allMeals.sort((a, b) => {
      const [dA, mA, yA] = a.date.split("/").map(Number);
      const [dB, mB, yB] = b.date.split("/").map(Number);
      return new Date(yA, mA - 1, dA) - new Date(yB, mB - 1, dB);
    });

    // ⚡ OPTIMIZATION 2: Build synchronous indexing maps for instant query lookups
    const mapByDate = {}; 
    const mapBySeq = {};  
    let activeCounter = 0;

    for (let meal of allMeals) {
      const [d, m, y] = meal.date.split("/").map(Number);
      const normalizedDateStr = `${d}/${m}/${y}`;

      if (!meal.morning?.isCancelled) {
        activeCounter++;
        mapByDate[`${normalizedDateStr}_morning`] = activeCounter;
        mapBySeq[activeCounter] = new Date(y, m - 1, d, 0, 0, 0);
      }
      if (!meal.night?.isCancelled) {
        activeCounter++;
        mapByDate[`${normalizedDateStr}_night`] = activeCounter;
        mapBySeq[activeCounter] = new Date(y, m - 1, d, 23, 59, 59);
      }
    }

    // 1. Fetch all logged fines matching this hostel context
    const paymentHistory = await Fine.find({ hostelId })
      .populate("studentId", "name email photoURL regNum")
      .populate("MealPlanID", "name price")
      .sort({ date: -1 })
      .lean();

    // 2. Fetch active/pending subscriptions to evaluate inside the cache loop
    const activeSubscriptions = await StudentSubscription.find({
      hostelId,
      status: { $in: ["active", "pending"] }
    }).sort({ createdAt: -1 }).lean();

    // 3. Process records synchronously
    const processedData = paymentHistory.map((fineDoc) => {
      const studentId = fineDoc.studentId?._id || fineDoc.studentId;

      if (!studentId) {
        fineDoc.belongsToCurrentCycle = false;
        fineDoc.skipRecord = true; // Flag to filter out corrupted records
        return fineDoc;
      }

      const fineStatus = (fineDoc.status || "").toLowerCase();
      if (!['pending', 'processing', 'success'].includes(fineStatus)) {
        fineDoc.skipRecord = true;
        return fineDoc;
      }

      // Find the student's active subscription relative to this fine's timestamp
      const currentSubscription = activeSubscriptions.find(sub => 
        sub.studentId.toString() === studentId.toString() && 
        new Date(sub.createdAt) <= new Date(fineDoc.date)
      );

      // If no active subscription is found, it automatically belongs to a previous cycle
      if (!currentSubscription) {
        // 🛑 STIPULATION: If it's a previous cycle fine and it's already paid, drop it!
        if (fineStatus === 'success') {
          fineDoc.skipRecord = true;
          return fineDoc;
        }
        fineDoc.belongsToCurrentCycle = false;
        fineDoc.cycleDescription = "Previous Cycle Balance";
        return fineDoc;
      }

      // RULE CHECK A: Base Subscription Plan Initialization Fee
      if (fineDoc.isMealPackage) {
        const subInitTime = new Date(currentSubscription.createdAt).getTime();
        const billInitTime = new Date(fineDoc.date).getTime();

        if (Math.abs(billInitTime - subInitTime) < 10000) {
          fineDoc.belongsToCurrentCycle = true;
          fineDoc.cycleDescription = "Current Cycle Base Subscription Bill";
          return fineDoc;
        }
      }

      // RULE CHECK B: Operational Fines (Guest Meals / Extra Charges / Walk-ins)
      const desc = fineDoc.description || "";
      const dateMatch = desc.match(/(\d{2}\/\d{2}\/\d{4})/);
      const targetSlot = desc.toLowerCase().includes("morning") ? "morning" : "night";

      if (dateMatch) {
        const [fd, fm, fy] = dateMatch[1].split("/").map(Number);
        const normalizedFineDateStr = `${fd}/${fm}/${fy}`;
        const cacheKey = `${normalizedFineDateStr}_${targetSlot}`;

        const fineMealAbsIndex = mapByDate[cacheKey];

        if (fineMealAbsIndex) {
          const subCreatedAtDate = new Date(currentSubscription.createdAt);
          const subDateFormatted = `${subCreatedAtDate.getDate()}/${subCreatedAtDate.getMonth() + 1}/${subCreatedAtDate.getFullYear()}`;
          
          const cycleStartMealAbsIndex = mapByDate[`${subDateFormatted}_morning`] || fineMealAbsIndex;
          const cycleEndMealAbsIndex = cycleStartMealAbsIndex + 59;

          const cycleStartDate = mapBySeq[cycleStartMealAbsIndex];
          let cycleEndDate = mapBySeq[cycleEndMealAbsIndex];

          if (!cycleEndDate && cycleStartDate) {
            cycleEndDate = new Date(cycleStartDate.getTime());
            cycleEndDate.setDate(cycleEndDate.getDate() + 30);
          }

          if (cycleStartDate && cycleEndDate) {
            const fineTimestamp = new Date(fineDoc.date);

            // Check if the fine falls inside the current Meal 1-60 Cycle Duration
            if (fineTimestamp.getTime() >= cycleStartDate.getTime() && fineTimestamp.getTime() <= cycleEndDate.getTime()) {
              fineDoc.belongsToCurrentCycle = true;
              fineDoc.cycleDescription = "Current Mess Fine";
              return fineDoc;
            }
          }
        }
      }

      // 🛑 STIPULATION FALLBACK: If it falls outside the 1-60 current loop duration,
      // it is a previous cycle fine. If its status is 'success', drop it completely.
      if (fineStatus === 'success') {
        fineDoc.skipRecord = true;
        return fineDoc;
      }

      fineDoc.belongsToCurrentCycle = false;
      fineDoc.cycleDescription = "Previous Cycle Balance";
      return fineDoc;
    }).filter(fine => !fine.skipRecord); // ✨ REMOVES ALL PREVIOUS CYCLE SUCCESS FINES AT THE DB LAYER!

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