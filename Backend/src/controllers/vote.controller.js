import mongoose from 'mongoose';
import moment from "moment";
import Meal from "../models/Meal.js";
import StudentSubscription from "../models/StudentSubscription.js";
import Fine from '../models/fine.model.js'; // Standardized capital model names
import FinePrice from "../models/FinePrice.js";
import User from "../models/User.js";
import WeeklyRoutine from "../models/WeeklyRoutine.js";
import Notification from "../models/Notification.js";

/**
 * @desc    Cast a personal student meal vote into the embedded array of a Meal document
 * @route   POST /api/meals/vote
 */
export const voteMeal = async (req, res) => {
  try {
    const { mealId, timeSlot, mealType } = req.body; // mealType: 'regular' | 'halal_chicken' | 'egg_substitute' | 'veg_forced'
    const studentId = req.user.id || req.user._id;

    const meal = await Meal.findById(mealId);
    if (!meal) return res.status(404).json({ message: "Meal plan not found" });

    const slotData = meal[timeSlot];
    if (!slotData) return res.status(400).json({ message: "Invalid time slot" });

    if (slotData.isCancelled) {
      return res.status(400).json({ message: `${timeSlot} meal has been cancelled` });
    }

    if (new Date() > slotData.lockTime || slotData.isLocked) {
      return res.status(403).json({ message: `Voting for ${timeSlot} is now closed` });
    }

    // Check unique constraint manually: Has this student already voted in this slot?
    const existingVoteIndex = slotData.studentVotes.findIndex(
      v => v.userId.toString() === studentId.toString()
    );

    const baseMenu = slotData.manu;
    let calculatedMenuAllocation = baseMenu;

    // Evaluate dynamic preference allocations
    if (mealType === "halal_chicken") {
      if (baseMenu !== "chicken") {
        return res.status(400).json({ message: "Halal Chicken variation is restricted unless core option is chicken." });
      }
      calculatedMenuAllocation = "halal_chicken";
    } else if (mealType === "egg_substitute") {
      if (baseMenu === "veg") {
        return res.status(400).json({ message: "Cannot swap out a pure vegetarian plate menu layout tier for egg variants." });
      }
      calculatedMenuAllocation = "egg";
    } else if (mealType === "veg_forced") {
      calculatedMenuAllocation = "veg";
    }

    if (existingVoteIndex !== -1) {
      // Update existing vote in array
      slotData.studentVotes[existingVoteIndex].itemPreference = mealType || "regular";
      slotData.studentVotes[existingVoteIndex].finalAllocatedMenu = calculatedMenuAllocation;
      slotData.studentVotes[existingVoteIndex].votedAt = new Date();
    } else {
      // Append a brand new embedded vote
      slotData.studentVotes.push({
        userId: studentId,
        itemPreference: mealType || "regular",
        finalAllocatedMenu: calculatedMenuAllocation,
        votedAt: new Date(),
        isServed: false
      });
    }

    await meal.save();

    return res.status(200).json({
      success: true,
      message: "Vote recorded successfully",
      meal
    });

  } catch (error) {
    console.error("Vote Error:", error);
    return res.status(500).json({ message: "Server error during voting: " + error.message });
  }
};

/**
 * @desc    Pull/Delete a student's personal vote from the embedded array
 * @route   POST /api/meals/cancel-vote
 */
export const cancelVote = async (req, res) => {
  try {
    const { mealId, timeSlot } = req.body;
    const studentId = req.user.id || req.user._id;

    const meal = await Meal.findById(mealId);
    if (!meal) return res.status(404).json({ success: false, message: "Meal document not found." });

    if (meal[timeSlot].isLocked || new Date() > meal[timeSlot].lockTime) {
      return res.status(403).json({ success: false, message: "Cannot cancel. Voting is locked." });
    }

    // Atomically pull the matching vote sub-document out of the embedded list array
    await Meal.findByIdAndUpdate(mealId, {
      $pull: {
        [`${timeSlot}.studentVotes`]: { userId: studentId }
      }
    });

    return res.json({ success: true, message: "Vote removed successfully" });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * @desc    Check a specific student's vote/served status for a single day's slots
 * @route   GET /api/meals/check-status/:mealId
 */
export const checkVoteStatus = async (req, res) => {
  try {
    const { mealId } = req.params;
    const studentId = req.user.id || req.user._id;

    const meal = await Meal.findById(mealId).lean();
    if (!meal) return res.status(404).json({ success: false, message: "Meal not found" });

    const morningVote = (meal.morning.studentVotes || []).find(v => v.userId.toString() === studentId.toString());
    const nightVote = (meal.night.studentVotes || []).find(v => v.userId.toString() === studentId.toString());

    const status = {
      morning: !!morningVote,
      morningServed: morningVote ? morningVote.isServed : false,
      morningChoice: morningVote ? morningVote.finalAllocatedMenu : "",
      night: !!nightVote,
      nightServed: nightVote ? nightVote.isServed : false,
      nightChoice: nightVote ? nightVote.finalAllocatedMenu : ""
    };

    return res.json({ success: true, status });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * @desc    Get complete structured history list records across unified daily meals arrays
 * @route   GET /api/meals/history
 */
export const getVoteHistory = async (req, res) => {
  try {
    const studentId = req.user.id || req.user._id;
    const hostelId = req.user.hostelId;
    const { month, year } = req.query;

    let matchStage = { hostelId: new mongoose.Types.ObjectId(hostelId) };

    if (month && year) {
      const formattedMonth = month.padStart(2, '0');
      const datePattern = new RegExp(`/${formattedMonth}/${year}$`);
      matchStage.date = { $regex: datePattern };
    }

    const rawMeals = await Meal.find(matchStage).lean();
    const historyList = [];

    for (const meal of rawMeals) {
      // Process Morning
      const morningVote = (meal.morning.studentVotes || []).find(v => v.userId.toString() === studentId.toString());
      const morningApprovedGuests = (meal.morning.guestRequests || []).filter(g => g.studentId.toString() === studentId.toString() && g.status === "approved");
      const morningGuestPlatesCount = morningApprovedGuests.reduce((sum, g) => sum + g.guestCount, 0);

      historyList.push({
        _id: meal._id,
        date: meal.date,
        timeSlot: "morning",
        menuItem: morningVote ? morningVote.finalAllocatedMenu : meal.morning.manu,
        isCancelled: meal.morning.isCancelled,
        voted: !!morningVote,
        isServed: morningVote ? morningVote.isServed : false,
        votedAt: morningVote ? morningVote.votedAt : null,
        hasGuest: morningGuestPlatesCount > 0,
        guestCount: morningGuestPlatesCount
      });

      // Process Night
      const nightVote = (meal.night.studentVotes || []).find(v => v.userId.toString() === studentId.toString());
      const nightApprovedGuests = (meal.night.guestRequests || []).filter(g => g.studentId.toString() === studentId.toString() && g.status === "approved");
      const nightGuestPlatesCount = nightApprovedGuests.reduce((sum, g) => sum + g.guestCount, 0);

      historyList.push({
        _id: meal._id,
        date: meal.date,
        timeSlot: "night",
        menuItem: nightVote ? nightVote.finalAllocatedMenu : meal.night.manu,
        isCancelled: meal.night.isCancelled,
        voted: !!nightVote,
        isServed: nightVote ? nightVote.isServed : false,
        votedAt: nightVote ? nightVote.votedAt : null,
        hasGuest: nightApprovedGuests.length > 0,
        guestCount: nightGuestPlatesCount
      });
    }

    // Sort by descending calendar dates natively
    historyList.sort((a, b) => {
      const splitA = a.date.split('/');
      const splitB = b.date.split('/');
      return new Date(splitB[2], splitB[1] - 1, splitB[0]) - new Date(splitA[2], splitA[1] - 1, splitA[0]);
    });

    return res.status(200).json({ success: true, history: historyList });
  } catch (error) {
    return res.status(500).json({ success: false, message: "History aggregation failure: " + error.message });
  }
};

/**
 * @desc    Verify if a user has cast votes across a collection profile block array of days
 * @route   POST /api/meals/check-weekly-votes
 */
export const checkUserVotesForWeek = async (req, res) => {
  try {
    const studentId = req.user.id || req.user._id;
    const { mealIds } = req.body;

    const targetMeals = await Meal.find({ _id: { $in: mealIds } }).lean();
    const formattedVotesOutput = [];

    targetMeals.forEach(meal => {
      const mVote = (meal.morning.studentVotes || []).find(v => v.userId.toString() === studentId.toString());
      if (mVote) {
        formattedVotesOutput.push({ mealId: meal._id, timeSlot: "morning", isServed: mVote.isServed });
      }

      const nVote = (meal.night.studentVotes || []).find(v => v.userId.toString() === studentId.toString());
      if (nVote) {
        formattedVotesOutput.push({ mealId: meal._id, timeSlot: "night", isServed: nVote.isServed });
      }
    });

    return res.json({ success: true, userVotes: formattedVotesOutput });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * @desc    Get master admin dashboard attendance logs map grid list sheets
 * @route   GET /api/meals/admin/get-votes
 */

export const getVotesByDateAndSlot = async (req, res) => {
  try {
    const { mealDate, timeSlot } = req.query;

    if (!mealDate || !timeSlot) {
      return res.status(400).json({ success: false, message: "Date and Slot parameters are required" });
    }

    const targetSlot = timeSlot.toLowerCase();

    // 1. Fetch the master day layout configuration document
    const meal = await Meal.findOne({ date: mealDate }).lean();
    if (!meal) {
      return res.status(404).json({ success: false, message: "No meal routine configured for this calendar date." });
    }

    const slotBlock = meal[targetSlot] || { studentVotes: [], guestRequests: [] };
    const currentMenuItem = slotBlock.manu || "veg";
    
    //  EXTRACT MEAL NUMBER: Grab the tracking sequence number for this slot (fallback to "0")
    const dynamicMealNum = slotBlock.mealsNum || "0";

    // 2. Fetch both "approve" and "active" student users
    const allUsers = await User.find({
      hostelId: meal.hostelId,
      status: { $in: ["approve", "active"] }
    }).select("_id name email photoURL").lean();

    const formattedData = [];

    // 3. Map Hostel Students (Both Voted and Unvoted Walk-ins)
    allUsers.forEach(user => {
      const userVote = (slotBlock.studentVotes || []).find(
        v => v.userId && v.userId.toString() === user._id.toString()
      );

      formattedData.push({
        studentId: user._id,
        voteId: userVote ? userVote._id : "",
        studentName: user.name,
        studentEmail: user.email,
        studentPhoto: user.photoURL || "",
        mealDate: mealDate,
        timeSlot: targetSlot,
        mealsNum: dynamicMealNum, // 🌟 Added absolute tracking meal number string here
        menuItem: currentMenuItem, 
        choice: userVote ? userVote.itemPreference : "", 
        votedAt: userVote ? userVote.votedAt : null,
        isServed: userVote ? userVote.isServed : false,
        isGuest: false,
        hostName: null
      });
    });

    // 4. Process Approved Guest Reservation Requests
    const approvedGuests = (slotBlock.guestRequests || []).filter(g => g.status === "approved");

    if (approvedGuests.length > 0) {
      const hostIds = approvedGuests.map(g => g.studentId);
      const hostsMap = await User.find({ _id: { $in: hostIds } }).select("_id name").lean();
      const hostProfiles = hostsMap.reduce((acc, h) => ({ ...acc, [h._id.toString()]: h.name }), {});

      approvedGuests.forEach(guestGroup => {
        const hostName = hostProfiles[guestGroup.studentId.toString()] || "Unknown Student Host";

        for (let index = 1; index <= guestGroup.guestCount; index++) {
          const guestVoteMarkerId = `${guestGroup._id}_${index}`;
          const isThisGuestServed = (slotBlock.studentVotes || []).some(
            v => v.finalAllocatedMenu === guestVoteMarkerId && v.isServed === true
          );

          formattedData.push({
            studentId: guestGroup.studentId, 
            voteId: guestVoteMarkerId, 
            studentName: `Guest ${index} (${hostName})`,
            studentEmail: "N/A",
            studentPhoto: "",
            mealDate: mealDate,
            timeSlot: targetSlot,
            mealsNum: dynamicMealNum, // 🌟 Added absolute tracking meal number string here
            menuItem: currentMenuItem, 
            choice: guestGroup.guestItemPreference || "regular", 
            votedAt: guestGroup.requestedAt,
            isServed: isThisGuestServed,
            isGuest: true,
            hostName: hostName
          });
        }
      });
    }

    return res.status(200).json({
      success: true,
      count: formattedData.length,
      mealsNum: dynamicMealNum, // 🌟 Also available at top-level envelope for easy parsing
      data: formattedData
    });

  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};
/**
 * @desc    Toggle serve execution statuses, compute package balances or fine parameters natively
 * @route   PUT /api/meals/serve-toggle
 */
// export const toggleServeStatus = async (req, res) => {
//   try {
//     const { studentId, mealDate, timeSlot } = req.body;
//     const currentHostelId = req.user.hostelId;
//     const targetSlot = timeSlot.toLowerCase();

//     if (!studentId || !mealDate || !timeSlot) {
//       return res.status(400).json({ success: false, message: "Missing required query targeting fields." });
//     }

//     const meal = await Meal.findOne({ date: mealDate, hostelId: currentHostelId });
//     if (!meal) return res.status(404).json({ success: false, message: "Meal document schedule entry matrix missing." });

//     const slot = meal[targetSlot];
//     let voteItem = slot.studentVotes.find(v => v.userId.toString() === studentId.toString());
//     let currentMealType = slot.manu;

//     if (!voteItem) {
//       // 1. STUDENT HAS NOT VOTED (Walk-in scenario execution)
//       const walkInVote = {
//         userId: studentId,
//         itemPreference: "regular",
//         finalAllocatedMenu: slot.manu, // Baseline routine type (e.g. 'veg', 'chicken', 'fish')
//         isServed: true,
//         servedAt: new Date(),
//         votedAt: new Date()
//       };

//       slot.studentVotes.push(walkInVote);

//       // Save immediately so Mongoose generates a valid `_id` for the subdocument
//       await meal.save();

//       // Find the newly created vote item directly from the array to read its auto-generated `_id`
//       voteItem = slot.studentVotes.find(v => v.userId.toString() === studentId.toString());
//     } else {
//       // 2. Student has already voted -> Toggle existing service status state variables
//       voteItem.isServed = !voteItem.isServed;
//       voteItem.servedAt = voteItem.isServed ? new Date() : null;
//       currentMealType = voteItem.finalAllocatedMenu;

//       await meal.save();
//     }

//     const isNowServed = voteItem.isServed;

//     //  CRITICAL TRANSLATION FIX: Map menu variations cleanly to match your StudentSubscription Schema attributes
//     let subscriptionKey = currentMealType.toLowerCase();
//     if (subscriptionKey === "halal_chicken") {
//       subscriptionKey = "chicken"; // Deducts from core chicken allotment quota bounds
//     } else if (subscriptionKey === "egg_substitute") {
//       subscriptionKey = "egg";
//     } else if (subscriptionKey === "veg_forced") {
//       subscriptionKey = "veg";
//     }

//     // Check student subscription plan profiles
//     const subscription = await StudentSubscription.findOne({
//       studentId,
//       hostelId: currentHostelId,
//       status: { $in: ["active", "completed", "pending"] }
//     }).sort({ createdAt: -1 });

//     let isUnsubscribedGuest = !subscription;
//     let fineGenerated = false;

//     if (isNowServed) {
//       // Use our safe subscriptionKey parameter map rather than unmapped meal strings
//       const currentUsage = subscription ? (subscription.usage[subscriptionKey] || 0) : 0;
//       const maxAllowed = subscription ? (subscription.maxLimits[subscriptionKey] || 0) : 0;

//       if (isUnsubscribedGuest || currentUsage >= maxAllowed) {
//         const priceList = await FinePrice.findOne({ hostelId: currentHostelId });

//         // Lookup correct mapping key or fall back gracefully
//         const fineAmount = priceList ? (priceList.prices[subscriptionKey] || 50) : 50;
//         const manager = await User.findOne({ hostelId: currentHostelId, role: "manager" });

//         await Fine.create({
//           studentId,
//           managerId: manager ? manager._id : studentId,
//           hostelId: currentHostelId,
//           title: isUnsubscribedGuest 
//             ? `Walk-in Meal Charge - ${subscriptionKey.toUpperCase()}` 
//             : `Extra Meal Charge - ${subscriptionKey.toUpperCase()}`,
//           amount: fineAmount,
//           description: isUnsubscribedGuest
//             ? `Student has no active subscription package. Billed single walk-in rate.`
//             : `Limit for ${subscriptionKey} was ${maxAllowed}. Charged for exceeding baseline plan quotas.`,
//           status: "pending",
//           date: new Date()
//         });
//         fineGenerated = true;
//       }
//     } else {
//       // Service undone: Delete fine statement records if pending (uses subscriptionKey verification query check)
//       await Fine.findOneAndDelete({
//         studentId,
//         hostelId: currentHostelId,
//         status: "pending",
//         title: { $regex: new RegExp(subscriptionKey, "i") }
//       });
//     }

//     // Update active plan balance indicators allocations
//     let updatedSubscriptionId = null;
//     if (!isUnsubscribedGuest && subscription) {
//       const incValue = isNowServed ? 1 : -1;
//       const updateKey = `usage.${subscriptionKey}`; // Deducts safely using subscription standard parameters

//       // Prevent negative values when unserving
//       if (!( !isNowServed && (subscription.usage[subscriptionKey] || 0) <= 0 )) {
//         const updatedSub = await StudentSubscription.findByIdAndUpdate(
//           subscription._id,
//           { $inc: { [updateKey]: incValue } },
//           { new: true }
//         );
//         if (updatedSub) updatedSubscriptionId = updatedSub._id;
//       }
//     }

//     // Trigger standard lifecycle checks if external completion pipelines are declared
//     if (updatedSubscriptionId && typeof consumptionOverviewCheck === 'function') {
//       await consumptionOverviewCheck(updatedSubscriptionId);
//     }

//     // Returns a valid subdocument object _id back to Flutter seamlessly
//     return res.json({
//       success: true,
//       message: isNowServed
//         ? (isUnsubscribedGuest
//           ? `Walk-in ${subscriptionKey.toUpperCase()} served. Bill generated!`
//           : (fineGenerated ? `Extra ${subscriptionKey.toUpperCase()} served. Fine generated!` : `Marked ${subscriptionKey.toUpperCase()} as served`))
//         : `Un-served ${subscriptionKey.toUpperCase()}. Usage balance parameters refunded safely.`,
//       isServed: voteItem.isServed,
//       mealType: currentMealType,
//       voteId: voteItem._id
//     });

//   } catch (error) {
//     console.error("Toggle Serve Error:", error);
//     return res.status(500).json({ success: false, message: error.message });
//   }
// };

/**
 * @desc    Toggle service status, enforce fast 60-day expiration, and instantly fine if subscription is completed
 * @route   POST /api/manager/toggle-serve
 */

// export const toggleServeStatus = async (req, res) => {
//   try {
//     const { studentId, mealDate, timeSlot } = req.body;
//     const currentHostelId = req.user.hostelId;
//     const targetSlot = timeSlot.toLowerCase();
    
    

//     // Resolve manager ID safely
//     const rawManagerId = req.user._id || req.user.id; 
//     if (!rawManagerId) {
//       return res.status(401).json({ success: false, message: "Unauthorized. Manager session context missing." });
//     }
//     const activeManagerId = new mongoose.Types.ObjectId(rawManagerId);

//     if (!studentId || !mealDate || !timeSlot) {
//       return res.status(400).json({ success: false, message: "Missing required query targeting fields." });
//     }

//     // 1. Fetch current meal plan document state
//     const mealDocCheck = await Meal.findOne({ date: mealDate, hostelId: currentHostelId }).lean();
//     if (!mealDocCheck) return res.status(404).json({ success: false, message: "Meal document schedule entry matrix missing." });

//     const slotBlock = mealDocCheck[targetSlot];
//     const existingVote = (slotBlock.studentVotes || []).find(v => v.userId.toString() === studentId.toString());
    
//     let isNowServed = false;
//     let currentMealType = slotBlock.manu;
//     let voteId = "";

//     if (!existingVote) {
//       // ➔ WALK-IN MODE
//       const newWalkIn = {
//         userId: new mongoose.Types.ObjectId(studentId),
//         itemPreference: "regular",
//         finalAllocatedMenu: slotBlock.manu, 
//         isServed: true,
//         servedBy: activeManagerId, // 🌟 Safe explicit injection
//         servedAt: new Date(),
//         votedAt: new Date()
//       };

//       const updatedMeal = await Meal.findOneAndUpdate(
//         { date: mealDate, hostelId: currentHostelId },
//         { $push: { [`${targetSlot}.studentVotes`]: newWalkIn } },
//         { new: true }
//       );
      
//       const freshlyCreatedVote = updatedMeal[targetSlot].studentVotes.find(v => v.userId.toString() === studentId.toString());
//       isNowServed = true;
//       voteId = freshlyCreatedVote ? freshlyCreatedVote._id : "";
//     } else {
//       // ➔ REGISTERED VOTE MODE
//       isNowServed = !existingVote.isServed;
//       currentMealType = existingVote.finalAllocatedMenu;
//       voteId = existingVote._id;

//       // 🌟 FIX: Use studentVotes.userId instead of studentVotes._id to ensure the query hits perfectly
//       await Meal.updateOne(
//         { 
//           date: mealDate, 
//           hostelId: currentHostelId, 
//           [`${targetSlot}.studentVotes.userId`]: new mongoose.Types.ObjectId(studentId) 
//         },
//         { 
//           $set: { 
//             [`${targetSlot}.studentVotes.$.isServed`]: isNowServed,
//             [`${targetSlot}.studentVotes.$.servedBy`]: isNowServed ? activeManagerId : null, 
//             [`${targetSlot}.studentVotes.$.servedAt`]: isNowServed ? new Date() : null 
//           } 
//         }
//       );
//     }

//     // 2. Normalize menu fields to match your dynamic FinePrice keys
//     let subscriptionKey = currentMealType.toLowerCase();
//     if (subscriptionKey.includes("chicken")) subscriptionKey = "chicken";
//     else if (subscriptionKey.includes("egg")) subscriptionKey = "egg";
//     else if (subscriptionKey !== "paneer" && subscriptionKey !== "fish" && subscriptionKey !== "mutton") {
//       subscriptionKey = "veg";
//     }

//     // 3. Parallel Database Index Fetching Optimization
//     const [priceDoc, subscription] = await Promise.all([
//       FinePrice.findOne({ hostelId: currentHostelId }).lean(),
//       StudentSubscription.findOne({
//         studentId,
//         hostelId: currentHostelId,
//         status: { $in: ["pending", "active", "completed"] }
//       }).sort({ createdAt: -1 })
//     ]);

//     const defaultFallbacks = { veg: 35, egg: 45, paneer: 45, chicken: 65, fish: 55, mutton: 85 };
//     const finalBilledAmount = priceDoc?.prices?.[subscriptionKey] || defaultFallbacks[subscriptionKey];

//     let forceFineBilling = false;
//     let fineReasonDescription = "";

//     if (subscription) {
//       const purchaseDate = new Date(subscription.createdAt);
//       const differenceInDays = (Date.now() - purchaseDate.getTime()) / (1000 * 3600 * 24);

//       if (differenceInDays > 60) {
//         if (subscription.status !== "completed") {
//           await StudentSubscription.updateOne({ _id: subscription._id }, { $set: { status: "completed" } });
//         }
//         forceFineBilling = true;
//         fineReasonDescription = "Student subscription package has exceeded its 60-day validity window and is expired.";
//       }

//       if (subscription.status === "completed") {
//         forceFineBilling = true;
//         if (!fineReasonDescription) {
//           fineReasonDescription = "Student has an already completed/exhausted subscription package layout.";
//         }
//       }
//     } else {
//       forceFineBilling = true;
//       fineReasonDescription = "Student has no subscription history context found.";
//     }

//     let fineGenerated = false;

//     if (isNowServed) {
//       const currentUsage = subscription?.usage?.[subscriptionKey] || 0;
//       const maxAllowed = subscription?.maxLimits?.[subscriptionKey] || 0;

//       if (forceFineBilling || currentUsage >= maxAllowed) {
//         await Fine.create({
//           studentId,
//           managerId: activeManagerId, 
//           hostelId: currentHostelId,
//           title: forceFineBilling 
//             ? `Walk-in Charge (Expired/Completed) - ${subscriptionKey.toUpperCase()}` 
//             : `Extra Meal Charge - ${subscriptionKey.toUpperCase()}`,
//           amount: finalBilledAmount,
//           description: forceFineBilling ? fineReasonDescription : `Limit for ${subscriptionKey} was ${maxAllowed}. Charged for exceeding plan quota bounds.`,
//           status: "pending",
//           isMealPackage: false,
//           date: new Date()
//         });
//         fineGenerated = true;
//       }
//     } else {
//       await Fine.findOneAndDelete({
//         studentId,
//         hostelId: currentHostelId,
//         status: "pending",
//         title: { $regex: new RegExp(subscriptionKey, "i") }
//       });
//     }

//     // 5. Update Active Token Quota Counts cleanly
//     if (!forceFineBilling && subscription && (subscription.status === "active" || subscription.status === "pending")) {
//       const incValue = isNowServed ? 1 : -1;
      
//       if (!( !isNowServed && (subscription.usage[subscriptionKey] || 0) <= 0 )) {
//         const updatedSub = await StudentSubscription.findByIdAndUpdate(
//           subscription._id,
//           { $inc: { [`usage.${subscriptionKey}`]: incValue } },
//           { new: true }
//         );

//         if (updatedSub) {
//           const totalUsedNow = ["veg", "chicken", "fish", "egg", "paneer", "mutton"]
//             .reduce((sum, key) => sum + (updatedSub.usage[key] || 0), 0);

//           if (totalUsedNow >= updatedSub.totalMealsBought) {
//             await StudentSubscription.updateOne({ _id: subscription._id }, { $set: { status: "completed" } });
//           }
//         }
//       }
//     } else if (!isNowServed && subscription && forceFineBilling && subscription.status === "completed") {
//       const totalUsedNow = ["veg", "chicken", "fish", "egg", "paneer", "mutton"]
//         .reduce((sum, key) => sum + (subscription.usage[key] || 0), 0);

//       const purchaseDate = new Date(subscription.createdAt);
//       const differenceInDays = (Date.now() - purchaseDate.getTime()) / (1000 * 3600 * 24);

//       if (totalUsedNow < subscription.totalMealsBought && differenceInDays <= 60) {
//         await StudentSubscription.updateOne({ _id: subscription._id }, { $set: { status: "active" } });
//       }
//     }

//     return res.status(200).json({
//       success: true,
//       message: isNowServed
//         ? (forceFineBilling
//           ? `Billed as Extra: Pack status is Expired/Completed. Invoice of ₹${finalBilledAmount} generated!`
//           : (fineGenerated ? `Extra ${subscriptionKey.toUpperCase()} served. Fine of ₹${finalBilledAmount} generated!` : `Marked ${subscriptionKey.toUpperCase()} as served`))
//         : `Un-served ${subscriptionKey.toUpperCase()}. System records synchronized cleanly.`,
//       isServed: isNowServed,
//       mealType: currentMealType,
//       voteId: voteId
//     });

//   } catch (error) {
//     console.error("Critical Toggle Serve Flow Failure:", error);
//     return res.status(500).json({ success: false, message: "Internal Server Error: " + error.message });
//   }
// };

const consumptionOverviewCheck = async (subscriptionId) => {
  try {
    const sub = await StudentSubscription.findById(subscriptionId);
    if (!sub) return;

    const isCompleted =
      sub.usage.veg >= sub.maxLimits.veg &&
      sub.usage.egg >= sub.maxLimits.egg &&
      sub.usage.paneer >= sub.maxLimits.paneer &&
      sub.usage.chicken >= sub.maxLimits.chicken &&
      sub.usage.fish >= sub.maxLimits.fish &&
      sub.usage.mutton >= sub.maxLimits.mutton;

    if (isCompleted && sub.status !== "completed") {
      sub.status = "completed";
      await sub.save();
    } else if (!isCompleted && sub.status === "completed") {
      sub.status = "active";
      await sub.save();
    }
  } catch (error) {
    console.error("Consumption Check Error:", error);
  }
};