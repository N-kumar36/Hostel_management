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








export const generateBulkFines = async (req, res) => {
  try {
    const { month } = req.body; // e.g., "March 2026"
    const managerId = req.user._id;
    const hostelId = req.user.hostelId;

    console.log("generateBulkFines", month);

    // 1. Fetch only the Base Fee from the Price Table
    const priceTable = await MealPrice.findOne({ hostelId });
    if (!priceTable) {
      return res.status(404).json({
        success: false,
        message: "Base Fee not set. Please configure the Price Table first."
      });
    }

    const baseFee = priceTable.baseFee;

    // 2. Get all students in this manager's hostel
    const students = await User.find({ hostelId, role: 'student' });

    if (students.length === 0) {
      return res.status(404).json({ success: false, message: "No students found." });
    }

    // 3. Create a fixed bill for every student (Ignoring Votes)
    const batchOperations = students.map(async (student) => {
      return await Fine.findOneAndUpdate(
        {
          studentId: student._id,
          title: `Mess Fee - ${month}`
        },
        {
          studentId: student._id,
          managerId: managerId,
          hostelId: hostelId,
          title: `Mess Fee - ${month}`,
          amount: baseFee, // Fixed amount
          description: `Fixed Monthly Mess Base Fee for ${month}`,
          status: 'pending',
          date: new Date()
        },
        { upsert: true, new: true }
      );
    });

    await Promise.all(batchOperations);

    res.status(200).json({
      success: true,
      message: `Successfully sent ₹${baseFee} payment request to ${students.length} students.`,
    });

  } catch (error) {
    console.error("Bulk Fine Error:", error);
    res.status(500).json({ success: false, message: error.message });
  }
};


export const verifyFinePayment = async (req, res) => {
  try {
    const fineId = req.params.id;

    // 1. Update the Fine status to success
    const updatedFine = await Fine.findByIdAndUpdate(
      fineId,
      {
        status: 'success',
        paidAt: new Date(),
        verifiedBy: req.user._id || req.user.id // Track which manager verified it
      },
      { new: true }
    );

    if (!updatedFine) {
      return res.status(404).json({ success: false, message: "Fine record not found" });
    }

    // 2. CRITICAL FIX: If this fine was for a Meal Package, activate the subscription
    if (updatedFine.isMealPackage && updatedFine.subscriptionId) {
      await StudentSubscription.findByIdAndUpdate(
        updatedFine.subscriptionId,
        {
          status: 'active' // Plan is now ready for QR scanning and usage
        }
      );

      console.log(`Subscription ${updatedFine.subscriptionId} activated for student.`);
    }

    res.status(200).json({
      success: true,
      message: updatedFine.isMealPackage
        ? "Payment verified and Meal Plan activated!"
        : "Fine payment verified successfully",
      data: updatedFine
    });

  } catch (error) {
    console.error("Verify Payment Error:", error);
    res.status(500).json({ success: false, message: error.message });
  }
};



export const getPendingFines = async (req, res) => {
  try {
    // 1. Get hostelId from the manager's token
    const hostelId = req.user.hostelId;

    // 2. Find fines using the correct field names from your schema
    const pendingFines = await Fine.find({
      hostelId: hostelId,
      status: "processing", // Ensure this matches your enum
    })
      .populate("studentId", "name email photoURL") //  Fixed: model uses 'studentId', not 'userId'
      .sort({ date: -1 }); // Sorting by your 'date' field

    res.status(200).json({
      success: true,
      count: pendingFines.length,
      data: pendingFines, // 'paymentScreenshot' will be inside these objects
    });
  } catch (error) {
    console.error("Error in getPendingFines:", error);
    res.status(500).json({
      success: false,
      message: "Error fetching pending fines: " + error.message,
    });
  }
};

