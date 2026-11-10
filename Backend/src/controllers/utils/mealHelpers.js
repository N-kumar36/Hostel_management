import Meal from "../../models/Meal.js";

export const recalculateMealNumbers = async (hostelId) => {
  // Fetch all documents for this hostel.
  const allMeals = await Meal.find({ hostelId });

  // Sort chronologically.
  allMeals.sort((a, b) => {
    const [dayA, monthA, yearA] = a.date.split("/").map(Number);
    const [dayB, monthB, yearB] = b.date.split("/").map(Number);

    const dateA = new Date(yearA, monthA - 1, dayA);
    const dateB = new Date(yearB, monthB - 1, dayB);

    if (dateA.getTime() !== dateB.getTime()) {
      return dateA - dateB;
    }

    // Secondary fallback: creation time.
    return (a.createdAt || 0) - (b.createdAt || 0);
  });

  let sequentialCounter = 0;

  for (const meal of allMeals) {
    let modified = false;

    // ============================================================
    // MORNING
    // ============================================================

    if (meal.morning.isExtraMeal === true) {
      // Extra/occasion meals NEVER participate in the 1–60 cycle.
      // Their number is stored separately in extraMealNumber.

      if (meal.morning.mealsNum !== "0") {
        meal.morning.mealsNum = "0";
        modified = true;
      }
    } else if (!meal.morning.isCancelled) {
      sequentialCounter++;

      // Normal 60-meal cycle:
      // 1, 2, 3, ... 58, 59, 60, 1, 2, ...
      const relativeNum = ((sequentialCounter - 1) % 60) + 1;

      if (meal.morning.mealsNum !== relativeNum.toString()) {
        meal.morning.mealsNum = relativeNum.toString();
        modified = true;
      }
    } else {
      if (meal.morning.mealsNum !== "0") {
        meal.morning.mealsNum = "0";
        modified = true;
      }
    }

    // ============================================================
    // NIGHT
    // ============================================================

    if (meal.night.isExtraMeal === true) {
      // Extra/occasion meals NEVER participate in the 1–60 cycle.
      // Their number is stored separately in extraMealNumber.

      if (meal.night.mealsNum !== "0") {
        meal.night.mealsNum = "0";
        modified = true;
      }
    } else if (!meal.night.isCancelled) {
      sequentialCounter++;

      const relativeNum = ((sequentialCounter - 1) % 60) + 1;

      if (meal.night.mealsNum !== relativeNum.toString()) {
        meal.night.mealsNum = relativeNum.toString();
        modified = true;
      }
    } else {
      if (meal.night.mealsNum !== "0") {
        meal.night.mealsNum = "0";
        modified = true;
      }
    }

    if (modified) {
      await meal.save();
    }
  }
};