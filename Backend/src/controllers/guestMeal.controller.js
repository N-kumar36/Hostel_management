import mongoose from "mongoose";
import Fine from '../models/fine.model.js';
import Meal from "../models/Meal.js";
import MealPrice from "../models/FinePrice.js";
import User from "../models/User.js"; // Included to resolve missing user instance query definitions

/**
 * @desc    Student creates a guest meal request directly inside a daily meal slot array
 * @route   POST /api/guest-meals/request
 */
export const requestGuestMeal = async (req, res) => {
  try {
    const { guestCount, mealDate, mealTime, guestItemPreference } = req.body;

    const studentId = req.user.id || req.user._id;
    const hostelId = req.user.hostelId;

    if (!guestCount || !mealDate || !mealTime) {
      return res.status(400).json({ success: false, message: "Missing required booking inputs" });
    }

    // 1. Check for blocking pending fines
    const pendingFine = await Fine.findOne({
      studentId,
      status: 'pending'
    });

    if (pendingFine) {
      return res.status(403).json({
        success: false,
        message: "Request blocked. Please clear your pending fines first."
      });
    }

    // 2. Normalize date string parsing layout gracefully
    let formattedDateForMeal = mealDate;
    if (mealDate.includes('-')) {
      const dateParts = mealDate.split('-');
      formattedDateForMeal = `${dateParts[2]}/${dateParts[1]}/${dateParts[0]}`;
    }

    const slot = mealTime.toLowerCase(); // 'morning' or 'night'

    const mealDoc = await Meal.findOne({ hostelId, date: formattedDateForMeal });
    if (!mealDoc) {
      return res.status(404).json({ success: false, message: `Hostel mess has not configured a meal schedule for ${formattedDateForMeal}.` });
    }

    // Check cutoff lock time constraints logic guards
    if (mealDoc[slot].isLocked || new Date() > new Date(mealDoc[slot].lockTime)) {
      return res.status(400).json({ success: false, message: "Bookings have closed for this slot window line." });
    }

    // 3. Create the embedded sub-document block object structure
    const newRequest = {
      _id: new mongoose.Types.ObjectId(),
      studentId,
      guestCount: parseInt(guestCount),
      guestItemPreference: guestItemPreference || "regular",
      status: "pending",
      requestedAt: new Date()
    };

    mealDoc[slot].guestRequests.push(newRequest);
    await mealDoc.save();

    return res.status(201).json({
      success: true,
      message: "Guest meal requested successfully!",
      data: newRequest
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * @desc    Student fetches only their own guest meal requests across all records
 * @route   GET /api/guest-meals/my-requests
 */
export const getMyGuestMealRequests = async (req, res) => {
  try {
    const studentId = req.user.id || req.user._id;
    const hostelId = req.user.hostelId;

    const rawMeals = await Meal.find({ hostelId }).lean();
    const studentRequests = [];

    for (const meal of rawMeals) {
      ['morning', 'night'].forEach(slotKey => {
        const slot = meal[slotKey];
        if (slot && slot.guestRequests) {
          slot.guestRequests.forEach(reqItem => {
            if (reqItem.studentId.toString() === studentId.toString()) {
              studentRequests.push({
                _id: reqItem._id,
                mealId: meal._id,
                studentId: reqItem.studentId,
                guestCount: reqItem.guestCount,
                guestItemPreference: reqItem.guestItemPreference,
                status: reqItem.status,
                requestedAt: reqItem.requestedAt,
                mealDate: meal.date,
                mealTime: slotKey,
                menuItem: slot.manu
              });
            }
          });
        }
      });
    }

    studentRequests.sort((a, b) => new Date(b.requestedAt) - new Date(a.requestedAt));

    return res.status(200).json({
      success: true,
      count: studentRequests.length,
      data: studentRequests
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: "Failed to fetch your requests: " + error.message });
  }
};

/**
 * @desc    Student cancels/rejects their own pending request directly in the sub-array
 * @route   PUT /api/guest-meals/cancel
 */
export const cancelGuestMealRequest = async (req, res) => {
  try {
    const { mealId, timeSlot, requestId } = req.body;
    const studentId = req.user.id || req.user._id;
    const slot = timeSlot.toLowerCase();

    const mealDoc = await Meal.findById(mealId);
    if (!mealDoc) return res.status(404).json({ success: false, message: "Meal schedule not found." });

    const requestItem = mealDoc[slot].guestRequests.id(requestId);
    if (!requestItem) return res.status(404).json({ success: false, message: "Request item not found inside this slot." });

    if (requestItem.studentId.toString() !== studentId.toString()) {
      return res.status(403).json({ success: false, message: "Unauthorized operation access rejected." });
    }

    if (requestItem.status !== 'pending') {
      return res.status(400).json({ success: false, message: "Only pending requests can be cancelled." });
    }

    requestItem.status = 'rejected';
    await mealDoc.save();

    return res.status(200).json({ success: true, message: "Request cancelled successfully." });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * @desc    Manager views all requests for their hostel bounds
 * @route   GET /api/guest-meals/manager/all
 */
export const getHostelGuestRequests = async (req, res) => {
  try {
    const hostelId = req.user.hostelId;

    // Process flat query find string patterns safely
    const rawMeals = await Meal.find({ hostelId })
      .populate({ path: 'morning.guestRequests.studentId', select: 'name roomNumber email' })
      .populate({ path: 'night.guestRequests.studentId', select: 'name roomNumber email' })
      .lean();

    const allRequests = [];

    for (const meal of rawMeals) {
      ['morning', 'night'].forEach(slotKey => {
        const slot = meal[slotKey];
        if (slot && slot.guestRequests) {
          slot.guestRequests.forEach(reqItem => {
            allRequests.push({
              _id: reqItem._id,
              mealId: meal._id,
              studentId: reqItem.studentId,
              guestCount: reqItem.guestCount,
              guestItemPreference: reqItem.guestItemPreference,
              status: reqItem.status,
              requestedAt: reqItem.requestedAt,
              mealDate: meal.date,
              mealTime: slotKey,
              menuItem: slot.manu
            });
          });
        }
      });
    }

    allRequests.sort((a, b) => new Date(b.requestedAt) - new Date(a.requestedAt));
    return res.status(200).json({ success: true, data: allRequests });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * @desc    Manager approves/rejects an embedded request status flag, computing automated billing logs
 * @route   PUT /api/guest-meals/manager/update
 */
export const updateRequestStatus = async (req, res) => {
  try {
    const { mealId, requestId, status } = req.body;

    const rawTimeSlot = req.body.timeSlot || req.body.timeSloat || req.body.mealTime;

    if (!mealId || !rawTimeSlot || !requestId || !status) {
      return res.status(400).json({
        success: false,
        message: "Missing required tracking parameters: mealId, timeSlot, requestId, and status are required."
      });
    }

    const slot = rawTimeSlot.toLowerCase(); 

    const mealDoc = await Meal.findById(mealId);
    if (!mealDoc) return res.status(404).json({ success: false, message: "Master daily meal document not found" });

    if (!mealDoc[slot] || !mealDoc[slot].guestRequests) {
      return res.status(400).json({ success: false, message: `Invalid or unconfigured time slot: ${slot}` });
    }

    const request = mealDoc[slot].guestRequests.id(requestId);
    if (!request) return res.status(404).json({ success: false, message: "Target embedded request record not found" });

    request.status = status;

    if (status === "approved") {
      request.approvedAt = new Date();

      const preference = request.guestItemPreference || "regular";
      const baseMenu = (mealDoc[slot].manu || "veg").toLowerCase();
      let billingItemKey = baseMenu; 

      if (preference === "halal_chicken" && baseMenu === "chicken") {
        billingItemKey = "chicken";
      } else if (preference === "egg_substitute") {
        billingItemKey = "egg";
      } else if (preference === "veg_forced") {
        billingItemKey = "veg";
      }

      // --- ACCOUNTING LEDGER AUTO-BILLING LOGIC ---
      const priceTable = await MealPrice.findOne({ hostelId: mealDoc.hostelId });
      let unitPrice = 0;

      if (priceTable && priceTable.prices) {
        const safeMenuChoice = billingItemKey.toLowerCase();
        unitPrice = priceTable.prices[safeMenuChoice] || 0;
      }

      const totalAmount = unitPrice * request.guestCount;

      if (totalAmount > 0) {
        const existingFine = await Fine.findOne({ description: { $regex: requestId } });

        if (!existingFine) {
          const finalStudentIdRef = (request.studentId && typeof request.studentId === 'object' && request.studentId._id)
              ? request.studentId._id
              : request.studentId;

          const managerIdRef = req.user._id || req.user.id;

          await Fine.create({
            studentId: finalStudentIdRef,
            managerId: managerIdRef,
            hostelId: mealDoc.hostelId,
            title: `Guest Meal - ${billingItemKey.toUpperCase()}`,
            amount: totalAmount,
            description: `Guest Meal Bill [Ref:${requestId}]: ${request.guestCount} guests x ₹${unitPrice} (${billingItemKey})`,
            status: "pending",
            date: new Date()
          });
          console.log("✅ Guest fine invoice generated successfully.");
        }
      }
    }

    await mealDoc.save();

    // ✨ CRITICAL FIX: Re-populate the student documents field reference path before responding back to Flutter!
    const populatedMealDoc = await Meal.findById(mealId)
      .populate({ path: `${slot}.guestRequests.studentId`, select: 'name roomNumber email' });
    
    const freshlyPopulatedRequest = populatedMealDoc[slot].guestRequests.id(requestId);

    return res.status(200).json({
      success: true,
      message: `Request marked as ${status} successfully.`,
      data: {
        ...freshlyPopulatedRequest.toObject(),
        mealId: mealDoc._id,
        mealTime: slot,
        mealDate: mealDoc.date,
        menuItem: mealDoc[slot].manu
      }
    });

  } catch (error) {
    console.error("Error in updateRequestStatus:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
};