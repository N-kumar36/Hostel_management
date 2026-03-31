import moment from "moment"; 
import Meal from "../models/Meal.js";
import mongoose from 'mongoose';
import WeeklyRoutine from "../models/WeeklyRoutine.js"; 

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
      // FIX: Use new Date() to ensure proper ISO storage in MongoDB
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

// Auto Generate Meals based on Routine
// Auto Generate Meals based on Routine
// Auto Generate Meals based on Routine
export const autoGenerateMeals = async (req, res) => {
  try {
    // ✨ FIX: Destructure the new lock times from the request body
    const { startDate, endDate, morningLockTime, nightLockTime } = req.body; 
    const hostelId = req.user.hostelId;

    if (!startDate || !endDate) {
      return res.status(400).json({ success: false, message: "Start date and End date are required." });
    }

    // Parse the times (Fallback to 07:00 and 17:00 if not provided)
    const mTime = morningLockTime || "07:00";
    const nTime = nightLockTime || "17:00";
    
    const [mHour, mMin] = mTime.split(':').map(Number);
    const [nHour, nMin] = nTime.split(':').map(Number);

    // 1. Get the routine for this hostel
    const routineDoc = await WeeklyRoutine.findOne({ hostelId: hostelId });
    if (!routineDoc || !routineDoc.routine) {
      return res.status(400).json({ success: false, message: "Weekly routine is missing. Please set it first." });
    }
    const routine = routineDoc.routine;

    // 2. Parse startDate and endDate
    const [sDay, sMonth, sYear] = startDate.split('/');
    let currentDate = new Date(sYear, sMonth - 1, sDay);
    
    const [eDay, eMonth, eYear] = endDate.split('/');
    let finalDate = new Date(eYear, eMonth - 1, eDay);

    // Normalize hours to ensure accurate Date comparison loop
    currentDate.setHours(0, 0, 0, 0);
    finalDate.setHours(0, 0, 0, 0);

    if (currentDate > finalDate) {
      return res.status(400).json({ success: false, message: "Start date must be before or equal to End date." });
    }

    let createdCount = 0;
    let activeCount = await Meal.countDocuments({ hostelId: hostelId });

    // 3. Loop and create meals UNTIL we pass the finalDate
    while (currentDate <= finalDate) {
      const dateString = `${String(currentDate.getDate()).padStart(2, '0')}/${String(currentDate.getMonth() + 1).padStart(2, '0')}/${currentDate.getFullYear()}`;
      
      let dayOfWeek = currentDate.getDay();
      if (dayOfWeek === 0) dayOfWeek = 7; 
      
      const dayKey = dayOfWeek.toString();
      const dayRoutine = routine.get ? routine.get(dayKey) : routine[dayKey];
      
      if (dayRoutine) {
        const existingMeal = await Meal.findOne({ date: dateString, hostelId: hostelId });
        
        if (!existingMeal) {
          
          // ✨ FIX: Apply the dynamically selected hours and minutes
          const morningLock = new Date(Date.UTC(
            currentDate.getFullYear(), 
            currentDate.getMonth(), 
            currentDate.getDate(), 
            mHour, mMin, 0
          )); 
          
          const nightLock = new Date(Date.UTC(
            currentDate.getFullYear(), 
            currentDate.getMonth(), 
            currentDate.getDate(), 
            nHour, nMin, 0
          )); 

          const nextMorningNum = (activeCount * 2 + 1).toString();
          const nextNightNum = (activeCount * 2 + 2).toString();

          await Meal.create({
            hostelId: hostelId,
            date: dateString,
            morning: { manu: dayRoutine.morning, mealsNum: nextMorningNum, lockTime: morningLock, isCancelled: false },
            night: { manu: dayRoutine.night, mealsNum: nextNightNum, lockTime: nightLock, isCancelled: false }
          });
          
          activeCount++;
          createdCount++;
        } else {
          console.log(`Meal already exists for ${dateString}, skipping.`);
        }
      } else {
        console.log(`No routine found in DB for Day ${dayKey}`);
      }
      
      // Move to the next day
      currentDate.setDate(currentDate.getDate() + 1);
    }

    res.status(200).json({ 
      success: true, 
      message: `Successfully generated ${createdCount} new meals.` 
    });

  } catch (error) {
    console.error("Auto Generate Error:", error);
    res.status(500).json({ success: false, message: error.message });
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
      if (req.body.morning.lockTime) updateData["morning.lockTime"] = new Date(req.body.morning.lockTime); 
    }

    if (req.body.night) {
      if (req.body.night.manu) updateData["night.manu"] = req.body.night.manu;
      if (req.body.night.isCancelled !== undefined) updateData["night.isCancelled"] = req.body.night.isCancelled;
      if (req.body.night.lockTime) updateData["night.lockTime"] = new Date(req.body.night.lockTime); 
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
      hostelId: userHostelId, 
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

    // 4. Limit to 30 days of upcoming meals
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
    // ✅ BUG FIX: Strictly format as DD/MM/YYYY so it never fails on cloud servers
    const todayStr = `${String(today.getDate()).padStart(2, '0')}/${String(today.getMonth() + 1).padStart(2, '0')}/${today.getFullYear()}`;

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
    const { studentId } =  req.params; 
    const hostelId = req.user.hostelId; 

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