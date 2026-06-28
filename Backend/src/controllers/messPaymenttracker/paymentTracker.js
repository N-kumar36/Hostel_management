import mongoose from "mongoose";
import Meal from "../../models/meal.js";

import Fine from "../../models/fine.model.js";
import StudentSubscription from "../../models/StudentSubscription.js";

/**
 * Calculates current cycle dates and active cash pool based on uncompleted loops
 * @param {String} hostelId 
 * @returns {Object} { activeDates, collectedFineFunds }
 */
export const calculateCurrentCycleBudget = async (hostelId) => {
  try {
    // 1. Fetch dates under the current running 1-60 meal block
    const activeMeals = await Meal.find({
      hostelId: hostelId,
      $or: [
        { "morning.mealsNum": { $gte: "1", $lte: "60" } },
        { "night.mealsNum": { $gte: "1", $lte: "60" } }
      ]
    }).select("date");

    const activeDates = activeMeals.map(meal => meal.date);

    // 2. Strict Check: Find all student subscriptions for this hostel that are NOT completed
    const uncompletedSubscriptions = await StudentSubscription.find({
      hostelId: hostelId,
      status: { $in: ["pending", "active"] } // Still running or upcoming
    }).select("_id");

    const subIds = uncompletedSubscriptions.map(sub => sub._id);

    // 3. Aggregate successful fine payments linked to these uncompleted subscriptions
    const collectedFines = await Fine.aggregate([
      {
        $match: {
          hostelId: new mongoose.Types.ObjectId(hostelId),
          subscriptionId: { $in: subIds },
          status: "success" // Strictly check successful payments
        }
      },
      {
        $group: {
          _id: null,
          totalCollected: { $sum: "$amount" }
        }
      }
    ]);

    const collectedFineFunds = collectedFines.length > 0 ? collectedFines[0].totalCollected : 0;

    return {
      activeDates,
      collectedFineFunds
    };
  } catch (error) {
    console.error("Budget tracking calculation error:", error);
    throw error;
  }
};