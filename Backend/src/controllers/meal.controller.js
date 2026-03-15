import moment from "moment"; // Optional but helpful for date formatting
import Meal from "../models/Meal.js";
import mongoose from 'mongoose';
import { param } from "express-validator";



export const createMeal = async (req, res) => {
  try {
    const { date, morning, night } = req.body;
    const hostelId = req.user.hostelId; // From authMiddleware

    if (!date || !morning || !night) {
      return res.status(400).json({ success: false, message: "Missing required fields" });
    }

    // 1. Check if a meal for this date already exists for this hostel
    const existingMeal = await Meal.findOne({ date, hostelId });

    if (existingMeal) {
      //  FIX: Use new Date() to ensure proper ISO storage in MongoDB
      existingMeal.morning.manu = morning.manu;
      existingMeal.morning.lockTime = new Date(morning.lockTime);
      existingMeal.night.manu = night.manu;
      existingMeal.night.lockTime = new Date(night.lockTime);

      await existingMeal.save();
      return res.status(200).json({ success: true, message: "Meal plan updated", meal: existingMeal });
    }

    // 2. Generate Serial Numbers (MealsNum)
    const activeCount = await Meal.countDocuments({ hostelId });
    const nextMorningNum = (activeCount * 2 + 1).toString();
    const nextNightNum = (activeCount * 2 + 2).toString();

    // 3. Create New Meal
    const meal = await Meal.create({
      hostelId,
      date,
      morning: {
        manu: morning.manu,
        mealsNum: nextMorningNum,
        lockTime: new Date(morning.lockTime), // ✅ FIX: Parse as Date object
        isLocked: false,
        isCancelled: false,
      },
      night: {
        manu: night.manu,
        mealsNum: nextNightNum,
        lockTime: new Date(night.lockTime), // ✅ FIX: Parse as Date object
        isLocked: false,
        isCancelled: false,
      },
    });

    res.status(201).json({ success: true, message: "Meal plan created", meal });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

export const updateMeal = async (req, res) => {
  try {
    const { mealId } = req.params;
    const updateData = {};


    // Use Dot Notation to update specific nested fields only
    if (req.body.morning) {
      if (req.body.morning.manu) updateData["morning.manu"] = req.body.morning.manu;
      if (req.body.morning.isCancelled !== undefined) updateData["morning.isCancelled"] = req.body.morning.isCancelled;
      if (req.body.morning.lockTime) updateData["morning.lockTime"] = new Date(req.body.morning.lockTime); // ✅ FIX
    }

    if (req.body.night) {
      if (req.body.night.manu) updateData["night.manu"] = req.body.night.manu;
      if (req.body.night.isCancelled !== undefined) updateData["night.isCancelled"] = req.body.night.isCancelled;
      if (req.body.night.lockTime) updateData["night.lockTime"] = new Date(req.body.night.lockTime); // ✅ FIX
    }

    const updatedMeal = await Meal.findByIdAndUpdate(
      mealId,
      { $set: updateData },
      { new: true, runValidators: true }
    );

    res.json({ success: true, meal: updatedMeal });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};


// Get all planned meals (Sorted by date)
export const getAllMeals = async (req, res) => {
  try {
    // 1. Security Check: Ensure the user belongs to a hostel
    const userHostelId = req.user.hostelId; // From your auth middleware
    if (!userHostelId) {
      return res.status(403).json({ success: false, message: "Access denied. No hostel assigned." });
    }

    // 2. Date Logic: Prepare current month and upcoming month strings
    const now = new Date();

    // Helper to format MM/YYYY
    const getMonthYear = (date) => {
      const m = String(date.getMonth() + 1).padStart(2, '0');
      const y = date.getFullYear();
      return `${m}/${y}`;
    };

    const currentMonth = getMonthYear(now);

    // Get next month for "upcoming" meal planning
    const nextMonthDate = new Date(now.getFullYear(), now.getMonth() + 1, 1);
    const nextMonth = getMonthYear(nextMonthDate);

    // 3. Secure Query: Filter by Hostel ID AND (Current Month OR Next Month)
    // Using a regex with an "OR" (|) operator to match either month suffix
    const meals = await Meal.find({
      hostelId: userHostelId, // 🔒 Security: Only show meals for this user's hostel
      date: {
        $regex: new RegExp(`(${currentMonth}|${nextMonth})$`)
      }
    }).sort({ date: 1 });

    res.status(200).json({
      success: true,
      count: meals.length,
      meals: meals
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error fetching meals: " + error.message
    });
  }
};


/**
 * GET /api/meals/week
 */


export const getWeeklyMeals = async (req, res) => {
  console.log("Get Weekly Meal Is called");
  try {
    // 1. Fetch all meals for this hostel
    const allMeals = await Meal.find({
      hostelId: req.user.hostelId,
    }).sort({ createdAt: 1 });

    // 2. Get today's date at midnight for accurate comparison
    const today = moment().startOf('day');

    // 3. Filter: Only keep meals where the date is today or in the future
    const filteredMeals = allMeals.filter(meal => {
      // Parse "DD/MM/YYYY" string into a date object
      const mealDate = moment(meal.date, "DD/MM/YYYY");
      return mealDate.isSameOrAfter(today);
    });

    // 4. Limit to 7 days of upcoming meals
    const meals = filteredMeals.slice(0, 30);

    if (!meals || meals.length === 0) {
      return res.status(404).json({
        success: false,
        message: "No upcoming meal plans found."
      });
    }

    res.json({ success: true, meals });
  } catch (err) {
    console.error("Fetch Weekly Meal Error:", err);
    res.status(500).json({ success: false, message: err.message });
  }
};


























/**
 * DELETE /api/meals/:id
 * Soft cancel meal (whole day)
 */
export const cancelMeal = async (req, res) => {
  try {
    const meal = await Meal.findOneAndUpdate(
      { _id: req.params.id, hostelId: req.user.hostelId },
      { isCancelled: true },
      { new: true }
    );

    if (!meal) {
      return res.status(404).json({
        success: false,
        message: "Meal not found",
      });
    }

    res.json({
      success: true,
      message: "Meal marked as cancelled",
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

/**
 * GET /api/meals/today
 */
export const getTodayMeals = async (req, res) => {
  try {
    const today = new Date();
    const todayStr = today.toLocaleDateString("en-GB"); // DD/MM/YYYY

    const meal = await Meal.findOne({
      hostelId: req.user.hostelId,
      date: todayStr,
      isCancelled: false,
    });

    res.json({ success: true, meal });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};



/// get meal status



export const getMealStatus = async (req, res) => {
  try {
    const { studentId } =  req.params; // From 
    const hostelId = req.user.hostelId; // From authMiddleware

    // Get current date boundaries for the current month
    const now = new Date();
    const currentMonth = (now.getMonth() + 1).toString().padStart(2, '0');
    const currentYear = now.getFullYear().toString();

    const result = await Meal.aggregate([
      // 1. Filter by Hostel
      { $match: { hostelId: new mongoose.Types.ObjectId(hostelId) } },

      // 2. Process Slots individually
      {
        $project: {
          date: 1,
          slots: [
            { timeSlot: "morning", manu: "$morning.manu", isCancelled: "$morning.isCancelled" },
            { timeSlot: "night", manu: "$night.manu", isCancelled: "$night.isCancelled" }
          ]
        }
      },
      { $unwind: "$slots" },

      // 3. Join with Votes to check 'voted' and 'isServed'
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

      // 4. Shape the data
      {
        $project: {
          date: 1,
          timeSlot: "$slots.timeSlot",
          menuItem: "$slots.manu",
          isCancelled: "$slots.isCancelled",
          voted: { $gt: [{ $size: "$voteData" }, 0] },
          isServed: { $ifNull: [{ $arrayElemAt: ["$voteData.isServed", 0] }, false] },
        }
      },

      // 5. Use FACET to calculate stats and list simultaneously
      {
        $facet: {
          historyList: [{ $sort: { date: -1 } }],
          summaryStats: [
            {
              $group: {
                _id: null,
                // Total only counts if NOT cancelled
                totalMealsThisMonth: {
                  $sum: { $cond: [{ $eq: ["$isCancelled", false] }, 1, 0] }
                },
                // Consumed only counts if isServed is true
                mealsConsumed: {
                  $sum: { $cond: [{ $eq: ["$isServed", true] }, 1, 0] }
                }
              }
            }
          ]
        }
      }
    ]);

    const stats = result[0].summaryStats[0] || { totalMealsThisMonth: 0, mealsConsumed: 0 };

    res.status(200).json({
      success: true,
      totalMealsThisMonth: stats.totalMealsThisMonth,
      mealsConsumed: stats.mealsConsumed,
      history: result[0].historyList
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
