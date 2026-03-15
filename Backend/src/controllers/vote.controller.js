import mongoose from "mongoose";
import Vote from "../models/Vote.js";
import Meal from "../models/Meal.js";



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
    const studentId = req.user.id; // From authMiddleware
    const hostelId = req.user.hostelId; // From authMiddleware
    console.log("Get History", studentId);

    const history = await Meal.aggregate([
      // 1. Filter by the user's specific hostel
      { 
        $match: { 
          hostelId: new mongoose.Types.ObjectId(hostelId) 
        } 
      },

      // 2. Project morning and night into an array so we can process each slot individually
      {
        $project: {
          date: 1,
          slots: [
            {
              timeSlot: "morning",
              manu: "$morning.manu",
              lockTime: "$morning.lockTime",
              isCancelled: "$morning.isCancelled"
            },
            {
              timeSlot: "night",
              manu: "$night.manu",
              lockTime: "$night.lockTime",
              isCancelled: "$night.isCancelled"
            }
          ]
        }
      },

      // 3. Flatten the array so each meal time becomes its own document
      { $unwind: "$slots" },

      // 4. Join with the 'votes' collection
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

      // 5. Final data structure for the Flutter app
      {
        $project: {
          _id: 1,
          date: 1,
          timeSlot: "$slots.timeSlot",
          menuItem: "$slots.manu",
          isCancelled: "$slots.isCancelled",
          voted: { $gt: [{ $size: "$voteData" }, 0] }, // true if user voted
          isServed: { $ifNull: [{ $arrayElemAt: ["$voteData.isServed", 0] }, false] },
          votedAt: { $arrayElemAt: ["$voteData.votedAt", 0] }
        }
      },

      // 6. Sort by date (descending) and timeSlot
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
      message: "Failed to fetch meal history: " + error.message
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
    const { voteId } = req.body; // The ID of the specific vote document
    console.log("voteId", voteId);

    const vote = await Vote.findById(voteId);
    if (!vote) return res.status(404).json({ success: false, message: "Vote not found" });

    // Toggle the served status
    vote.isServed = !vote.isServed;
    vote.servedAt = vote.isServed ? new Date() : null;
    
    await vote.save();

    res.json({ 
      success: true, 
      message: vote.isServed ? "Meal marked as served" : "Service undone",
      isServed: vote.isServed 
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};