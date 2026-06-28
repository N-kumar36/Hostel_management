import moment from "moment";
import Meal from "../models/Meal.js";
import WeeklyRoutine from "../models/WeeklyRoutine.js";
import { recalculateMealNumbers } from "./utils/mealHelpers.js"; // Replace with your actual utility path



/**
 * @desc    Create or update a master daily meal layout configuration
 * @route   POST /api/meals/create
 */
export const createMeal = async (req, res) => {
  try {
    const { date, morning, night } = req.body;
    const hostelId = req.user.hostelId;

    console.log("create meal", date, morning, night)

    if (!date || !morning || !night) {
      return res.status(400).json({ success: false, message: "Missing required fields" });
    }

    // Helper to safely parse strings into Dates without unexpected timezone changes
    const parseLockTime = (targetDateStr, isoTimeStr) => {
      // If the incoming string is a full ISO timestamp, extract just the time component HH:MM
      const timePart = isoTimeStr.includes("T") ? isoTimeStr.split("T")[1].substring(0, 5) : isoTimeStr.substring(0, 5);
      const [day, month, year] = targetDateStr.split("/");
      // Build a clean local date constructor string
      return new Date(`${year}-${month}-${day}T${timePart}:00.000Z`);
    };

    const existingMeal = await Meal.findOne({ date, hostelId });

    if (existingMeal) {
      existingMeal.morning.manu = morning.manu;
      existingMeal.morning.lockTime = parseLockTime(date, morning.lockTime);

      if (morning.isCancelled !== undefined) existingMeal.morning.isCancelled = morning.isCancelled;

      existingMeal.night.manu = night.manu;
      existingMeal.night.lockTime = parseLockTime(date, night.lockTime);
      if (night.isCancelled !== undefined) existingMeal.night.isCancelled = night.isCancelled;

      await existingMeal.save();
      await recalculateMealNumbers(hostelId);

      const updatedMeal = await Meal.findOne({ date, hostelId });
      return res.status(200).json({ success: true, message: "Meal plan updated successfully.", meal: updatedMeal });
    }

    const meal = await Meal.create({
      hostelId,
      date,
      morning: {
        manu: morning.manu,
        mealsNum: "0",
        lockTime: parseLockTime(date, morning.lockTime),
        isLocked: false,
        isCancelled: false,
        studentVotes: [],
        guestRequests: []
      },
      night: {
        manu: night.manu,
        mealsNum: "0",
        lockTime: parseLockTime(date, night.lockTime),
        isLocked: false,
        isCancelled: false,
        studentVotes: [],
        guestRequests: []
      },
    });

    await recalculateMealNumbers(hostelId);
    const finalSavedMeal = await Meal.findById(meal._id);

    return res.status(201).json({ success: true, message: "Meal plan created successfully.", meal: finalSavedMeal });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

/**
 * @desc    Auto-generate batch meal routines across customized execution windows
 * @route   POST /api/meals/auto-generate
 */
export const autoGenerateMeals = async (req, res) => {
  try {
    const { startDate, endDate, morningLockTime, nightLockTime } = req.body;
    const hostelId = req.user.hostelId;

    if (!startDate || !endDate) {
      return res.status(400).json({ success: false, message: "Start date and End date are required." });
    }

    const mTime = morningLockTime || "07:00";
    const nTime = nightLockTime || "17:00";
    const [mHour, mMin] = mTime.split(':').map(Number);
    const [nHour, nMin] = nTime.split(':').map(Number);

    const routineDoc = await WeeklyRoutine.findOne({ hostelId });
    if (!routineDoc || !routineDoc.routine) {
      return res.status(400).json({ success: false, message: "Weekly routine is missing. Please set it first." });
    }
    const routine = routineDoc.routine;

    const [sDay, sMonth, sYear] = startDate.split('/');
    let currentDate = new Date(sYear, sMonth - 1, sDay);
    const [eDay, eMonth, eYear] = endDate.split('/');
    let finalDate = new Date(eYear, eMonth - 1, eDay);

    currentDate.setHours(0, 0, 0, 0);
    finalDate.setHours(0, 0, 0, 0);

    if (currentDate > finalDate) {
      return res.status(400).json({ success: false, message: "Start date must be before or equal to End date." });
    }

    let createdCount = 0;

    while (currentDate <= finalDate) {
      const dateString = `${String(currentDate.getDate()).padStart(2, '0')}/${String(currentDate.getMonth() + 1).padStart(2, '0')}/${currentDate.getFullYear()}`;
      let dayOfWeek = currentDate.getDay();
      if (dayOfWeek === 0) dayOfWeek = 7;

      const dayKey = dayOfWeek.toString();
      const dayRoutine = routine.get ? routine.get(dayKey) : routine[dayKey];

      if (dayRoutine) {
        const existingMeal = await Meal.findOne({ date: dateString, hostelId });

        if (!existingMeal) {
          const morningLock = new Date(Date.UTC(currentDate.getFullYear(), currentDate.getMonth(), currentDate.getDate(), mHour, mMin, 0));
          const nightLock = new Date(Date.UTC(currentDate.getFullYear(), currentDate.getMonth(), currentDate.getDate(), nHour, nMin, 0));

          await Meal.create({
            hostelId,
            date: dateString,
            morning: { manu: dayRoutine.morning, mealsNum: "0", lockTime: morningLock, isCancelled: false, studentVotes: [], guestRequests: [] },
            night: { manu: dayRoutine.night, mealsNum: "0", lockTime: nightLock, isCancelled: false, studentVotes: [], guestRequests: [] }
          });
          createdCount++;
        }
      }
      currentDate.setDate(currentDate.getDate() + 1);
    }

    if (createdCount > 0) {
      await recalculateMealNumbers(hostelId);
    }

    return res.status(200).json({ success: true, message: `Successfully generated ${createdCount} new meals.` });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * @desc    Inline meal updating controller
 * @route   PUT /api/meals/update/:mealId
 */

export const updateMeal = async (req, res) => {
  try {
    const { mealId } = req.params;
    
    // 1. Fetch the target meal record first
    const existingMeal = await Meal.findById(mealId);
    if (!existingMeal) {
      return res.status(404).json({ success: false, message: "Meal configuration record not found." });
    }

    const updateData = {};
    const clearMorningArrays = {};
    const clearNightArrays = {};

    // 🛡️ MORNING SLOT OPERATIONS
    if (req.body.morning) {
      // Rule 1: If menu item changes, wipe the arrays so students can revote
      if (req.body.morning.manu && req.body.morning.manu !== existingMeal.morning.manu) {
        updateData["morning.manu"] = req.body.morning.manu;
        
        // Clear student votes and guest requests out completely
        clearMorningArrays["morning.studentVotes"] = [];
        clearMorningArrays["morning.guestRequests"] = [];
      }
      
      // Rule 2: If canceling the meal, update status but KEEP the votes intact
      if (req.body.morning.isCancelled !== undefined) {
        updateData["morning.isCancelled"] = req.body.morning.isCancelled;
      }
      
      if (req.body.morning.lockTime) {
        const timePart = req.body.morning.lockTime.includes("T") 
          ? req.body.morning.lockTime.split("T")[1].substring(0, 5) 
          : req.body.morning.lockTime.substring(0, 5);
        const [day, month, year] = existingMeal.date.split("/");
        updateData["morning.lockTime"] = new Date(`${year}-${month}-${day}T${timePart}:00.000Z`);
      }
    }

    // 🛡️ NIGHT SLOT OPERATIONS
    if (req.body.night) {
      // Rule 1: If menu item changes, wipe the arrays so students can revote
      if (req.body.night.manu && req.body.night.manu !== existingMeal.night.manu) {
        updateData["night.manu"] = req.body.night.manu;
        
        // Clear student votes and guest requests out completely
        clearNightArrays["night.studentVotes"] = [];
        clearNightArrays["night.guestRequests"] = [];
      }
      
      // Rule 2: If canceling the meal, update status but KEEP the votes intact
      if (req.body.night.isCancelled !== undefined) {
        updateData["night.isCancelled"] = req.body.night.isCancelled;
      }
      
      if (req.body.night.lockTime) {
        const timePart = req.body.night.lockTime.includes("T") 
          ? req.body.night.lockTime.split("T")[1].substring(0, 5) 
          : req.body.night.lockTime.substring(0, 5);
        const [day, month, year] = existingMeal.date.split("/");
        updateData["night.lockTime"] = new Date(`${year}-${month}-${day}T${timePart}:00.000Z`);
      }
    }

    // 2. Build the final update payload combining atomic sets and clears
    const finalUpdatePayload = { $set: updateData };
    
    // Add arrays to be wiped out if menu changed
    if (Object.keys(clearMorningArrays).length > 0 || Object.keys(clearNightArrays).length > 0) {
      finalUpdatePayload.$set = { 
        ...updateData, 
        ...clearMorningArrays, 
        ...clearNightArrays 
      };
    }

    // 3. Commit changes to MongoDB
    const updatedMeal = await Meal.findByIdAndUpdate(
      mealId,
      finalUpdatePayload,
      { new: true, runValidators: true }
    );

    await recalculateMealNumbers(req.user.hostelId);

    return res.status(200).json({ 
      success: true, 
      message: "Meal configuration synchronized successfully.", 
      meal: updatedMeal 
    });

  } catch (error) {
    return res.status(500).json({ 
      success: false, 
      message: "Internal server side update process error: " + error.message 
    });
  }
};



/**
 * @desc    Atomically cast a personal plate vote with dynamic item preferences mapping
 * @route   POST /api/meals/vote
 */
export const castVote = async (req, res) => {
  try {
    const { mealId, timeSlot, itemPreference } = req.body;
    const studentId = req.user._id || req.user.id;

    const mealDoc = await Meal.findById(mealId);
    if (!mealDoc) return res.status(404).json({ success: false, message: "Schedule timeline parameters not found." });

    const slot = mealDoc[timeSlot];
    if (!slot) return res.status(400).json({ success: false, message: "Invalid time slot target definition." });

    if (slot.isCancelled) return res.status(400).json({ success: false, message: "Voting rejected. This meal slot has been cancelled." });
    if (slot.isLocked || new Date() > new Date(slot.lockTime)) {
      return res.status(400).json({ success: false, message: "Voting locked. The modification cutoff deadline has passed." });
    }

    const baseMenu = slot.manu;
    let calculatedMenuAllocation = baseMenu;

    if (itemPreference === "halal_chicken") {
      if (baseMenu !== "chicken") {
        return res.status(400).json({ success: false, message: "Halal Chicken variation is restricted unless core menu option is chicken." });
      }
      calculatedMenuAllocation = "halal_chicken";
    }
    else if (itemPreference === "egg_substitute") {
      if (baseMenu === "veg") {
        return res.status(400).json({ success: false, message: "Cannot swap out a pure vegetarian plate menu layout tier for egg variants." });
      }
      calculatedMenuAllocation = "egg";
    }
    else if (itemPreference === "veg_forced") {
      calculatedMenuAllocation = "veg";
    }

    slot.studentVotes.push({
      userId: studentId,
      itemPreference: itemPreference || "regular",
      finalAllocatedMenu: calculatedMenuAllocation
    });

    await mealDoc.save();
    return res.status(200).json({ success: true, message: `Vote registered successfully as ${calculatedMenuAllocation}!` });

  } catch (error) {
    if (error.code === 11000) return res.status(400).json({ success: false, message: "Duplicate attempt. You already voted for this slot period configuration." });
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * @desc    Submit a guest meal reservation array block request into a daily schedule slot
 * @route   POST /api/meals/request-guest
 */
export const requestGuestMeal = async (req, res) => {
  try {
    const { date, timeSlot, guestCount, guestItemPreference } = req.body;
    const studentId = req.user._id;

    const mealDoc = await Meal.findOne({ hostelId: req.user.hostelId, date });
    if (!mealDoc) return res.status(404).json({ success: false, message: "Mess schedule timeline data entry map index missing." });

    const slot = mealDoc[timeSlot];
    if (slot.isLocked || new Date() > new Date(slot.lockTime)) {
      return res.status(400).json({ success: false, message: "Guest reservations loop timeline for this menu space has closed." });
    }

    slot.guestRequests.push({
      studentId,
      guestCount: parseInt(guestCount) || 1,
      guestItemPreference: guestItemPreference || "regular",
      status: "pending"
    });

    await mealDoc.save();
    return res.status(200).json({ success: true, message: "Guest plate booking request routed waiting for review." });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * @desc    Calculate exact grocery count allocations for the cooking staff members
 * @route   GET /api/meals/kitchen-metrics/:id
 */
export const getKitchenCookingMetrics = async (req, res) => {
  try {
    const mealDoc = await Meal.findById(req.params.id).lean();
    if (!mealDoc) return res.status(404).json({ success: false, message: "Daily collection file profile missing." });

    const calculateSlotMetrics = (slot) => {
      const votes = slot.studentVotes || [];
      const approvedGuests = (slot.guestRequests || []).filter(g => g.status === "approved");

      let veg = votes.filter(v => v.finalAllocatedMenu === "veg").length;
      let egg = votes.filter(v => v.finalAllocatedMenu === "egg").length;
      let paneer = votes.filter(v => v.finalAllocatedMenu === "paneer").length;
      let chicken = votes.filter(v => v.finalAllocatedMenu === "chicken").length;
      let halalChicken = votes.filter(v => v.finalAllocatedMenu === "halal_chicken").length;
      let fish = votes.filter(v => v.finalAllocatedMenu === "fish").length;
      let mutton = votes.filter(v => v.finalAllocatedMenu === "mutton").length;

      approvedGuests.forEach(g => {
        const pref = g.guestItemPreference;
        const base = slot.manu;

        if (pref === "halal_chicken" && base === "chicken") halalChicken += g.guestCount;
        else if (pref === "egg_substitute" && base !== "veg") egg += g.guestCount;
        else if (pref === "veg_forced") veg += g.guestCount;
        else {
          if (base === "veg") veg += g.guestCount;
          if (base === "egg") egg += g.guestCount;
          if (base === "paneer") paneer += g.guestCount;
          if (base === "chicken") chicken += g.guestCount;
          if (base === "fish") fish += g.guestCount;
          if (base === "mutton") mutton += g.guestCount;
        }
      });

      return {
        baseRoutineMenu: slot.manu,
        isCancelled: slot.isCancelled,
        isLocked: slot.isLocked,
        totalPlatesToCook: votes.length + approvedGuests.reduce((s, g) => s + g.guestCount, 0),
        breakdown: { veg, egg, paneer, chicken, halalChicken, fish, mutton }
      };
    };

    return res.status(200).json({
      success: true,
      date: mealDoc.date,
      morning: calculateSlotMetrics(mealDoc.morning),
      night: calculateSlotMetrics(mealDoc.night)
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};

/**
 * @desc    Fetch meal status breakdown list maps history records for checking app progress rings charts
 * @route   GET /api/meals/status/:studentId
 */
export const getMealStatus = async (req, res) => {
  try {
    const { studentId } = req.params;
    const hostelId = req.user.hostelId;

    const rawMeals = await Meal.find({ hostelId }).lean();

    let totalMealsThisMonth = 0;
    let mealsConsumed = 0;
    const historyList = [];

    const currentMonthStr = String(new Date().getMonth() + 1).padStart(2, '0');
    const currentYearStr = String(new Date().getFullYear());

    for (const meal of rawMeals) {
      const dateParts = meal.date.split('/');
      const isCurrentMonth = dateParts[1] === currentMonthStr && dateParts[2] === currentYearStr;

      if (!meal.morning.isCancelled) {
        if (isCurrentMonth) totalMealsThisMonth++;
        const morningVote = meal.morning.studentVotes.find(v => v.userId.toString() === studentId);
        if (morningVote && morningVote.isServed && isCurrentMonth) mealsConsumed++;

        historyList.push({
          date: meal.date,
          timeSlot: "morning",
          menuItem: morningVote ? morningVote.finalAllocatedMenu : meal.morning.manu,
          isCancelled: false,
          voted: !!morningVote,
          isServed: morningVote ? morningVote.isServed : false
        });
      } else {
        historyList.push({ date: meal.date, timeSlot: "morning", menuItem: meal.morning.manu, isCancelled: true, voted: false, isServed: false });
      }

      if (!meal.night.isCancelled) {
        if (isCurrentMonth) totalMealsThisMonth++;
        const nightVote = meal.night.studentVotes.find(v => v.userId.toString() === studentId);
        if (nightVote && nightVote.isServed && isCurrentMonth) mealsConsumed++;

        historyList.push({
          date: meal.date,
          timeSlot: "night",
          menuItem: nightVote ? nightVote.finalAllocatedMenu : meal.night.manu,
          isCancelled: false,
          voted: !!nightVote,
          isServed: nightVote ? nightVote.isServed : false
        });
      } else {
        historyList.push({ date: meal.date, timeSlot: "night", menuItem: meal.night.manu, isCancelled: true, voted: false, isServed: false });
      }
    }

    historyList.sort((a, b) => {
      const splitA = a.date.split('/');
      const splitB = b.date.split('/');
      return new Date(splitB[2], splitB[1] - 1, splitB[0]) - new Date(splitA[2], splitA[1] - 1, splitA[0]);
    });

    return res.status(200).json({
      success: true,
      totalMealsThisMonth,
      mealsConsumed,
      history: historyList
    });

  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
};


export const getAllMeals = async (req, res) => {
  try {
    const userHostelId = req.user.hostelId;
    if (!userHostelId) {
      return res.status(403).json({ success: false, message: "Access denied. No hostel assigned." });
    }

    const { startDateStr, endDateStr } = req.query;
    console.log("Query Parameters Received: ", startDateStr, endDateStr);

    let targetMeals = [];

    // ➔ OPTION A: If at least a Start Date is available, fetch all meals from that date onwards
    if (startDateStr && startDateStr !== 'null') {
      const [startDay, startMonth, startYear] = startDateStr.split("/");
      const trueStartDate = new Date(`${startYear}-${startMonth}-${startDay}T00:00:00.000Z`);

      // If an explicit end date is also present, capture the bound; otherwise fallback to future infinity
      let trueEndDate = null;
      if (endDateStr && endDateStr !== 'null') {
        const [endDay, endMonth, endYear] = endDateStr.split("/");
        trueEndDate = new Date(`${endYear}-${endMonth}-${endDay}T23:59:59.999Z`);
      }

      const mealsInSystem = await Meal.find({ hostelId: userHostelId }).lean();

      targetMeals = mealsInSystem.filter(meal => {
        const [d, m, y] = meal.date.split("/");
        const currentMealDate = new Date(`${y}-${m}-${d}T00:00:00.000Z`);
        
        if (trueEndDate) {
          return currentMealDate >= trueStartDate && currentMealDate <= trueEndDate;
        }
        // If no end date, return everything from start date forward
        return currentMealDate >= trueStartDate;
      });

    } else {
      // ➔ OPTION B: AUTOMATIC CURRENT CYCLE DETECTOR (Fallback to Active 1-60 Meal Block)
      const now = new Date();
      const todayStr = `${String(now.getDate()).padStart(2, '0')}/${String(now.getMonth() + 1).padStart(2, '0')}/${now.getFullYear()}`;

      let referenceMeal = await Meal.findOne({ hostelId: userHostelId, date: todayStr }).lean();

      // If today has no document, find the most recently created historical document entry
      if (!referenceMeal) {
        referenceMeal = await Meal.findOne({ hostelId: userHostelId })
          .sort({ createdAt: -1 })
          .lean();
      }

      if (referenceMeal) {
        const currentNum = parseInt(referenceMeal.morning?.mealsNum || referenceMeal.night?.mealsNum || 1, 10);

        const cycleIndexOffset = (currentNum - 1) % 60; 
        const cycleStartMealNum = currentNum - cycleIndexOffset; 
        const cycleEndMealNum = cycleStartMealNum + 59; 

        const mealsInSystem = await Meal.find({ hostelId: userHostelId }).lean();

        targetMeals = mealsInSystem.filter(meal => {
          const mNumMorning = parseInt(meal.morning?.mealsNum || 0, 10);
          const mNumNight = parseInt(meal.night?.mealsNum || 0, 10);
          
          return (mNumMorning >= cycleStartMealNum && mNumMorning <= cycleEndMealNum) ||
                 (mNumNight >= cycleStartMealNum && mNumNight <= cycleEndMealNum);
        });
      }
      
      // Extreme Fallback: If filtered list is still empty, output the latest 30 records
      if (targetMeals.length === 0) {
        targetMeals = await Meal.find({ hostelId: userHostelId })
          .sort({ createdAt: -1 })
          .limit(30)
          .lean();
      }
    }

    // ➔ Sort sequentially by date
    targetMeals.sort((a, b) => {
      const [dA, mA, yA] = a.date.split("/").map(Number);
      const [dB, mB, yB] = b.date.split("/").map(Number);
      return new Date(yA, mA - 1, dA) - new Date(yB, mB - 1, dB);
    });

    return res.status(200).json({
      success: true,
      count: targetMeals.length,
      meals: targetMeals
    });

  } catch (error) {
    return res.status(500).json({ success: false, message: "Error fetching current cycle meals: " + error.message });
  }
};


export const getWeeklyMeals = async (req, res) => {
  try {
    const allMeals = await Meal.find({ hostelId: req.user.hostelId }).sort({ createdAt: 1 });
    const today = moment().startOf('day');

    const filteredMeals = allMeals.filter(meal => {
      const mealDate = moment(meal.date, "DD/MM/YYYY");
      return mealDate.isSameOrAfter(today);
    });

    const meals = filteredMeals.slice(0, 30);

    if (!meals || meals.length === 0) {
      return res.status(404).json({ success: false, message: "No upcoming meal plans found." });
    }

    return res.json({ success: true, meals });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

export const getTodayMeals = async (req, res) => {
  try {
    const today = new Date();
    const todayStr = `${String(today.getDate()).padStart(2, '0')}/${String(today.getMonth() + 1).padStart(2, '0')}/${today.getFullYear()}`;

    const meal = await Meal.findOne({ hostelId: req.user.hostelId, date: todayStr });

    return res.json({ success: true, meal });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};