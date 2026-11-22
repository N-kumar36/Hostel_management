import mongoose from "mongoose";
import dotenv from "dotenv";

import Meal from "../models/Meal.js";
import MealCycleCounter from "../models/MealCycleCounter.js";

dotenv.config();

const MONGO_URI = process.env.MONGO_URI || process.env.DATABASE_URL;

if (!MONGO_URI) {
  throw new Error(
    "MongoDB connection string is missing. Set MONGO_URI or DATABASE_URL in .env"
  );
}

// ------------------------------------------------------------
// Convert DD/MM/YYYY into a real Date
// ------------------------------------------------------------
const parseMealDate = (dateString) => {
  if (!dateString) {
    return new Date(0);
  }

  const [day, month, year] = dateString
    .split("/")
    .map(Number);

  return new Date(
    Date.UTC(
      year,
      month - 1,
      day
    )
  );
};

// ------------------------------------------------------------
// Get all normal active slots from a Meal document.
//
// IMPORTANT:
// Morning and night are treated as two separate meal slots.
// The global sequence is maintained across both slots.
// ------------------------------------------------------------
const getNormalSlots = (meal) => {
  const slots = [];

  if (
    meal.morning &&
    meal.morning.isExtraMeal !== true &&
    meal.morning.isCancelled !== true
  ) {
    slots.push({
      meal,
      slotName: "morning",
      slot: meal.morning,
    });
  }

  if (
    meal.night &&
    meal.night.isExtraMeal !== true &&
    meal.night.isCancelled !== true
  ) {
    slots.push({
      meal,
      slotName: "night",
      slot: meal.night,
    });
  }

  return slots;
};

// ------------------------------------------------------------
// Main migration
// ------------------------------------------------------------
const migrateMealCycles = async () => {
  console.log("==============================================");
  console.log(" Meal Cycle Migration");
  console.log("==============================================");

  await mongoose.connect(MONGO_URI);

  console.log("Connected to MongoDB.");

  const meals = await Meal.find({}).lean();

  console.log(
    `Found ${meals.length} Meal documents.`
  );

  // ----------------------------------------------------------
  // Sort daily Meal documents chronologically.
  // createdAt is used as a secondary ordering value.
  // ----------------------------------------------------------
  meals.sort((a, b) => {
    const dateA = parseMealDate(a.date);
    const dateB = parseMealDate(b.date);

    if (dateA.getTime() !== dateB.getTime()) {
      return dateA.getTime() - dateB.getTime();
    }

    return (
      new Date(a.createdAt || 0).getTime() -
      new Date(b.createdAt || 0).getTime()
    );
  });

  // ----------------------------------------------------------
  // Group normal slots by hostel.
  // ----------------------------------------------------------
  const hostelSlots = new Map();

  for (const meal of meals) {
    if (!meal.hostelId) {
      continue;
    }

    const normalSlots = getNormalSlots(meal);

    if (normalSlots.length === 0) {
      continue;
    }

    const hostelKey =
      meal.hostelId.toString();

    if (!hostelSlots.has(hostelKey)) {
      hostelSlots.set(hostelKey, []);
    }

    hostelSlots
      .get(hostelKey)
      .push(...normalSlots);
  }

  console.log(
    `Found ${hostelSlots.size} hostel(s) containing normal meals.`
  );

  // ----------------------------------------------------------
  // Process each hostel independently.
  // ----------------------------------------------------------
  for (const [
    hostelId,
    slots
  ] of hostelSlots.entries()) {
    console.log("");
    console.log("----------------------------------------------");
    console.log(`Processing hostel: ${hostelId}`);
    console.log(
      `Normal meal slots: ${slots.length}`
    );

    let mealNumber = 0;
    let cycleNumber = 1;

    const bulkOperations = [];

    // --------------------------------------------------------
    // Rebuild the sequence from the remaining historical data.
    //
    // 1, 2, 3 ... 60
    // then
    // cycle 2 → 1, 2, 3 ... 60
    // --------------------------------------------------------
    for (const item of slots) {
      mealNumber++;

      if (mealNumber > 60) {
        mealNumber = 1;
        cycleNumber++;
      }

      bulkOperations.push({
        updateOne: {
          filter: {
            _id: item.meal._id,
          },
          update: {
            $set: {
              [`${item.slotName}.mealsNum`]:
                String(mealNumber),

              [`${item.slotName}.cycleNumber`]:
                cycleNumber,
            },
          },
        },
      });

      console.log(
        `${item.meal.date} | ${item.slotName} | #${mealNumber} | cycle ${cycleNumber}`
      );
    }

    // --------------------------------------------------------
    // Update Meal documents in bulk.
    // --------------------------------------------------------
    if (bulkOperations.length > 0) {
      await Meal.bulkWrite(
        bulkOperations,
        {
          ordered: true,
        }
      );
    }

    // --------------------------------------------------------
    // Update the persistent counter.
    //
    // This is the LAST assigned normal meal for this hostel.
    // --------------------------------------------------------
    await MealCycleCounter.findOneAndUpdate(
      {
        hostelId,
      },
      {
        $set: {
          cycleNumber,
          mealNumber,
        },
      },
      {
        upsert: true,
        new: true,
        setDefaultsOnInsert: true,
      }
    );

    console.log(
      `Counter initialized → cycle ${cycleNumber}, meal ${mealNumber}`
    );
  }

  console.log("");
  console.log("==============================================");
  console.log(" Migration completed successfully.");
  console.log("==============================================");

  await mongoose.disconnect();

  console.log("Disconnected from MongoDB.");
};

// ------------------------------------------------------------
// Run
// ------------------------------------------------------------
migrateMealCycles()
  .catch(async (error) => {
    console.error("");
    console.error("Migration failed:");
    console.error(error);

    try {
      await mongoose.disconnect();
    } catch (_) {}

    process.exit(1);
  });