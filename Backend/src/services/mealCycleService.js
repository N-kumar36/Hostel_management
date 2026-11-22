import MealCycleCounter from "../models/MealCycleCounter.js";

/**
 * Get the current counter for a hostel.
 *
 * If the hostel does not have a counter yet, create one.
 */
export const getMealCycleCounter = async (hostelId) => {
  let counter = await MealCycleCounter.findOne({ hostelId });

  if (!counter) {
    try {
      counter = await MealCycleCounter.create({
        hostelId,
        cycleNumber: 1,
        mealNumber: 0,
      });
    } catch (error) {
      // Another request may have created it at the same time.
      // Try fetching it again.
      if (error.code === 11000) {
        counter = await MealCycleCounter.findOne({ hostelId });
      } else {
        throw error;
      }
    }
  }

  return counter;
};

/**
 * Reserve the next normal meal number.
 *
 * Sequence:
 *
 * 1  → 2 → 3 → ... → 59 → 60
 * 60 → 1  (new cycle)
 *
 * Extra meals and cancelled meals MUST NOT call this function.
 */
export const reserveNextMealNumber = async (hostelId) => {
  // Make sure the counter document exists.
  await getMealCycleCounter(hostelId);

  /*
   * Atomically increment the meal number.
   *
   * If the current number is below 60:
   *     mealNumber + 1
   *
   * If the current number is already 60:
   *     mealNumber becomes 1
   *     cycleNumber becomes cycleNumber + 1
   *
   * The condition is evaluated by MongoDB itself, so concurrent
   * requests cannot both reserve the same number.
   */
  const counter = await MealCycleCounter.findOneAndUpdate(
    {
      hostelId,
      mealNumber: { $lt: 60 },
    },
    {
      $inc: {
        mealNumber: 1,
      },
    },
    {
      new: true,
    }
  );

  // Normal case: 1 → 60
  if (counter) {
    return {
      mealsNum: String(counter.mealNumber),
      cycleNumber: counter.cycleNumber,
    };
  }

  /*
   * Current mealNumber must be 60.
   *
   * Atomically:
   *   60 → 1
   *   cycle 1 → cycle 2
   */
  const newCycleCounter = await MealCycleCounter.findOneAndUpdate(
    {
      hostelId,
      mealNumber: 60,
    },
    {
      $set: {
        mealNumber: 1,
      },
      $inc: {
        cycleNumber: 1,
      },
    },
    {
      new: true,
    }
  );

  if (!newCycleCounter) {
    /*
     * Extremely unlikely race-condition protection.
     *
     * Another request may have already moved the counter
     * into the next cycle.
     */
    const currentCounter = await getMealCycleCounter(hostelId);

    return {
      mealsNum: String(currentCounter.mealNumber),
      cycleNumber: currentCounter.cycleNumber,
    };
  }

  return {
    mealsNum: String(newCycleCounter.mealNumber),
    cycleNumber: newCycleCounter.cycleNumber,
  };
};

/**
 * Get the current meal cycle without changing it.
 */
export const getCurrentMealCycle = async (hostelId) => {
  return getMealCycleCounter(hostelId);
};