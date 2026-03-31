import mongoose from "mongoose";
import moment from "moment";
import Vote from "../models/Vote.js";
import Meal from "../models/Meal.js";
import StudentSubscription from "../models/StudentSubscription.js";
import Fine from "../models/fine.model.js";
import FinePrice from "../models/FinePrice.js";
import User from "../models/User.js";
import WeeklyRoutine from "../models/WeeklyRoutine.js";







export const voteMeal = async (req, res) => {
  try {
    const { mealId, timeSlot, mealType } = req.body;
    console.log("mealId", mealId)

    // 1. Find the meal document
    const meal = await Meal.findById(mealId);
    if (!meal) return res.status(404).json({ message: "Meal plan not found" });

    // 2. Identify the specific slot data (morning or night)
    const slotData = meal[timeSlot];
    if (!slotData) return res.status(400).json({ message: "Invalid time slot" });

    // --- NEW VERIFICATION LOGIC ---
    // 3. Verify that the requested mealType matches the menu set by the manager
    if (slotData.manu !== mealType) {
      return res.status(400).json({
        message: `Invalid meal selection. The menu for ${timeSlot} is ${slotData.manu}, not ${mealType}.`
      });
    }

    // 4. Logic Check: Is the specific slot cancelled?
    if (slotData.isCancelled) {
      return res.status(400).json({ message: `${timeSlot} meal has been cancelled` });
    }

    // 5. Logic Check: Is the specific slot past its lockTime?
    if (new Date() > slotData.lockTime || slotData.isLocked) {
      return res.status(403).json({ message: `Voting for ${timeSlot} is now closed` });
    }

    // 6. Create or Update the vote
    const vote = await Vote.findOneAndUpdate(
      { userId: req.user.id, mealId, timeSlot },
      {
        hostelId: req.user.hostelId,
        mealType, // Now we are 100% sure this matches the menu
        votedAt: new Date()
      },
      { upsert: true, new: true }
    );

    res.status(200).json({
      success: true,
      message: "Vote recorded successfully",
      vote
    });

  } catch (error) {
    if (error.code === 11000) {
      return res.status(400).json({ message: "You have already voted for this meal" });
    }
    console.error("Vote Error:", error);
    res.status(500).json({ message: "Server error during voting" });
  }
};

export const cancelVote = async (req, res) => {
  try {
    const { mealId, timeSlot } = req.body;

    console.log("cancel api was call ", mealId)

    // Verify the meal isn't locked yet
    const meal = await Meal.findById(mealId);
    if (meal[timeSlot].isLocked || new Date() > meal[timeSlot].lockTime) {
      return res.status(403).json({ success: false, message: "Cannot cancel. Voting is locked." });
    }

    await Vote.findOneAndDelete({
      userId: req.user.id,
      mealId: mealId,
      timeSlot: timeSlot
    });

    res.json({ success: true, message: "Vote removed successfully" });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// Controller: check-vote-status
export const checkVoteStatus = async (req, res) => {
  try {
    const { mealId } = req.params;
    const userId = req.user.id;

    // Find all votes by this user for this specific meal
    const votes = await Vote.find({ userId, mealId });

    //  Extract both 'voted' and 'isServed' status for each slot
    const morningVote = votes.find(v => v.timeSlot === 'morning');
    const nightVote = votes.find(v => v.timeSlot === 'night');

    const status = {
      // Slot: Morning
      morning: !!morningVote,
      morningServed: morningVote ? morningVote.isServed : false,

      // Slot: Night
      night: !!nightVote,
      nightServed: nightVote ? nightVote.isServed : false
    };

    res.json({ success: true, status });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};


// get history
export const getVoteHistory = async (req, res) => {
  try {
    const studentId = req.user.id;
    const hostelId = req.user.hostelId;

    const month = req.query.month;
    const year = req.query.year;

    let matchStage = {
      hostelId: new mongoose.Types.ObjectId(hostelId)
    };

    if (month && year) {
      const formattedMonth = month.padStart(2, '0');
      const datePattern = new RegExp(`/${formattedMonth}/${year}$`);
      matchStage.date = { $regex: datePattern };
    }

    const history = await Meal.aggregate([
      { $match: matchStage },

      {
        $project: {
          date: 1,
          slots: [
            {
              timeSlot: "morning",
              menuItem: "$morning.manu",
              isCancelled: "$morning.isCancelled"
            },
            {
              timeSlot: "night",
              menuItem: "$night.manu",
              isCancelled: "$night.isCancelled"
            }
          ]
        }
      },

      { $unwind: "$slots" },

      {
        $lookup: {
          from: "votes",
          let: { meal_id: "$_id", slot_name: "$slots.timeSlot" },
          pipeline: [
            {
              $match: {
                $expr: {
                  $and: [
                    { $eq: ["$mealId", "$$meal_id"] },
                    { $eq: ["$timeSlot", "$$slot_name"] },
                    { $eq: ["$userId", new mongoose.Types.ObjectId(studentId)] }
                  ]
                }
              }
            }
          ],
          as: "voteData"
        }
      },

      // Stage 5: Fixed Projection for Guests
      {
        $project: {
          _id: 1,
          date: 1,
          timeSlot: "$slots.timeSlot",
          menuItem: "$slots.menuItem",
          isCancelled: "$slots.isCancelled",

          //  FIX 1: Returns TRUE if ANY vote in the array has isGuest: true
          hasGuest: {
            $in: [true, { $ifNull: ["$voteData.isGuest", []] }]
          },

          //  FIX 2: Accurately counts HOW MANY guest votes exist for this meal
          guestCount: {
            $size: {
              $filter: {
                input: { $ifNull: ["$voteData", []] },
                as: "v",
                cond: { $eq: ["$$v.isGuest", true] }
              }
            }
          },

          voted: { $gt: [{ $size: "$voteData" }, 0] },
          isServed: { $ifNull: [{ $arrayElemAt: ["$voteData.isServed", 0] }, false] },
          votedAt: { $arrayElemAt: ["$voteData.votedAt", 0] }
        }
      },

      { $sort: { date: -1, timeSlot: 1 } }
    ]);

    res.status(200).json({
      success: true,
      history: history
    });

  } catch (error) {
    console.error("History Error:", error);
    res.status(500).json({
      success: false,
      message: "Server Error: " + error.message
    });
  }
};



// Controller: checkUserVotesForWeek
export const checkUserVotesForWeek = async (req, res) => {
  try {
    const userId = req.user.id; // From auth middleware
    const { mealIds } = req.body; // Array of meal IDs from the frontend

    const userVotes = await Vote.find({
      userId: userId,
      mealId: { $in: mealIds }
    }).select('mealId timeSlot isServed');
    console.log("userVotes", userVotes);

    res.json({ success: true, userVotes });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};




export const getVotesByDateAndSlot = async (req, res) => {
  try {
    const { mealDate, timeSlot } = req.query;

    if (!mealDate || !timeSlot) {
      return res.status(400).json({ success: false, message: "Date and Slot are required" });
    }

    // 1. Find the Meal document (Needed for mealId and hostelId)
    // NOTE: If your app has multiple hostels, make sure you query by hostelId here too!
    const meal = await Meal.findOne({ date: mealDate });
    if (!meal) {
      return res.status(404).json({ success: false, message: "No meal routine found for this date" });
    }

    // 2. Fetch ALL approved users (students) belonging to this hostel
    const allUsers = await User.find({
      hostelId: meal.hostelId,
      pending: "approve" // Only get active, approved users
    }).select("_id name email photoURL");

    // 3. Fetch all votes (Students + Guests) for this specific meal and slot
    const votes = await Vote.find({
      mealId: meal._id,
      timeSlot: timeSlot.toLowerCase()
    }).populate("userId", "name email photoURL");

    // 4. Separate regular votes and guest votes for easier mapping
    const regularVotesMap = {};
    const guestVotesList = [];

    votes.forEach(vote => {
      if (vote.isGuest) {
        guestVotesList.push(vote);
      } else {
        // Create a dictionary keyed by userId for quick lookup
        if (vote.userId) {
          regularVotesMap[vote.userId._id.toString()] = vote;
        }
      }
    });

    // 5. Build the final merged array
    const formattedData = [];

    // Map through ALL users to see if they voted
    allUsers.forEach(user => {
      const userIdStr = user._id.toString();
      const userVote = regularVotesMap[userIdStr]; // Check if they have a vote

      formattedData.push({
        studentId: user._id, // Crucial for the Flutter fallback
        voteId: userVote ? userVote._id : null, // Will be null if they haven't voted
        studentName: user.name,
        studentEmail: user.email,
        studentPhoto: user.photoURL || "",
        mealDate: mealDate,
        timeSlot: timeSlot.toLowerCase(),
        choice: userVote ? userVote.mealType : "", // Empty means NOT VOTED
        votedAt: userVote ? userVote.votedAt : null,
        isServed: userVote ? userVote.isServed : false,
        isGuest: false,
        hostName: null
      });
    });

    // Append the guest votes to the bottom of the list
    guestVotesList.forEach(guestVote => {
      formattedData.push({
        studentId: guestVote._id, // Fallback ID
        voteId: guestVote._id,
        studentName: guestVote.guestName || "Unknown Guest",
        studentEmail: guestVote.userId?.email || "N/A",
        studentPhoto: "",
        mealDate: mealDate,
        timeSlot: timeSlot.toLowerCase(),
        choice: guestVote.mealType,
        votedAt: guestVote.votedAt,
        isServed: guestVote.isServed,
        isGuest: true,
        hostName: guestVote.userId?.name || "Unknown Host"
      });
    });

    // 6. Send the merged response
    res.json({
      success: true,
      count: formattedData.length,
      data: formattedData
    });
  } catch (error) {
    console.error("Fetch Votes Error:", error);
    res.status(500).json({ success: false, message: error.message });
  }
};




// Controller: toggleServeStatus
// export const toggleServeStatus = async (req, res) => {
//   try {
//     const { voteId } = req.body;

//     // 1. Find Vote and Meal data
//     const vote = await Vote.findById(voteId).populate("mealId");
//     if (!vote) return res.status(404).json({ success: false, message: "Vote not found" });

//     const mealDate = moment(vote.mealId.date, "DD/MM/YYYY");
//     const subscriptionMonth = mealDate.format("MMMM YYYY");
//     const mealType = vote.mealType.toLowerCase();

//     // 2. Find Subscription
//     const subscription = await StudentSubscription.findOne({
//       studentId: vote.userId,
//       month: subscriptionMonth,
//       status: "active"
//     });

//     if (!subscription && !vote.isGuest) {
//       return res.status(400).json({ success: false, message: "No active plan for this month" });
//     }

//     const isNowServed = !vote.isServed;

//     // --- AUTO FINE LOGIC ---
//     if (isNowServed && !vote.isGuest) {
//       const currentUsage = subscription.usage[mealType] || 0;
//       const maxAllowed = subscription.maxLimits[mealType] || 0;

//       // Check if this meal is EXTRA
//       if (currentUsage >= maxAllowed) {
//         // Fetch specific fine prices for this hostel
//         const priceList = await FinePrice.findOne({ hostelId: vote.hostelId });
//         const fineAmount = priceList ? priceList.prices[mealType] : 50; // Fallback to 50 if no price set

//         // Find manager ID to assign the fine
//         const manager = await User.findOne({ hostelId: vote.hostelId, role: "manager" });

//         // Create the Automatic Fine
//         await Fine.create({
//           studentId: vote.userId,
//           managerId: manager ? manager._id : vote.userId, // Fallback safety
//           hostelId: vote.hostelId,
//           title: `Extra Meal Charge - ${vote.mealType.toUpperCase()}`,
//           amount: fineAmount,
//           description: `Automatically generated: Limit for ${mealType} was ${maxAllowed}. Student is consuming an extra plate.`,
//           status: "pending",
//           date: new Date()
//         });
//       }
//     }

//     // 3. Update Subscription Usage
//     if (!vote.isGuest && subscription) {
//       const incValue = isNowServed ? 1 : -1;
//       const updateKey = `usage.${mealType}`;

//       if (!isNowServed && subscription.usage[mealType] <= 0) {
//         // Safety: Don't decrement below 0
//       } else {
//         await StudentSubscription.findByIdAndUpdate(subscription._id, {
//           $inc: { [updateKey]: incValue }
//         });
//       }
//     }

//     // 4. Update Vote Status
//     vote.isServed = isNowServed;
//     vote.servedAt = isNowServed ? new Date() : null;
//     await vote.save();

//     res.json({
//       success: true,
//       message: vote.isServed
//         ? (subscription.usage[mealType] >= subscription.maxLimits[mealType]
//           ? `Extra ${vote.mealType} served. Fine generated!`
//           : `Marked ${vote.mealType} as served`)
//         : "Service undone",
//       isServed: vote.isServed
//     });

//   } catch (error) {
//     console.error("Toggle Serve Error:", error);
//     res.status(500).json({ success: false, message: error.message });
//   }
// };


export const toggleServeStatus = async (req, res) => {
  try {
    const { voteId, studentId, mealDate, timeSlot } = req.body;

    let vote = null;
    let isNewVote = false;
    let mealIdToUse = null;

    console.log("voteId", voteId, "studentId", studentId, "mealDate", mealDate, "timeSlot", timeSlot);

    // 1. Try to find the existing vote
    if (voteId) {
      vote = await Vote.findById(voteId).populate("mealId");
    }

    let isNowServed;
    let currentMealType;
    let currentUserId;
    let currentHostelId;
    let currentMealDateObj;

    // 2. If no vote exists, we are serving a "Walk-in" (Unvoted Student)
    if (!vote) {
      if (!studentId || !mealDate || !timeSlot) {
        return res.status(400).json({ success: false, message: "Missing required fields to serve unvoted student." });
      }

      const user = await User.findById(studentId);
      if (!user) return res.status(404).json({ success: false, message: "Student not found" });

      currentHostelId = user.hostelId;
      currentUserId = user._id;

      const meal = await Meal.findOne({ date: mealDate, hostelId: currentHostelId });
      if (!meal) return res.status(404).json({ success: false, message: "Meal not found for this date" });
      mealIdToUse = meal._id;

      // Determine Meal Type from Weekly Routine using NUMBER keys (1-7)
      currentMealDateObj = moment(mealDate, "DD/MM/YYYY");
      const dayOfWeekNumString = currentMealDateObj.isoWeekday().toString();

      console.log("Mapped Day of Week Key:", dayOfWeekNumString);

      const weeklyRoutine = await WeeklyRoutine.findOne({ hostelId: currentHostelId });

      // Check if the routine exists and has the numerical key
      if (!weeklyRoutine || !weeklyRoutine.routine.has(dayOfWeekNumString)) {
        return res.status(404).json({ success: false, message: "Weekly routine not found to determine meal type" });
      }

      // Grab the specific meal type (veg, egg, etc.) for this exact day and time slot
      const dayMeals = weeklyRoutine.routine.get(dayOfWeekNumString);
      currentMealType = dayMeals[timeSlot.toLowerCase()];

      if (!currentMealType) {
        return res.status(400).json({ success: false, message: "Meal type not defined in routine for this slot" });
      }

      isNewVote = true;
      isNowServed = true; // Serving an unvoted student implies we are turning the switch ON
    } else {
      // It's an existing vote, extract variables normally
      currentMealType = vote.mealType.toLowerCase();
      currentUserId = vote.userId;
      currentHostelId = vote.hostelId;
      currentMealDateObj = moment(vote.mealId.date, "DD/MM/YYYY");
      isNowServed = !vote.isServed; // Toggle it
    }

    // 3. Find Subscription (Allow both active and completed) - REMOVED MONTH LOGIC
    const subscription = await StudentSubscription.findOne({
      studentId: currentUserId,
      status: { $in: ["active", "completed"] }
    }).sort({ createdAt: -1 });

    if (!subscription && (!vote || !vote.isGuest)) {
      return res.status(400).json({ success: false, message: "No active plan found for this student" });
    }

    // --- AUTO FINE LOGIC ---
    let fineGenerated = false;
    if (isNowServed && (!vote || !vote.isGuest)) {
      const currentUsage = subscription.usage[currentMealType] || 0;
      const maxAllowed = subscription.maxLimits[currentMealType] || 0;

      // Check if this meal is EXTRA
      if (currentUsage >= maxAllowed) {
        const priceList = await FinePrice.findOne({ hostelId: currentHostelId });
        const fineAmount = priceList ? priceList.prices[currentMealType] : 50;

        const manager = await User.findOne({ hostelId: currentHostelId, role: "manager" });

        await Fine.create({
          studentId: currentUserId,
          managerId: manager ? manager._id : currentUserId,
          hostelId: currentHostelId,
          title: `Extra Meal Charge - ${currentMealType.toUpperCase()}`,
          amount: fineAmount,
          description: `Automatically generated: Limit for ${currentMealType} was ${maxAllowed}. Student is consuming an extra plate.`,
          status: "pending",
          date: new Date()
        });

        fineGenerated = true;
      }
    }

    // 4. Update Subscription Usage
    let updatedSubscriptionId = null;

    if ((!vote || !vote.isGuest) && subscription) {
      const incValue = isNowServed ? 1 : -1;
      const updateKey = `usage.${currentMealType}`;

      if (!(!isNowServed && subscription.usage[currentMealType] <= 0)) {
        const updatedSub = await StudentSubscription.findByIdAndUpdate(
          subscription._id,
          { $inc: { [updateKey]: incValue } },
          { new: true }
        );
        updatedSubscriptionId = updatedSub._id;
      }
    }

    // 5. Create OR Update the Vote
    if (isNewVote) {
      vote = new Vote({
        userId: currentUserId,
        hostelId: currentHostelId,
        mealId: mealIdToUse,
        timeSlot: timeSlot.toLowerCase(),
        mealType: currentMealType,
        isGuest: false,
        isServed: true,
        servedAt: new Date(),
        votedAt: new Date() // Treat the walk-in time as their voted time
      });
      await vote.save();
    } else {
      vote.isServed = isNowServed;
      vote.servedAt = isNowServed ? new Date() : null;
      await vote.save();
    }

    // 6. Run the auto-completion check!
    if (updatedSubscriptionId) {
      // Ensure consumptionOverviewCheck is imported and available in this scope
      if (typeof consumptionOverviewCheck === 'function') {
        await consumptionOverviewCheck(updatedSubscriptionId);
      } else {
        console.warn("consumptionOverviewCheck function is missing or not imported.");
      }
    }

    res.json({
      success: true,
      message: isNowServed
        ? (fineGenerated
          ? `Extra ${currentMealType} served. Fine generated!`
          : `Marked ${currentMealType} as served`)
        : "Service undone",
      isServed: vote.isServed,
      mealType: currentMealType 
    });

  } catch (error) {
    console.error("Toggle Serve Error:", error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// --- HELPER FUNCTION ---
const consumptionOverviewCheck = async (subscriptionId) => {
  try {
    const sub = await StudentSubscription.findById(subscriptionId);
    if (!sub) return;

    // Check if EVERY category's usage has reached or exceeded its max limit
    const isCompleted =
      sub.usage.veg >= sub.maxLimits.veg &&
      sub.usage.egg >= sub.maxLimits.egg &&
      sub.usage.paneer >= sub.maxLimits.paneer &&
      sub.usage.chicken >= sub.maxLimits.chicken &&
      sub.usage.fish >= sub.maxLimits.fish &&
      sub.usage.mutton >= sub.maxLimits.mutton;

    // If limits are met, mark as completed
    if (isCompleted && sub.status !== "completed") {
      sub.status = "completed";
      await sub.save();
      console.log(`Subscription ${sub._id} is now COMPLETED.`);
    }
    // If limits are NOT met (e.g., manager un-served a meal), revert to active
    else if (!isCompleted && sub.status === "completed") {
      sub.status = "active";
      await sub.save();
      console.log(`Subscription ${sub._id} reverted back to ACTIVE.`);
    }
  } catch (error) {
    console.error("Consumption Check Error:", error);
  }
};