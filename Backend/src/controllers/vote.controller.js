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

    // 2. Identify the active time slot block
    const slotBlock = meal[targetSlot] || { studentVotes: [], guestRequests: [] };
    const currentMenuItem = slotBlock.manu || "veg"; // Snapshot of the base meal type

    // 3. Fetch all approved hostellers to ensure walk-ins can be managed
    const allUsers = await User.find({ 
      hostelId: meal.hostelId, 
      pending: "approve" 
    }).select("_id name email photoURL").lean();

    const formattedData = [];

    // 4. Map Hostel Students (Both Voted and Unvoted Walk-ins)
    allUsers.forEach(user => {
      const userVote = (slotBlock.studentVotes || []).find(
        v => v.userId.toString() === user._id.toString()
      );

      formattedData.push({
        studentId: user._id,
        voteId: userVote ? userVote._id : "",
        studentName: user.name,
        studentEmail: user.email,
        studentPhoto: user.photoURL || "",
        mealDate: mealDate,
        timeSlot: targetSlot,
        menuItem: currentMenuItem, // ✨ CRITICAL: Feeds the base menu validation context straight to Flutter
        choice: userVote ? userVote.itemPreference : "", // Sends original choice token ('regular', 'halal_chicken', etc.)
        votedAt: userVote ? userVote.votedAt : null,
        isServed: userVote ? userVote.isServed : false,
        isGuest: false,
        hostName: null
      });
    });

    // 5. Process Approved Guest Reservation Requests
    const approvedGuests = (slotBlock.guestRequests || []).filter(g => g.status === "approved");

    if (approvedGuests.length > 0) {
      // Collect Host info cleanly
      const hostIds = approvedGuests.map(g => g.studentId);
      const hostsMap = await User.find({ _id: { $in: hostIds } }).select("_id name").lean();
      const hostProfiles = hostsMap.reduce((acc, h) => ({ ...acc, [h._id.toString()]: h.name }), {});

      approvedGuests.forEach(guestGroup => {
        const hostName = hostProfiles[guestGroup.studentId.toString()] || "Unknown Student Host";

        for (let index = 1; index <= guestGroup.guestCount; index++) {
          formattedData.push({
            studentId: guestGroup.studentId, // Links back to the host student record context block
            voteId: `${guestGroup._id}_${index}`, // Unique runtime virtual string identifier 
            studentName: `Guest ${index} (${hostName})`,
            studentEmail: "N/A",
            studentPhoto: "",
            mealDate: mealDate,
            timeSlot: targetSlot,
            menuItem: currentMenuItem, // ✨ Passes menu context down to the guest item card array
            choice: guestGroup.guestItemPreference || "regular", // ✨ FIX: Returns what type of plate option the guest voted
            votedAt: guestGroup.requestedAt,
            isServed: guestGroup.isServed || false, // ✨ FIX: Read true live service indicators inside the array database records
            isGuest: true,
            hostName: hostName
          });
        }
      });
    }

    return res.status(200).json({ 
      success: true, 
      count: formattedData.length, 
      data: formattedData 
    });

  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};


/**
 * @desc    Toggle attendance status flag values inside the embedded arrays directly
 * @route   PUT /api/meals/admin/toggle-serve
 */
export const toggleServeStatus = async (req, res) => {
  try {
    const { studentId, mealDate, timeSlot } = req.body;
    const currentHostelId = req.user.hostelId;
    const targetSlot = timeSlot.toLowerCase();

    if (!studentId || !mealDate || !timeSlot) {
      return res.status(400).json({ success: false, message: "Missing required query targeting fields." });
    }

    const meal = await Meal.findOne({ date: mealDate, hostelId: currentHostelId });
    if (!meal) return res.status(404).json({ success: false, message: "Meal document schedule entry matrix missing." });

    const slot = meal[targetSlot];
    let voteItem = slot.studentVotes.find(v => v.userId.toString() === studentId.toString());
    let currentMealType = slot.manu;

    if (!voteItem) {
      // 1. STUDENT HAS NOT VOTED (Walk-in scenario execution)
      const walkInVote = {
        userId: studentId,
        itemPreference: "regular",
        finalAllocatedMenu: slot.manu,
        isServed: true,
        servedAt: new Date(),
        votedAt: new Date()
      };

      slot.studentVotes.push(walkInVote);
      
      // ✅ FIX: Save immediately so Mongoose generates a valid `_id` for the subdocument
      await meal.save();
      
      // ✅ FIX: Find the newly created vote item directly from the array to read its auto-generated `_id`
      voteItem = slot.studentVotes.find(v => v.userId.toString() === studentId.toString());
    } else {
      // 2. Student has already voted -> Toggle existing service status state variables
      voteItem.isServed = !voteItem.isServed;
      voteItem.servedAt = voteItem.isServed ? new Date() : null;
      currentMealType = voteItem.finalAllocatedMenu;
      
      // Save updates for standard existing voters
      await meal.save();
    }

    const isNowServed = voteItem.isServed;

    // Check student subscription plan profiles
    const subscription = await StudentSubscription.findOne({
      studentId,
      status: { $in: ["active", "completed", "pending"] }
    }).sort({ createdAt: -1 });

    let isUnsubscribedGuest = !subscription;
    let fineGenerated = false;

    if (isNowServed) {
      const currentUsage = subscription ? (subscription.usage[currentMealType] || 0) : 0;
      const maxAllowed = subscription ? (subscription.maxLimits[currentMealType] || 0) : 0;

      if (isUnsubscribedGuest || currentUsage >= maxAllowed) {
        const priceList = await FinePrice.findOne({ hostelId: currentHostelId });
        const fineAmount = priceList ? (priceList.prices[currentMealType] || 50) : 50;
        const manager = await User.findOne({ hostelId: currentHostelId, role: "manager" });

        await Fine.create({
          studentId,
          managerId: manager ? manager._id : studentId,
          hostelId: currentHostelId,
          title: isUnsubscribedGuest 
            ? `Walk-in Meal Charge - ${currentMealType.toUpperCase()}` 
            : `Extra Meal Charge - ${currentMealType.toUpperCase()}`,
          amount: fineAmount,
          description: isUnsubscribedGuest
            ? `Student has no active subscription package. Billed single walk-in rate.`
            : `Limit for ${currentMealType} was ${maxAllowed}. Charged for exceeding baseline plan quotas.`,
          status: "pending",
          date: new Date()
        });
        fineGenerated = true;
      }
    } else {
      // Service undone: Delete fine statement records if pending
      await Fine.findOneAndDelete({
        studentId,
        hostelId: currentHostelId,
        status: "pending",
        title: { $regex: currentMealType, $options: "i" }
      });
    }

    // Update active plan balance indicators allocations
    let updatedSubscriptionId = null;
    if (!isUnsubscribedGuest && subscription) {
      const incValue = isNowServed ? 1 : -1;
      const updateKey = `usage.${currentMealType}`;

      // Prevent negative values when unserving
      if (!(!isNowServed && (subscription.usage[currentMealType] || 0) <= 0)) {
        const updatedSub = await StudentSubscription.findByIdAndUpdate(
          subscription._id,
          { $inc: { [updateKey]: incValue } },
          { new: true }
        );
        if (updatedSub) updatedSubscriptionId = updatedSub._id;
      }
    }

    if (updatedSubscriptionId) {
      await consumptionOverviewCheck(updatedSubscriptionId);
    }

    // 🚀 Returns a valid subdocument object _id back to Flutter seamlessly
    return res.json({
      success: true,
      message: isNowServed
        ? (isUnsubscribedGuest
          ? `Walk-in ${currentMealType} served. Bill generated!`
          : (fineGenerated ? `Extra ${currentMealType} served. Fine generated!` : `Marked ${currentMealType} as served`))
        : `Un-served ${currentMealType}. Usage balance parameters refunded safely.`,
      isServed: voteItem.isServed,
      mealType: currentMealType,
      voteId: voteItem._id // ✅ Guaranteed to be present now!
    });

  } catch (error) {
    console.error("Toggle Serve Error:", error);
    return res.status(500).json({ success: false, message: error.message });
  }
};
// --- SUBSCRIPTION EXHAUSTION SYSTEM PARSER HOOK ---
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