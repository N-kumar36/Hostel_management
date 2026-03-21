import mongoose from "mongoose";
import Vote from "../models/Vote.js";
import Meal from "../models/Meal.js";
import StudentSubscription from "../models/StudentSubscription.js";
import Fine from "../models/fine.model.js";
import FinePrice from "../models/FinePrice.js";
import User from "../models/User.js";
import moment from "moment";



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

    console.log("cancel api was call ", mealId )

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

    // 1. Find the Meal document (Matches DD/MM/YYYY)
    const meal = await Meal.findOne({ date: mealDate });
    if (!meal) {
      return res.status(404).json({ success: false, message: "No meal routine found for this date" });
    }

    // 2. Fetch all votes (Students + Individual Guests)
    const votes = await Vote.find({ 
      mealId: meal._id, 
      timeSlot: timeSlot.toLowerCase() 
    }).populate("userId", "name email photoURL");

    // 3. Map the data
    const formattedData = votes.map(vote => ({
      voteId: vote._id,
      //  Logic: Use guestName if it exists, otherwise use student name
      studentName: vote.isGuest ? vote.guestName : (vote.userId?.name || "Unknown"),
      studentEmail: vote.userId?.email || "N/A",
      studentPhoto: vote.isGuest ? "" : (vote.userId?.photoURL || ""),
      mealDate: mealDate,
      timeSlot: vote.timeSlot,
      choice: vote.mealType,
      votedAt: vote.votedAt,
      isServed: vote.isServed,
      isGuest: vote.isGuest || false,
      // hostName helps the manager see who requested the guest
      hostName: vote.isGuest ? vote.userId?.name : null 
    }));

    res.json({ 
      success: true, 
      count: formattedData.length, 
      data: formattedData 
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};





// Controller: toggleServeStatus
export const toggleServeStatus = async (req, res) => {
  try {
    const { voteId } = req.body;

    // 1. Find Vote and Meal data
    const vote = await Vote.findById(voteId).populate("mealId");
    if (!vote) return res.status(404).json({ success: false, message: "Vote not found" });

    const mealDate = moment(vote.mealId.date, "DD/MM/YYYY");
    const subscriptionMonth = mealDate.format("MMMM YYYY");
    const mealType = vote.mealType.toLowerCase();

    // 2. Find Subscription
    const subscription = await StudentSubscription.findOne({
      studentId: vote.userId,
      month: subscriptionMonth,
      status: "active"
    });

    if (!subscription && !vote.isGuest) {
      return res.status(400).json({ success: false, message: "No active plan for this month" });
    }

    const isNowServed = !vote.isServed;

    // --- AUTO FINE LOGIC ---
    if (isNowServed && !vote.isGuest) {
      const currentUsage = subscription.usage[mealType] || 0;
      const maxAllowed = subscription.maxLimits[mealType] || 0;

      // Check if this meal is EXTRA
      if (currentUsage >= maxAllowed) {
        // Fetch specific fine prices for this hostel
        const priceList = await FinePrice.findOne({ hostelId: vote.hostelId });
        const fineAmount = priceList ? priceList.prices[mealType] : 50; // Fallback to 50 if no price set

        // Find manager ID to assign the fine
        const manager = await User.findOne({ hostelId: vote.hostelId, role: "manager" });

        // Create the Automatic Fine
        await Fine.create({
          studentId: vote.userId,
          managerId: manager ? manager._id : vote.userId, // Fallback safety
          hostelId: vote.hostelId,
          title: `Extra Meal Charge - ${vote.mealType.toUpperCase()}`,
          amount: fineAmount,
          description: `Automatically generated: Limit for ${mealType} was ${maxAllowed}. Student is consuming an extra plate.`,
          status: "pending",
          date: new Date()
        });
      }
    }

    // 3. Update Subscription Usage
    if (!vote.isGuest && subscription) {
      const incValue = isNowServed ? 1 : -1;
      const updateKey = `usage.${mealType}`;

      if (!isNowServed && subscription.usage[mealType] <= 0) {
        // Safety: Don't decrement below 0
      } else {
        await StudentSubscription.findByIdAndUpdate(subscription._id, {
          $inc: { [updateKey]: incValue }
        });
      }
    }

    // 4. Update Vote Status
    vote.isServed = isNowServed;
    vote.servedAt = isNowServed ? new Date() : null;
    await vote.save();

    res.json({
      success: true,
      message: vote.isServed 
        ? (subscription.usage[mealType] >= subscription.maxLimits[mealType] 
            ? `Extra ${vote.mealType} served. Fine generated!` 
            : `Marked ${vote.mealType} as served`)
        : "Service undone",
      isServed: vote.isServed
    });

  } catch (error) {
    console.error("Toggle Serve Error:", error);
    res.status(500).json({ success: false, message: error.message });
  }
};