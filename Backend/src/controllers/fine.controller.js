import Fine from "../models/fine.model.js";
import User from "../models/User.js";
import StudentSubscription from "../models/StudentSubscription.js";
import MealPlan from "../models/MealPlan.js";
import FinePrice from "../models/FinePrice.js";
import moment from "moment";




// import { fineUploadFirebase } from "../utils/uploadHelper.js"; // Ensure your uploader is imported
import { fineUploadFirebase } from "../ConfigMultar/multar.control.js";




//  Manager creates a fine for a student
export const createFine = async (req, res) => {
  try {
    const { studentId, title, amount, description } = req.body;
    const fine = await Fine.create({
      studentId,
      hostelId: req.user.hostelId,
      title,
      amount,
      description
    });
    res.status(201).json({ success: true, data: fine });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

//  Student fetches their own fines
export const getMyFines = async (req, res) => {
  try {
    const fines = await Fine.find({ studentId: req.user.id }).sort({ date: -1 });
    res.status(200).json({ success: true, data: fines });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

//  Student uploads payment screenshot



export const payFine = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, message: "Screenshot required" });
    }

    // 1. Upload image to Firebase
    const imageUrl = await fineUploadFirebase(req.file);

    // 2. Find and update the Fine document
    const fine = await Fine.findByIdAndUpdate(
      req.params.id,
      {
        paymentScreenshot: imageUrl,
        status: 'processing'
      },
      { new: true }
    );

    if (!fine) {
      return res.status(404).json({ success: false, message: "Fine not found" });
    }

    // 3. NEW LOGIC: Check if this is a meal subscription payment
    if (fine.isMealPackage && fine.subscriptionId) {
      await StudentSubscription.findByIdAndUpdate(
        fine.subscriptionId,
        { status: 'active' } // Or 'processing' if you want to wait for manager approval
      );
    }

    res.status(200).json({
      success: true,
      message: "Payment proof submitted! Subscription is now active.",
      data: fine
    });

  } catch (error) {
    console.error("Pay Fine Error:", error);
    res.status(500).json({ success: false, message: error.message });
  }
};




/**
 * @desc    Fetch student fines filtered dynamically by meal cycle date range (DD/MM/YYYY)
 * @route   GET /api/fines/pending
 * @access  Private (Manager Only)
 */
export const getPendingFines = async (req, res) => {
  try {
    const hostelId = req.user.hostelId;
    if (!hostelId) {
      return res.status(403).json({ success: false, message: "Access denied. No hostel assigned." });
    }

    const { startDateStr, endDateStr } = req.query;
    let query = { hostelId: hostelId };

    console.log("Received meal cycle parameters: ", startDateStr, "to", endDateStr);

    //  Parse date parameters into standard MongoDB ISO Date formats
    if (startDateStr && startDateStr !== 'null' && endDateStr && endDateStr !== 'null') {
      const [startDay, startMonth, startYear] = startDateStr.split("/");
      const [endDay, endMonth, endYear] = endDateStr.split("/");

      const trueStartDate = new Date(`${startYear}-${startMonth}-${startDay}T00:00:00.000Z`);
      const trueEndDate = new Date(`${endYear}-${endMonth}-${endDay}T23:59:59.999Z`);

      if (isNaN(trueStartDate.getTime()) || isNaN(trueEndDate.getTime())) {
        return res.status(400).json({
          success: false,
          message: "Invalid start or end date format provided. Expected format: DD/MM/YYYY"
        });
      }

      query.date = {
        $gte: trueStartDate, // From midnight on the start date
        $lte: trueEndDate    // Until the end of the final day
      };
    }

    // Execute lookup with populated student records
    const pendingFines = await Fine.find(query)
      .populate("studentId", "name email photoURL")
      .sort({ date: -1 })
      .lean();

    return res.status(200).json({
      success: true,
      count: pendingFines.length,
      data: pendingFines,
    });

  } catch (error) {
    console.error("Error in getPendingFines controller:", error);
    return res.status(500).json({
      success: false,
      message: "Error fetching pending fines: " + error.message,
    });
  }
};

// Manager approves or rejects a fine/bill


export const updateFineStatus = async (req, res) => {
  try {
    const { id } = req.params;
    let { status, paymentMethod } = req.body;

    const activeManagerId = req.user?._id || req.user?.id;
    if (!activeManagerId) {
      return res.status(401).json({
        success: false,
        message: "Unauthorized. Session context missing."
      });
    }

    if (status === 'rejected') {
      status = 'reject';
    }

    const updatePayload = {
      status: status,
      managerId: activeManagerId
    };

    if (status === 'success') {
      if (paymentMethod === 'Online' || paymentMethod === 'Offline') {
        updatePayload.paymentMethod = paymentMethod;
      } else {
        updatePayload.paymentMethod = 'Offline';
      }
    } else if (status === 'reject') {
      // Clear method parameter if transaction is reversed/rejected
      updatePayload.paymentMethod = null;
    }

    const updatedFine = await Fine.findByIdAndUpdate(
      id,
      { $set: updatePayload },
      { new: true, runValidators: true }
    ).populate("managerId", "name");

    if (!updatedFine) {
      return res.status(404).json({
        success: false,
        message: "Bill record not found."
      });
    }

    if (updatedFine.isMealPackage && updatedFine.subscriptionId) {
      let subStatus = 'pending';

      if (status === 'success') {
        subStatus = 'active';
      } else if (status === 'reject') {
        subStatus = 'pending';
      }

      await StudentSubscription.findByIdAndUpdate(
        updatedFine.subscriptionId,
        { $set: { status: subStatus } }
      );
    }

    return res.status(200).json({
      success: true,
      message: `Bill record updated cleanly as ${status}`,
      data: updatedFine
    });

  } catch (error) {
    console.error("Fine status controller error:", error);
    return res.status(500).json({
      success: false,
      message: "Internal server error: " + error.message
    });
  }
};


export const updateFineStatusDelete = async (req, res) => {
  try {
    const { id } = req.params; // Matches fineId from your Dart code

    // 1. Find and delete the Fine document
    const deletedFine = await Fine.findByIdAndDelete(id);

    if (!deletedFine) {
      return res.status(404).json({
        success: false,
        message: "Bill not found or already deleted"
      });
    }

    // 2.  SMART SYNC LOGIC: Delete orphaned subscription
    // If this bill was for a meal plan, delete the pending meal plan too!
    // if (deletedFine.isMealPackage && deletedFine.subscriptionId) {
    //   await StudentSubscription.findByIdAndDelete(deletedFine.subscriptionId);
    // }

    // 3.  FIXED: Send the success response back to Flutter!
    res.status(200).json({
      success: true,
      message: "Bill deleted successfully."
    });

  } catch (error) {
    console.error("Error deleting fine:", error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
};



export const convertFineToSubscription = async (req, res) => {
  console.log("Convert Fine to Subscription called with params:", req.params, "and body:", req.body);
  try {
    const { id } = req.params; // Fine ID
    const { planId } = req.body;
    const hostelId = req.user.hostelId;

    // 1. Validate Fine & Plan
    const fine = await Fine.findOne({ _id: id, hostelId });
    if (!fine) return res.status(404).json({ success: false, message: "Fine not found" });

    const plan = await MealPlan.findOne({ _id: planId, hostelId });
    if (!plan) return res.status(404).json({ success: false, message: "Meal Plan not found" });

    const currentMonth = moment().format("MMMM YYYY");

    //  2. EXTRACT MEAL TYPE FROM FINE
    const combinedText = ((fine.title || "") + " " + (fine.description || "")).toLowerCase();
    let consumedType = null;
    const mealTypes = ["veg", "egg", "paneer", "chicken", "fish", "mutton"];

    for (const type of mealTypes) {
      if (combinedText.includes(type)) {
        consumedType = type;
        break;
      }
    }

    // 3. Check if student already has a subscription this month
    let subscription = await StudentSubscription.findOne({
      studentId: fine.studentId,
      status: { $in: ["pending", "active"] }
    });

    if (subscription) {
      // =========================================================
      // SCENARIO A: STUDENT ALREADY HAS A PLAN
      // =========================================================

      // 1. Add the consumed meal to their existing plan usage
      if (consumedType) {
        subscription.usage[consumedType] = (subscription.usage[consumedType] || 0) + 1;
        subscription.markModified("usage");
      }
      await subscription.save();

      // 2.  DELETE the fine entirely! They don't need a bill because their plan covers it.
      await Fine.findByIdAndDelete(fine._id);

      return res.status(200).json({
        success: true,
        message: `Added ${consumedType ? consumedType : 'meal'} to existing plan and deleted the extra fine.`
      });

    } else {
      // =========================================================
      // SCENARIO B: STUDENT DOES NOT HAVE A PLAN YET
      // =========================================================

      const initialUsage = { veg: 0, egg: 0, paneer: 0, chicken: 0, fish: 0, mutton: 0 };

      if (consumedType) {
        initialUsage[consumedType] = 1;
      }

      // 1. Create the new subscription
      subscription = await StudentSubscription.create({
        studentId: fine.studentId,
        hostelId: hostelId,
        mealsPlanId: plan._id,
        month: currentMonth,
        planType: plan.planType,
        amount: plan.monthlyPrice,
        maxLimits: plan.limits,
        status: fine.status === "success" ? "active" : "pending",
        usage: initialUsage
      });

      // 2. Transform the Fine into their new Subscription Receipt
      const oldTitle = fine.title;
      fine.isMealPackage = true;
      fine.MealPlanID = plan._id;
      fine.subscriptionId = subscription._id;
      fine.title = `Converted to Plan: ${plan.planType}`;
      fine.amount = plan.monthlyPrice;
      fine.description = `Converted by manager. Included 1 ${consumedType ? consumedType.toUpperCase() : 'Meal'}. Old fine was: ${oldTitle}`;

      await fine.save();

      return res.status(200).json({
        success: true,
        message: "Created new meal subscription and converted fine into receipt!"
      });
    }

  } catch (error) {
    console.error("Convert Fine Error:", error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// ==========================================
// CONVERT MEAL PACK TO INDIVIDUAL GUEST MEALS
// ==========================================
export const convertMealPackToGuestMeal = async (req, res) => {
  try {
    const { id } = req.params; // Original Fine ID
    const hostelId = req.user.hostelId;
    const managerId = req.user._id || req.user.id;

    // 1. Find the original Fine
    const originalFine = await Fine.findOne({ _id: id, hostelId });
    if (!originalFine) {
      return res.status(404).json({ success: false, message: "Bill not found" });
    }
    if (!originalFine.isMealPackage) {
      return res.status(400).json({ success: false, message: "This is already a regular bill." });
    }

    if (!originalFine.subscriptionId) {
      // Edge case: No subscription attached. Delete orphaned bill.
      await Fine.findByIdAndDelete(id);
      return res.status(200).json({
        success: true,
        message: "Package cancelled (no active subscription found)."
      });
    }

    // 2. Fetch Subscription and Prices
    const subscription = await StudentSubscription.findById(originalFine.subscriptionId);
    const priceList = await FinePrice.findOne({ hostelId });

    // Ensure fallback safety if DB price config is missing keys
    const defaultPrices = { veg: 35, egg: 45, paneer: 45, chicken: 65, fish: 55, mutton: 85 };
    const prices = priceList && priceList.prices ? { ...defaultPrices, ...priceList.prices } : defaultPrices;

    if (subscription && subscription.usage) {
      const u = subscription.usage;
      const mealTypes = ['veg', 'egg', 'paneer', 'chicken', 'fish', 'mutton'];

      // 3. Create INDIVIDUAL fines for each consumed meal type
      for (const type of mealTypes) {
        const count = Number(u[type]) || 0;
        if (count > 0) {
          const unitPrice = Number(prices[type]) || 0;
          const cost = count * unitPrice;
          const typeName = type.charAt(0).toUpperCase() + type.slice(1);

          await Fine.create({
            studentId: originalFine.studentId,
            managerId: managerId,
            hostelId: hostelId,
            title: `Guest Meal - ${count} ${typeName}`,
            amount: cost,
            description: `Converted from cancelled meal package. Consumed ${count} plates at ₹${unitPrice} each.`,
            isMealPackage: false,
            status: "pending"
          });
        }
      }

      // 4. Delete the subscription entirely
      await StudentSubscription.findByIdAndDelete(subscription._id);
    }

    // 5. Delete the original meal package fine
    await Fine.findByIdAndDelete(originalFine._id);

    return res.status(200).json({
      success: true,
      message: "Successfully converted to individual guest meal bills!"
    });

  } catch (error) {
    console.error("Convert to Guest Meal Error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
};