import ShoppingItem from "../models/shopping.model.js";
import Meal from "../models/Meal.js";
import StudentSubscription from "../models/StudentSubscription.js";
import Fine from "../models/fine.model.js";
import mongoose from "mongoose";
import moment from "moment-timezone";

/**
 * @desc    Helper utility to calculate budget matching the current live 1-60 meal cycle window
 */
const calculateCurrentCycleBudget = async (hostelId) => {
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

/**
 * @desc    Helper utility to calculate cycle budget for any specific historical or past cycle date bounds
 */
const calculateCycleBudgetByDateRange = async (hostelId, startDateStr, endDateStr) => {
    try {
        const startMoment = moment.tz(startDateStr, "DD/MM/YYYY", "Asia/Kolkata").startOf('day');
        const endMoment = moment.tz(endDateStr, "DD/MM/YYYY", "Asia/Kolkata").endOf('day');

        // Fetch meals belonging to this hostel and filter matching day blocks
        const meals = await Meal.find({ hostelId }).lean();
        const activeMeals = meals.filter(m => {
            const mealMoment = moment.tz(m.date, "DD/MM/YYYY", "Asia/Kolkata");
            return mealMoment.isSameOrAfter(startMoment) && mealMoment.isSameOrBefore(endMoment);
        });

        const activeDates = activeMeals.map(m => m.date);

        // Fetch subscriptions created during this cycle timeframe
        const subscriptionsInPeriod = await StudentSubscription.find({
            hostelId: hostelId,
            createdAt: {
                $gte: startMoment.toDate(),
                $lte: endMoment.toDate()
            }
        }).select("_id");

        const subIds = subscriptionsInPeriod.map(sub => sub._id);

        // Aggregate successful payments linked to these cycle subscriptions
        const collectedFines = await Fine.aggregate([
            {
                $match: {
                    hostelId: new mongoose.Types.ObjectId(hostelId),
                    subscriptionId: { $in: subIds },
                    status: "success"
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
        console.error("Budget date range tracking error:", error);
        throw error;
    }
};

/**
 * @desc    Helper utility to generate formatted server date-time string
 * @returns {String} e.g., "18 Jun 2026, 12:59 AM"
 */
const getServerFormattedDateTime = () => {
    return moment().tz("Asia/Kolkata").format("DD MMM YYYY, hh:mm A");
};

/**
 * @desc    Create a new shopping/procurement item
 * @route   POST /api/shopping
 * @access  Private (Protect, Manager, Approved)
 */
export const createShoppingList = async (req, res) => {
    try {
        const { name, description, price, isBought } = req.body;
        const hostelId = req.user?.hostelId;
        const userId = req.user?._id || req.user?.id;

        if (!hostelId) {
            return res.status(400).json({
                success: false,
                message: "Hostel context missing from user authentication token.",
            });
        }

        if (!userId) {
            return res.status(401).json({
                success: false,
                message: "Unauthorized. Session context missing.",
            });
        }

        if (!name || price === undefined) {
            return res.status(400).json({
                success: false,
                message: "Please include both an item name and estimated price calculation.",
            });
        }

        const serverDateTime = getServerFormattedDateTime();

        const newItem = await ShoppingItem.create({
            name,
            description,
            price: Number(price),
            isBought: isBought || false,
            dateTime: serverDateTime,
            createdBy: userId,
            hostelId: hostelId,
        });

        const populatedItem = await ShoppingItem.findById(newItem._id)
            .populate("createdBy", "name")
            .lean();

        res.status(201).json({
            success: true,
            message: "Item added to mess procurement list successfully.",
            data: populatedItem,
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: "Server error creating shopping item logs.",
            error: error.message,
        });
    }
};

/**
 * @desc    Get shopping items and calculate loop finances
 * @route   GET /api/shopping
 * @access  Private
 */
export const getShoppingList = async (req, res) => {
    try {
        const hostelId = req.user.hostelId || req.body.hostelId;

        if (!hostelId) {
            return res.status(400).json({
                success: false,
                message: "Hostel context missing from request header parameters.",
            });
        }

        const { startDateStr, endDateStr } = req.query;

        let activeDates = [];
        let collectedFineFunds = 0;

        // Determine cycle parameters based on client query
        if (startDateStr && endDateStr && startDateStr !== 'null' && endDateStr !== 'null') {
            const result = await calculateCycleBudgetByDateRange(hostelId, startDateStr, endDateStr);
            activeDates = result.activeDates;
            collectedFineFunds = result.collectedFineFunds;
        } else {
            const result = await calculateCurrentCycleBudget(hostelId);
            activeDates = result.activeDates;
            collectedFineFunds = result.collectedFineFunds;
        }

        // Fetch all raw items belonging to this hostel
        const allItems = await ShoppingItem.find({ hostelId })
            .populate("createdBy", "name")
            .sort({ createdAt: -1 });

        // Filter items matching your specific string date layout using Moment safely
        const filteredItems = allItems.filter((item) => {
            if (!item.dateTime) return false;

            // Extract "18 Jun 2026" from "18 Jun 2026, 12:59 AM" safely
            const cleanItemDateStr = item.dateTime.split(",")[0].trim();

            const itemMoment = moment.tz(cleanItemDateStr, "DD MMM YYYY", "Asia/Kolkata");
            if (!itemMoment.isValid()) return false;

            return activeDates.some((mealDateStr) => {
                const mealMoment = moment.tz(mealDateStr, "DD/MM/YYYY", "Asia/Kolkata");
                return itemMoment.isSame(mealMoment, 'day');
            });
        });

        // Calculate total money spent on bought items
        const totalSpentOnItems = filteredItems
            .filter(item => item.isBought === true)
            .reduce((sum, item) => sum + (item.price || 0), 0);

        res.status(200).json({
            success: true,
            finances: {
                totalMoney: collectedFineFunds,
                spendMoney: totalSpentOnItems,
                remainingBalance: collectedFineFunds - totalSpentOnItems
            },
            count: filteredItems.length,
            data: filteredItems,
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: "Error processing contextual loop shopping calculations.",
            error: error.message,
        });
    }
};

/**
 * @desc    Update an item completely or toggle purchase complete status
 * @route   PUT /api/shopping/:id
 * @access  Private (Protect, Manager, Approved)
 */
export const updateShoppingList = async (req, res) => {
    try {
        const { id } = req.params;
        const updates = req.body;

        if (updates.price !== undefined) {
            updates.price = Number(updates.price);
        }

        const updatedItem = await ShoppingItem.findByIdAndUpdate(
            id,
            { $set: updates },
            { new: true, runValidators: true }
        );

        if (!updatedItem) {
            return res.status(404).json({
                success: false,
                message: "Target procurement document item could not be found.",
            });
        }

        res.status(200).json({
            success: true,
            message: "Procurement record updated successfully.",
            data: updatedItem,
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: "Server structural processing error modifying target item details.",
            error: error.message,
        });
    }
};

/**
 * @desc    Remove an item permanently from procurement collections
 * @route   DELETE /api/shopping/:id
 * @access  Private (Protect, Manager, Approved)
 */
export const deleteShoppingList = async (req, res) => {
    try {
        const { id } = req.params;
        const targetItem = await ShoppingItem.findByIdAndDelete(id);

        if (!targetItem) {
            return res.status(404).json({
                success: false,
                message: "Target procurement item was missing or deleted previously.",
            });
        }

        res.status(200).json({
            success: true,
            message: "Item removed from the mess procurement registry successfully.",
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: "Server side error deleting shopping item profile.",
            error: error.message,
        });
    }
};