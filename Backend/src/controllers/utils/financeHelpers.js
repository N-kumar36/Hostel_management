import Meal from "../../models/Meal.js";
import Fine from "../../models/fine.model.js";
import ShoppingItem from "../../models/shopping.model.js";

/**
 * 1. Fetches and aggregates meal consumption logs within a date range
 */
export const getActiveMealsAndConsumption = async (hostelId, trueStartDate, trueEndDate) => {
    const allMeals = await Meal.find({ hostelId: hostelId })
        .populate("morning.studentVotes.userId night.studentVotes.userId", "name email");

    const activeMeals = allMeals.filter(meal => {
        const [d, m, y] = meal.date.split("/");
        const mealDate = new Date(`${y}-${m}-${d}T00:00:00.000Z`);
        return mealDate >= trueStartDate && mealDate <= trueEndDate;
    });

    const targetCycleDates = activeMeals.map((m) => m.date);

    let totalMealsCount = 0;
    const usageAggregatorMap = {};

    activeMeals.forEach((mealDoc) => {
        ["morning", "night"].forEach((slot) => {
            if (mealDoc[slot] && mealDoc[slot].studentVotes) {
                mealDoc[slot].studentVotes.forEach((vote) => {
                    if (vote.isServed && vote.userId) {
                        totalMealsCount++;
                        const studentId = vote.userId._id.toString();

                        if (!usageAggregatorMap[studentId]) {
                            usageAggregatorMap[studentId] = { consumed: 0 };
                        }
                        usageAggregatorMap[studentId].consumed += 1;
                    }
                });
            }
        });
    });

    return { totalMealsCount, targetCycleDates, usageAggregatorMap };
};

/**
 * 2. Fetches fines and converts them to the Flutter usage list format
 */
export const getStudentFinesAndUsage = async (hostelId, trueStartDate, trueEndDate, usageAggregatorMap) => {
    // 1. Fetch all fines for the hostel inside your date coordinates
    const activeFinesWithStudentInfo = await Fine.find({
        hostelId: hostelId,
        date: { $gte: trueStartDate, $lte: trueEndDate }
    }).populate("studentId", "name email photoURL");

    let totalIncomePool = 0;
    let pendingIncomePool = 0;
    const finalizedStudentUsageList = [];

    // 2. Loop directly over the unique database records instead of a combined email map!
    activeFinesWithStudentInfo.forEach((fine) => {
        if (!fine.studentId) return; // Safeguard if user profile is missing

        const studentIdStr = fine.studentId._id.toString();
        // Look up meal consumption tally safely
        const dynamicMealData = usageAggregatorMap[studentIdStr];

        // Calculate totals dynamically per record status string directly
        if (fine.status === "success") {
            totalIncomePool += (fine.amount || 0);
        } else if (fine.status === "pending" || fine.status === "processing") {
            pendingIncomePool += (fine.amount || 0);
        }

        // Build object pushing raw fields directly from the unique record
        finalizedStudentUsageList.push({
            _id: fine._id,
            name: fine.studentId.name || "Unknown Student",
            email: fine.studentId.email || "No Email",
            photoURL: fine.studentId.photoURL || "",
            title: fine.title || "Hostel Fine Charges",
            description: fine.description || "",
            consumed: dynamicMealData ? dynamicMealData.consumed : 0,
            amount: fine.amount || 0,
            status: fine.status, // Holds the exact matching status per individual fine record
            isMealPackage: fine.isMealPackage,
            paymentScreenshot: fine.paymentScreenshot || null,
            paymentMethod: fine.paymentMethod || null
        });
    });

    console.log("Calculated Income Pools Exactly:", { totalIncomePool, pendingIncomePool });

    return { totalIncomePool, pendingIncomePool, finalizedStudentUsageList };
};
/**
 * 3. Fetches and parses grocery/procurement shopping expenses matching meal dates
 */

export const getProcurementExpenses = async (hostelId, targetCycleDates) => {
    // Fetch items belonging to the hostel and populate the manager's name
    const targetedProcurements = await ShoppingItem.find({ hostelId: hostelId })
        .populate("createdBy", "name");

    console.log("Fetched Procurements for Hostel:", hostelId, targetedProcurements.length);

    const filteredProcurements = targetedProcurements.filter((item) => {
        if (!item.dateTime) return false;

        try {
            // Safely extract the date part if it contains a timestamp separator (e.g., "YYYY-MM-DD, 12:00")
            const cleanItemDate = item.dateTime.includes(",")
                ? item.dateTime.split(",")[0].trim()
                : item.dateTime.trim();

            const parsedItemTime = new Date(cleanItemDate);
            if (isNaN(parsedItemTime.getTime())) return false; // Skip if date string is invalid

            // Check if the item date matches any of the meal dates in the active cycle
            return targetCycleDates.some((mealDate) => {
                const [d, m, y] = mealDate.split("/");
                const comparisonMealDate = new Date(`${y}-${m}-${d}`);
                return parsedItemTime.toDateString() === comparisonMealDate.toDateString();
            });
        } catch (err) {
            console.error(`Failed parsing item time for ID: ${item._id}`, err);
            return false;
        }
    });

    // Sum total expenses for items actually bought
    const totalSpentExpenses = filteredProcurements
        .filter((item) => item.isBought === true)
        .reduce((sum, item) => sum + (item.price || 0), 0);

    // Format final structure expected by Flutter
    const formattedProcurements = filteredProcurements.map(item => ({
        _id: item._id,
        name: item.name,
        description: item.description || "",
        price: item.price,
        isBought: item.isBought,
        dateTime: item.dateTime ? item.dateTime.split(",")[0].trim() : "",
        createdBy: item.createdBy ? item.createdBy.name : "System Manager"
    }));

    return { totalSpentExpenses, formattedProcurements };
};