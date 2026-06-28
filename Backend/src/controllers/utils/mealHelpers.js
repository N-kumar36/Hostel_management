import Meal from "../../models/Meal.js";


export const recalculateMealNumbers = async (hostelId) => {
  // 1. Fetch all documents for this specific hostel
  const allMeals = await Meal.find({ hostelId });

  // 2. Sort them accurately in JavaScript using true date comparison operations
  allMeals.sort((a, b) => {
    const [dayA, monthA, yearA] = a.date.split("/").map(Number);
    const [dayB, monthB, yearB] = b.date.split("/").map(Number);

    const dateA = new Date(yearA, monthA - 1, dayA);
    const dateB = new Date(yearB, monthB - 1, dayB);

    if (dateA.getTime() !== dateB.getTime()) {
      return dateA - dateB;
    }
    // Secondary fallback sorting parameter if dates match exactly
    return (a.createdAt || 0) - (b.createdAt || 0);
  });

  let sequentialCounter = 0;

  for (let meal of allMeals) {
    let modified = false;

    // --- Process Morning Slot ---
    if (!meal.morning.isCancelled) {
      sequentialCounter++;
      // Reset count back to 1 when hitting package maximum baseline cycle limits (e.g., 61 becomes 1)
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

    // --- Process Night Slot ---
    if (!meal.night.isCancelled) {
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