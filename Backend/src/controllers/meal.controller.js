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

    console.log("create meal", date, morning, night);

    if (!date || !morning || !night) {
      return res.status(400).json({
        success: false,
        message: "Missing required fields"
      });
    }

    // Helper to safely parse strings into Dates without unexpected timezone changes
    const parseLockTime = (targetDateStr, isoTimeStr) => {
      const timePart = isoTimeStr.includes("T")
        ? isoTimeStr.split("T")[1].substring(0, 5)
        : isoTimeStr.substring(0, 5);

      const [day, month, year] = targetDateStr.split("/");

      return new Date(
        `${year}-${month}-${day}T${timePart}:00.000Z`
      );
    };

    /*
     * Normalize extra-meal information.
     *
     * Normal meal:
     *   isExtraMeal = false
     *   extraMealNumber = null
     *   occasion = null
     *
     * Extra meal:
     *   isExtraMeal = true
     *   mealsNum = "0"
     *   extraMealNumber = "61", "62", etc.
     */
    const prepareSlot = (slot, defaultLockTime) => {
      const isExtraMeal = slot.isExtraMeal === true;

      return {
        manu: slot.manu,

        // Extra meals NEVER receive a normal cycle number.
        mealsNum: "0",

        isExtraMeal,

        extraMealNumber: isExtraMeal
          ? (slot.extraMealNumber != null
              ? String(slot.extraMealNumber)
              : null)
          : null,

        occasion: isExtraMeal
          ? (slot.occasion?.trim() || null)
          : null,

        lockTime: parseLockTime(
          date,
          slot.lockTime || defaultLockTime
        ),

        isLocked: false,

        isCancelled: slot.isCancelled === true,

        studentVotes: [],
        guestRequests: []
      };
    };

    const existingMeal = await Meal.findOne({
      date,
      hostelId
    });

    // ============================================================
    // UPDATE EXISTING DAILY MEAL
    // ============================================================

    if (existingMeal) {
      /*
       * MORNING
       */
      existingMeal.morning.manu = morning.manu;

      existingMeal.morning.lockTime = parseLockTime(
        date,
        morning.lockTime
      );

      if (morning.isCancelled !== undefined) {
        existingMeal.morning.isCancelled = morning.isCancelled;
      }

      if (morning.isExtraMeal !== undefined) {
        existingMeal.morning.isExtraMeal =
          morning.isExtraMeal === true;

        if (existingMeal.morning.isExtraMeal) {
          existingMeal.morning.mealsNum = "0";

          existingMeal.morning.extraMealNumber =
            morning.extraMealNumber != null
              ? String(morning.extraMealNumber)
              : null;

          existingMeal.morning.occasion =
            morning.occasion?.trim() || null;
        } else {
          // Converting extra → normal
          existingMeal.morning.mealsNum = "0";
          existingMeal.morning.extraMealNumber = null;
          existingMeal.morning.occasion = null;
        }
      } else if (existingMeal.morning.isExtraMeal) {
        // Existing extra meal remains isolated from cycle.
        existingMeal.morning.mealsNum = "0";

        if (morning.extraMealNumber !== undefined) {
          existingMeal.morning.extraMealNumber =
            morning.extraMealNumber != null
              ? String(morning.extraMealNumber)
              : null;
        }

        if (morning.occasion !== undefined) {
          existingMeal.morning.occasion =
            morning.occasion?.trim() || null;
        }
      }

      /*
       * NIGHT
       */
      existingMeal.night.manu = night.manu;

      existingMeal.night.lockTime = parseLockTime(
        date,
        night.lockTime
      );

      if (night.isCancelled !== undefined) {
        existingMeal.night.isCancelled = night.isCancelled;
      }

      if (night.isExtraMeal !== undefined) {
        existingMeal.night.isExtraMeal =
          night.isExtraMeal === true;

        if (existingMeal.night.isExtraMeal) {
          existingMeal.night.mealsNum = "0";

          existingMeal.night.extraMealNumber =
            night.extraMealNumber != null
              ? String(night.extraMealNumber)
              : null;

          existingMeal.night.occasion =
            night.occasion?.trim() || null;
        } else {
          // Converting extra → normal
          existingMeal.night.mealsNum = "0";
          existingMeal.night.extraMealNumber = null;
          existingMeal.night.occasion = null;
        }
      } else if (existingMeal.night.isExtraMeal) {
        existingMeal.night.mealsNum = "0";

        if (night.extraMealNumber !== undefined) {
          existingMeal.night.extraMealNumber =
            night.extraMealNumber != null
              ? String(night.extraMealNumber)
              : null;
        }

        if (night.occasion !== undefined) {
          existingMeal.night.occasion =
            night.occasion?.trim() || null;
        }
      }

      await existingMeal.save();

      // Recalculate ONLY normal 1–60 meals.
      await recalculateMealNumbers(hostelId);

      const updatedMeal = await Meal.findOne({
        date,
        hostelId
      });

      return res.status(200).json({
        success: true,
        message: "Meal plan updated successfully.",
        meal: updatedMeal
      });
    }

    // ============================================================
    // CREATE NEW DAILY MEAL
    // ============================================================

    const meal = await Meal.create({
      hostelId,
      date,

      morning: prepareSlot(
        morning,
        morning.lockTime
      ),

      night: prepareSlot(
        night,
        night.lockTime
      )
    });

    // Assign normal 1–60 numbers.
    // Extra meals are ignored by the helper.
    await recalculateMealNumbers(hostelId);

    const finalSavedMeal = await Meal.findById(meal._id);

    return res.status(201).json({
      success: true,
      message: "Meal plan created successfully.",
      meal: finalSavedMeal
    });

  } catch (err) {
    return res.status(500).json({
      success: false,
      message: err.message
    });
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

    // 1. Fetch target meal
    const existingMeal = await Meal.findById(mealId);

    if (!existingMeal) {
      return res.status(404).json({
        success: false,
        message: "Meal configuration record not found."
      });
    }

    const updateData = {};
    const clearMorningArrays = {};
    const clearNightArrays = {};

    // ============================================================
    // MORNING SLOT
    // ============================================================

    if (req.body.morning) {
      const incomingMorning = req.body.morning;

      // ----------------------------------------------------------
      // Menu change
      // ----------------------------------------------------------

      if (
        incomingMorning.manu &&
        incomingMorning.manu !== existingMeal.morning.manu
      ) {
        updateData["morning.manu"] = incomingMorning.manu;

        clearMorningArrays["morning.studentVotes"] = [];
        clearMorningArrays["morning.guestRequests"] = [];
      }

      // ----------------------------------------------------------
      // Cancellation
      // ----------------------------------------------------------

      if (incomingMorning.isCancelled !== undefined) {
        updateData["morning.isCancelled"] =
          incomingMorning.isCancelled;
      }

      // ----------------------------------------------------------
      // Lock time
      // ----------------------------------------------------------

      if (incomingMorning.lockTime) {
        const timePart =
          incomingMorning.lockTime.includes("T")
            ? incomingMorning.lockTime
                .split("T")[1]
                .substring(0, 5)
            : incomingMorning.lockTime.substring(0, 5);

        const [day, month, year] =
          existingMeal.date.split("/");

        updateData["morning.lockTime"] =
          new Date(
            `${year}-${month}-${day}T${timePart}:00.000Z`
          );
      }

      // ----------------------------------------------------------
      // EXTRA MEAL
      // ----------------------------------------------------------

      if (incomingMorning.isExtraMeal !== undefined) {
        const isExtra =
          incomingMorning.isExtraMeal === true;

        updateData["morning.isExtraMeal"] = isExtra;

        if (isExtra) {
          // Extra meals never participate in 1–60 cycle.
          updateData["morning.mealsNum"] = "0";

          if (
            incomingMorning.extraMealNumber !== undefined
          ) {
            updateData["morning.extraMealNumber"] =
              incomingMorning.extraMealNumber != null
                ? String(incomingMorning.extraMealNumber)
                : null;
          }

          if (incomingMorning.occasion !== undefined) {
            updateData["morning.occasion"] =
              incomingMorning.occasion?.trim() || null;
          }
        } else {
          // Convert extra → normal.
          // recalculateMealNumbers() will assign the correct 1–60 number.
          updateData["morning.mealsNum"] = "0";
          updateData["morning.extraMealNumber"] = null;
          updateData["morning.occasion"] = null;
        }
      } else if (existingMeal.morning.isExtraMeal) {
        // Existing extra meal remains isolated.
        updateData["morning.mealsNum"] = "0";

        if (
          incomingMorning.extraMealNumber !== undefined
        ) {
          updateData["morning.extraMealNumber"] =
            incomingMorning.extraMealNumber != null
              ? String(incomingMorning.extraMealNumber)
              : null;
        }

        if (incomingMorning.occasion !== undefined) {
          updateData["morning.occasion"] =
            incomingMorning.occasion?.trim() || null;
        }
      }
    }

    // ============================================================
    // NIGHT SLOT
    // ============================================================

    if (req.body.night) {
      const incomingNight = req.body.night;

      // ----------------------------------------------------------
      // Menu change
      // ----------------------------------------------------------

      if (
        incomingNight.manu &&
        incomingNight.manu !== existingMeal.night.manu
      ) {
        updateData["night.manu"] = incomingNight.manu;

        clearNightArrays["night.studentVotes"] = [];
        clearNightArrays["night.guestRequests"] = [];
      }

      // ----------------------------------------------------------
      // Cancellation
      // ----------------------------------------------------------

      if (incomingNight.isCancelled !== undefined) {
        updateData["night.isCancelled"] =
          incomingNight.isCancelled;
      }

      // ----------------------------------------------------------
      // Lock time
      // ----------------------------------------------------------

      if (incomingNight.lockTime) {
        const timePart =
          incomingNight.lockTime.includes("T")
            ? incomingNight.lockTime
                .split("T")[1]
                .substring(0, 5)
            : incomingNight.lockTime.substring(0, 5);

        const [day, month, year] =
          existingMeal.date.split("/");

        updateData["night.lockTime"] =
          new Date(
            `${year}-${month}-${day}T${timePart}:00.000Z`
          );
      }

      // ----------------------------------------------------------
      // EXTRA MEAL
      // ----------------------------------------------------------

      if (incomingNight.isExtraMeal !== undefined) {
        const isExtra =
          incomingNight.isExtraMeal === true;

        updateData["night.isExtraMeal"] = isExtra;

        if (isExtra) {
          // Extra meals never participate in 1–60 cycle.
          updateData["night.mealsNum"] = "0";

          if (
            incomingNight.extraMealNumber !== undefined
          ) {
            updateData["night.extraMealNumber"] =
              incomingNight.extraMealNumber != null
                ? String(incomingNight.extraMealNumber)
                : null;
          }

          if (incomingNight.occasion !== undefined) {
            updateData["night.occasion"] =
              incomingNight.occasion?.trim() || null;
          }
        } else {
          // Convert extra → normal.
          updateData["night.mealsNum"] = "0";
          updateData["night.extraMealNumber"] = null;
          updateData["night.occasion"] = null;
        }
      } else if (existingMeal.night.isExtraMeal) {
        // Existing extra meal remains isolated.
        updateData["night.mealsNum"] = "0";

        if (
          incomingNight.extraMealNumber !== undefined
        ) {
          updateData["night.extraMealNumber"] =
            incomingNight.extraMealNumber != null
              ? String(incomingNight.extraMealNumber)
              : null;
        }

        if (incomingNight.occasion !== undefined) {
          updateData["night.occasion"] =
            incomingNight.occasion?.trim() || null;
        }
      }
    }

    // ============================================================
    // BUILD UPDATE PAYLOAD
    // ============================================================

    const finalUpdatePayload = {
      $set: {
        ...updateData,
        ...clearMorningArrays,
        ...clearNightArrays
      }
    };

    // ============================================================
    // SAVE
    // ============================================================

    const updatedMeal = await Meal.findByIdAndUpdate(
      mealId,
      finalUpdatePayload,
      {
        new: true,
        runValidators: true
      }
    );

    // Recalculate normal cycle only.
    await recalculateMealNumbers(
      req.user.hostelId
    );

    // Fetch again so response contains recalculated numbers.
    const finalMeal = await Meal.findById(mealId);

    return res.status(200).json({
      success: true,
      message: "Meal configuration synchronized successfully.",
      meal: finalMeal || updatedMeal
    });

  } catch (error) {
    return res.status(500).json({
      success: false,
      message:
        "Internal server side update process error: " +
        error.message
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
    const { startDate, endDate } = req.query;

    const hostelId = req.user.hostelId;

    // ============================================================
    // 1. EXPLICIT DATE RANGE
    // ============================================================
    if (startDate || endDate) {
      if (!startDate || !endDate) {
        return res.status(400).json({
          success: false,
          message: "Both startDate and endDate are required.",
        });
      }

      const [startDay, startMonth, startYear] = startDate
        .split("/")
        .map(Number);

      const [endDay, endMonth, endYear] = endDate
        .split("/")
        .map(Number);

      const startDateObj = new Date(
        Date.UTC(startYear, startMonth - 1, startDay)
      );

      const endDateObj = new Date(
        Date.UTC(endYear, endMonth - 1, endDay)
      );

      if (
        Number.isNaN(startDateObj.getTime()) ||
        Number.isNaN(endDateObj.getTime())
      ) {
        return res.status(400).json({
          success: false,
          message: "Invalid date format. Use DD/MM/YYYY.",
        });
      }

      if (startDateObj > endDateObj) {
        return res.status(400).json({
          success: false,
          message: "startDate cannot be after endDate.",
        });
      }

      const allMeals = await Meal.find({ hostelId });

      const filteredMeals = allMeals.filter((meal) => {
        const [day, month, year] = meal.date.split("/").map(Number);

        const mealDate = new Date(
          Date.UTC(year, month - 1, day)
        );

        return (
          mealDate >= startDateObj &&
          mealDate <= endDateObj
        );
      });

      filteredMeals.sort((a, b) => {
        const [dayA, monthA, yearA] = a.date.split("/").map(Number);
        const [dayB, monthB, yearB] = b.date.split("/").map(Number);

        const dateA = Date.UTC(yearA, monthA - 1, dayA);
        const dateB = Date.UTC(yearB, monthB - 1, dayB);

        if (dateA !== dateB) {
          return dateA - dateB;
        }

        return (
          new Date(a.createdAt || 0).getTime() -
          new Date(b.createdAt || 0).getTime()
        );
      });

      return res.status(200).json({
        success: true,
        count: filteredMeals.length,
        meals: filteredMeals,
      });
    }

    // ============================================================
    // 2. AUTOMATIC CURRENT 60-MEAL CYCLE
    // ============================================================

    const allMeals = await Meal.find({ hostelId });

    if (!allMeals.length) {
      return res.status(200).json({
        success: true,
        count: 0,
        meals: [],
      });
    }

    // ------------------------------------------------------------
    // Convert DD/MM/YYYY into a comparable UTC timestamp
    // ------------------------------------------------------------
    const getMealDate = (meal) => {
      const [day, month, year] = meal.date.split("/").map(Number);

      return Date.UTC(
        year,
        month - 1,
        day
      );
    };

    // ------------------------------------------------------------
    // Sort daily documents chronologically
    // ------------------------------------------------------------
    allMeals.sort((a, b) => {
      const dateA = getMealDate(a);
      const dateB = getMealDate(b);

      if (dateA !== dateB) {
        return dateA - dateB;
      }

      return (
        new Date(a.createdAt || 0).getTime() -
        new Date(b.createdAt || 0).getTime()
      );
    });

    // ------------------------------------------------------------
    // Build ONLY normal meal slots.
    //
    // Extra meals:
    //   isExtraMeal === true
    //
    // are deliberately excluded from the 1-60 cycle.
    //
    // Cancelled meals:
    //   isCancelled === true
    //
    // are also excluded from the cycle.
    // ------------------------------------------------------------
    const normalMealSlots = [];

    for (const meal of allMeals) {
      const mealDate = getMealDate(meal);

      // Morning
      if (
        meal.morning &&
        meal.morning.isExtraMeal !== true &&
        meal.morning.isCancelled !== true
      ) {
        const mealsNum = Number(meal.morning.mealsNum);

        if (
          Number.isInteger(mealsNum) &&
          mealsNum >= 1 &&
          mealsNum <= 60
        ) {
          normalMealSlots.push({
            mealId: meal._id.toString(),
            date: meal.date,
            dateValue: mealDate,
            slot: "morning",
            mealsNum,
          });
        }
      }

      // Night
      if (
        meal.night &&
        meal.night.isExtraMeal !== true &&
        meal.night.isCancelled !== true
      ) {
        const mealsNum = Number(meal.night.mealsNum);

        if (
          Number.isInteger(mealsNum) &&
          mealsNum >= 1 &&
          mealsNum <= 60
        ) {
          normalMealSlots.push({
            mealId: meal._id.toString(),
            date: meal.date,
            dateValue: mealDate,
            slot: "night",
            mealsNum,
          });
        }
      }
    }

    // ------------------------------------------------------------
    // No normal meals available
    // ------------------------------------------------------------
    if (normalMealSlots.length === 0) {
      return res.status(200).json({
        success: true,
        count: 0,
        meals: [],
      });
    }

    // ------------------------------------------------------------
    // Find today's date.
    //
    // We compare only the calendar date, not the current time.
    // ------------------------------------------------------------
    const now = new Date();

    const todayStart = Date.UTC(
      now.getFullYear(),
      now.getMonth(),
      now.getDate()
    );

    // ------------------------------------------------------------
    // Find the reference meal.
    //
    // Priority:
    //   1. Latest normal meal today
    //   2. Latest normal meal before today
    //   3. Latest normal meal available
    // ------------------------------------------------------------
    let referenceIndex = -1;

    for (let i = normalMealSlots.length - 1; i >= 0; i--) {
      if (normalMealSlots[i].dateValue === todayStart) {
        referenceIndex = i;
        break;
      }
    }

    if (referenceIndex === -1) {
      for (let i = normalMealSlots.length - 1; i >= 0; i--) {
        if (normalMealSlots[i].dateValue < todayStart) {
          referenceIndex = i;
          break;
        }
      }
    }

    if (referenceIndex === -1) {
      referenceIndex = normalMealSlots.length - 1;
    }

    // ------------------------------------------------------------
    // Determine the 60-meal cycle.
    //
    // Example:
    //
    // slots 0  - 59  = cycle 1
    // slots 60 - 119 = cycle 2
    // slots 120-179 = cycle 3
    //
    // Extra meals never enter this array.
    // ------------------------------------------------------------
    const cycleStartIndex =
      Math.floor(referenceIndex / 60) * 60;

    const cycleEndIndex = Math.min(
      cycleStartIndex + 59,
      normalMealSlots.length - 1
    );

    const cycleSlots = normalMealSlots.slice(
      cycleStartIndex,
      cycleEndIndex + 1
    );

    if (cycleSlots.length === 0) {
      return res.status(200).json({
        success: true,
        count: 0,
        meals: [],
      });
    }

    // ------------------------------------------------------------
    // Determine the calendar date range of this 60-meal cycle.
    // ------------------------------------------------------------
    const cycleStartDate =
      cycleSlots[0].dateValue;

    const cycleEndDate =
      cycleSlots[cycleSlots.length - 1].dateValue;

    // ------------------------------------------------------------
    // Return DAILY documents whose date falls inside the cycle.
    //
    // This is intentional.
    //
    // A Meal document contains BOTH:
    //   morning
    //   night
    //
    // Therefore we return the whole daily document instead of
    // returning only individual slots.
    //
    // Extra meals inside this date range are automatically included.
    // ------------------------------------------------------------
    const targetMeals = allMeals.filter((meal) => {
      const mealDate = getMealDate(meal);

      return (
        mealDate >= cycleStartDate &&
        mealDate <= cycleEndDate
      );
    });

    // ------------------------------------------------------------
    // Final chronological sorting
    // ------------------------------------------------------------
    targetMeals.sort((a, b) => {
      const dateA = getMealDate(a);
      const dateB = getMealDate(b);

      if (dateA !== dateB) {
        return dateA - dateB;
      }

      return (
        new Date(a.createdAt || 0).getTime() -
        new Date(b.createdAt || 0).getTime()
      );
    });

    // ------------------------------------------------------------
    // Response
    // ------------------------------------------------------------
    return res.status(200).json({
      success: true,
      count: targetMeals.length,
      meals: targetMeals,
    });
  } catch (error) {
    console.error("Error fetching meals:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to fetch meals.",
      error: error.message,
    });
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