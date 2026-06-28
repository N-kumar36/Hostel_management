import ShoppingItem from "../models/shopping.model.js";
// 🌟 FIX: Updated path from "./messpaymenttracker/paymentTracker.js" to "./messPaymentTracker/paymentTracker.js"
// This matches the exact case-sensitive folder name on your GitHub/Vercel server!
import { calculateCurrentCycleBudget } from "./messPaymentTracker/paymentTracker.js";
import moment from "moment-timezone"; 

/**
 * @desc    Helper utility to generate formatted server date-time string
 * @returns {String} e.g., "18 Jun 2026, 12:59 AM"
 */
const getServerFormattedDateTime = () => {
    // Standardizes string creation via moment-timezone matching your server profile context
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
        const { hostelId } = req.user;

        if (!hostelId) {
            return res.status(400).json({
                success: false,
                message: "Hostel context missing from user authentication token.",
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
            createdBy: req.user._id,
            hostelId: req.user.hostelId,
        });

        res.status(201).json({
            success: true,
            message: "Item added to mess procurement list successfully.",
            data: newItem,
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

        // 1. Get live cycle metrics and income from successful student collections
        const { activeDates, collectedFineFunds } = await calculateCurrentCycleBudget(hostelId);

        // 2. Fetch all raw items belonging to this hostel
        const allItems = await ShoppingItem.find({ hostelId })
            .populate("createdBy", "name")
            .sort({ createdAt: -1 });

        // 3. Filter items matching your specific string date layout using Moment safely
        const filteredItems = allItems.filter((item) => {
            if (!item.dateTime) return false;

            // Extract "18 Jun 2026" from "18 Jun 2026, 12:59 AM" safely
            const cleanItemDateStr = item.dateTime.split(",")[0].trim();

            // Parse custom formats by supplying explicit mapping arguments to Moment
            const itemMoment = moment.tz(cleanItemDateStr, "DD MMM YYYY", "Asia/Kolkata");
            if (!itemMoment.isValid()) return false;

            return activeDates.some((mealDateStr) => {
                // Safely translate "18/06/2026" to compare day blocks across structural timestamps
                const mealMoment = moment.tz(mealDateStr, "DD/MM/YYYY", "Asia/Kolkata");
                return itemMoment.isSame(mealMoment, 'day'); // Precise calendar day comparison logic
            });
        });

        // 4. Calculate total money spent on bought items
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