import Fine from "../models/fine.model.js";
import User from "../models/User.js";
import StudentSubscription from "../models/StudentSubscription.js";

// import { fineUploadFirebase } from "../utils/uploadHelper.js"; // Ensure your uploader is imported


import { fineUploadFirebase } from "../ConfigMultar/multar.control.js";

//  Manager creates a fine for a student
export const createFine = async (req, res) => {
  try {
    const { studentId, title, amount, description } = req.body;
    const fine = await Fine.create({
      studentId,
      managerId: req.user.id,
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











export const getPendingFines = async (req, res) => {
  try {
    const hostelId = req.user.hostelId;
    const month = req.query.month; // e.g., ?month=March 2026 or ?month=2026-03

    let query = { hostelId: hostelId };

    console.log("Received month query parameter:", month);

    if (month) {

      const startDate = new Date(month);

      if (isNaN(startDate.getTime())) {
        return res.status(400).json({
          success: false,
          message: "Invalid month format provided."
        });
      }

      const endDate = new Date(startDate);
      endDate.setMonth(endDate.getMonth() + 1);

      query.date = {
        $gte: startDate, // On or after the 1st of the target month
        $lt: endDate     // Strictly before the 1st of the next month
      };
    }

    // 3. Execute the query
    const pendingFines = await Fine.find(query)
      .populate("studentId", "name email photoURL")
      .sort({ date: -1 });

    res.status(200).json({
      success: true,
      count: pendingFines.length,
      data: pendingFines,
    });
  } catch (error) {
    console.error("Error in getPendingFines:", error);
    res.status(500).json({
      success: false,
      message: "Error fetching pending fines: " + error.message,
    });
  }
};


// Manager approves or rejects a fine/bill
export const updateFineStatus = async (req, res) => {
  try {
    const { id } = req.params; // Matches $billId from your Dart code
    const { status } = req.body; // 'success', 'rejected', 'processing', etc.

    // 1. Find and update the Fine document
    const updatedFine = await Fine.findByIdAndUpdate(
      id,
      { status: status },
      { new: true }
    );

    if (!updatedFine) {
      return res.status(404).json({ 
        success: false, 
        message: "Bill not found" 
      });
    }

    // 2. (Optional but Recommended) Update linked subscription status
    // If the manager rejects the payment, we should probably pause their meal plan
    if (updatedFine.isMealPackage && updatedFine.subscriptionId) {
      let subStatus = 'pending';
      if (status === 'success') subStatus = 'active';
      if (status === 'rejected') subStatus = 'pending'; // Revert to pending so they have to pay again

      await StudentSubscription.findByIdAndUpdate(
        updatedFine.subscriptionId,
        { status: subStatus }
      );
    }

    res.status(200).json({ 
      success: true, 
      message: `Bill marked as ${status}`,
      data: updatedFine 
    });

  } catch (error) {
    console.error("Error updating fine status:", error);
    res.status(500).json({ 
      success: false, 
      message: error.message 
    });
  }
};

