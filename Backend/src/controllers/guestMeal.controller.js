import GuestMeal from "../models/guestMeal.model.js";
import Fine from "../models/fine.model.js";
import Meal from "../models/Meal.js";
import Vote from "../models/Vote.js";
import MealPrice from "../models/FinePrice.js";



//  Student creates a guest meal request
export const requestGuestMeal = async (req, res) => {
  try {
    const { guestCount, mealDate, mealTime } = req.body;

    // 1. Check for pending fines
    const pendingFine = await Fine.findOne({
      studentId: req.user.id,
      status: 'pending'
    });

    if (pendingFine) {
      return res.status(403).json({
        success: false,
        message: "Request blocked. Please clear your pending fines first."
      });
    }

    // 2. Create the request
    const newRequest = await GuestMeal.create({
      studentId: req.user.id,
      hostelId: req.user.hostelId,
      guestCount,
      mealDate,
      mealTime
    });

    res.status(201).json({ success: true, data: newRequest });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};


//  Student fetches only their own guest meal requests
export const getMyGuestMealRequests = async (req, res) => {
  try {
    // We filter by req.user.id which comes from the 'protect' middleware
    const requests = await GuestMeal.find({ studentId: req.user.id })
      .sort({ createdAt: -1 }); // Show newest first

    res.status(200).json({
      success: true,
      count: requests.length,
      data: requests
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Failed to fetch your requests: " + error.message
    });
  }
};


//  Student cancels/rejects their own pending request
export const cancelGuestMealRequest = async (req, res) => {
  try {
    const requestId = req.params.id;

    // Find the request and ensure it belongs to the student
    const request = await GuestMeal.findOne({
      _id: requestId,
      studentId: req.user.id
    });

    if (!request) {
      return res.status(404).json({ success: false, message: "Request not found." });
    }

    // Only allow cancellation if it's still pending
    if (request.status !== 'pending') {
      return res.status(400).json({
        success: false,
        message: "Only pending requests can be cancelled."
      });
    }

    // Update status to rejected (or you could delete it using .deleteOne())
    request.status = 'rejected';
    await request.save();

    res.status(200).json({ success: true, message: "Request cancelled successfully." });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

//  Manager views all requests for their hostel
export const getHostelGuestRequests = async (req, res) => {
  try {
    const requests = await GuestMeal.find({ hostelId: req.user.hostelId })
      .populate('studentId', 'name roomNumber')
      .sort({ createdAt: -1 });

    res.status(200).json({ success: true, data: requests });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};


// Manager approves/rejects request
export const updateRequestStatus = async (req, res) => {
  try {
    const { status } = req.body;
    const requestId = req.params.id;

    console.log("updateRequestStatus:", status, requestId);

    const request = await GuestMeal.findByIdAndUpdate(
      requestId,
      { status },
      { new: true }
    ).populate("studentId");

    if (!request) {
      return res.status(404).json({ success: false, message: "Request not found" });
    }

    if (status === "approved") {
      const dateParts = request.mealDate.split('-');
      const formattedDateForMeal = `${dateParts[2]}/${dateParts[1]}/${dateParts[0]}`;

      const mealDoc = await Meal.findOne({
        hostelId: request.hostelId,
        date: formattedDateForMeal
      });

      if (!mealDoc) {
        return res.status(200).json({
          success: true,
          message: `Approved, but no routine for ${formattedDateForMeal}`,
          data: request
        });
      }

      const slot = request.mealTime.toLowerCase(); 
      const menuChoice = mealDoc[slot].manu; // Note: verify if this should be .menu instead of .manu in your schema

      // --- BILLING LOGIC ---
      const priceTable = await MealPrice.findOne({ hostelId: request.hostelId });
      
      let unitPrice = 0;
      if (priceTable && priceTable.prices) {
        // FIXED: Access standard nested object using bracket notation and lowercase key
        const safeMenuChoice = menuChoice ? menuChoice.toLowerCase() : "";
        unitPrice = priceTable.prices[safeMenuChoice] || 0;
      }

      const totalAmount = unitPrice * request.guestCount;

      if (!req.user || !req.user._id) {
        console.error("CRITICAL: req.user._id is missing. Fine cannot be created.");
      } else if (totalAmount > 0) {
        try {
          // Check if a fine already exists for this guest request to prevent double billing
          const existingFine = await Fine.findOne({ description: { $regex: requestId } });
          
          if (!existingFine) {
            const newFine = await Fine.create({
              studentId: request.studentId._id,
              managerId: req.user._id, 
              hostelId: request.hostelId,
              title: `Guest Meal - ${menuChoice.toUpperCase()}`,
              amount: totalAmount,
              description: `Guest Meal Bill [Ref:${requestId}]: ${request.guestCount} guests x ₹${unitPrice} (${menuChoice})`,
              status: "pending",
              date: new Date()
            });
            console.log("✅ Fine created successfully:", newFine._id);
          }
        } catch (fineError) {
          console.error("❌ Error creating Fine document:", fineError.message);
        }
      }

      // --- VOTING LOGIC ---
      
      // 1. Clear any previous votes for THIS specific request
      await Vote.deleteMany({ guestMealId: request._id });

      const guestVoteEntries = [];
      for (let i = 1; i <= request.guestCount; i++) {
        guestVoteEntries.push({
          userId: request.studentId._id,
          hostelId: request.hostelId,
          mealId: mealDoc._id,
          timeSlot: slot,
          mealType: menuChoice,
          isGuest: true,
          // Added request ID suffix to ensure guestName uniqueness in the index
          guestName: `Guest ${i} (${request.studentId.name}) - ${requestId.slice(-4)}`,
          guestMealId: request._id,
          votedAt: new Date(),
          isServed: false
        });
      }
      
      if (guestVoteEntries.length > 0) {
        try {
          // ordered: false prevents one duplicate from stopping the whole batch
          await Vote.insertMany(guestVoteEntries, { ordered: false });
          console.log(`✅ Created ${request.guestCount} individual guest votes.`);
        } catch (bulkError) {
          if (bulkError.code === 11000) {
            console.warn("⚠️ Duplicate guest votes detected and skipped.");
          } else {
            throw bulkError;
          }
        }
      }
    }

    if (status === "rejected") {
      // Cleanup votes if rejected
      await Vote.deleteMany({ guestMealId: request._id });
    }

    res.status(200).json({ success: true, data: request });

  } catch (error) {
    console.error("Error in updateRequestStatus:", error);
    res.status(500).json({ success: false, message: error.message });
  }
};



// export const updateRequestStatus = async (req, res) => {
//   try {
//     const { status } = req.body;
//     const requestId = req.params.id;

//     console.log("updateRequestStatus", requestId);

//     const request = await GuestMeal.findByIdAndUpdate(
//       requestId,
//       { status },
//       { new: true }
//     ).populate("studentId");

//     if (!request) {
//       return res.status(404).json({ success: false, message: "Request not found" });
//     }

//     if (status === "approved") {
//       // 1. Format date: "2026-03-14" -> "14/03/2026"
//       const dateParts = request.mealDate.split('-');
//       const formattedDateForMeal = `${dateParts[2]}/${dateParts[1]}/${dateParts[0]}`;

//       const mealDoc = await Meal.findOne({
//         hostelId: request.hostelId,
//         date: formattedDateForMeal
//       });

//       if (!mealDoc) {
//         return res.status(200).json({
//           success: true,
//           message: `Approved, but no routine for ${formattedDateForMeal}`,
//           data: request
//         });
//       }

//       const slot = request.mealTime.toLowerCase();
//       const menuChoice = mealDoc[slot].manu;

//       // 2. Clear any existing guest votes for this request (to prevent duplicates if re-approved)
//       await Vote.deleteMany({ guestMealId: request._id });

//       // 3. Create individual entries based on guestCount
//       const guestVoteEntries = [];
//       for (let i = 1; i <= request.guestCount; i++) {
//         guestVoteEntries.push({
//           userId: request.studentId._id,
//           hostelId: request.hostelId,
//           mealId: mealDoc._id,
//           timeSlot: slot,
//           mealType: menuChoice,
//           isGuest: true,
//           // We mark individual names like "Guest 1 (Nitya)", "Guest 2 (Nitya)"
//           guestName: `Guest ${i} (${request.studentId.name})`, 
//           guestMealId: request._id,
//           votedAt: new Date(),
//           isServed: false
//         });
//       }

//       // 4. Batch insert all guest votes into the collection
//       await Vote.insertMany(guestVoteEntries);
      
//       console.log(`Created ${request.guestCount} individual guest votes.`);
//     }

//     if (status === "rejected") {
//       // Remove all associated votes if rejected
//       await Vote.deleteMany({ guestMealId: request._id });
//     }

//     res.status(200).json({ success: true, data: request });
//   } catch (error) {
//     console.error("Error in updateRequestStatus:", error);
//     res.status(500).json({ success: false, message: error.message });
//   }
// };