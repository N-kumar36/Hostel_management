import MealPrice from "../models/mealPrice.model.js";

/**
 * @desc    Get the price table for the manager's hostel
 * @route   GET /api/fine/price-table
 */
export const getMealPrices = async (req, res) => {
    try {
        const hostelId = req.user.hostelId;

        console.log("getMealPrices", hostelId)

        let priceTable = await MealPrice.findOne({ hostelId });

        // If no table exists yet, create one with defaults
        if (!priceTable) {
            priceTable = await MealPrice.create({
                hostelId,
                prices: {
                    veg: 35,
                    egg: 45,
                    paneer: 45,
                    chicken: 65,
                    fish: 55,
                    mutton: 85
                }
            });
        }

        res.status(200).json({
            success: true,
            data: priceTable,
        });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};

/**
 * @desc    Update or Set new prices (Dynamic Items allowed)
 * @route   POST /api/fine/price-table
 */
export const setMealPrices = async (req, res) => {
    try {
        const hostelId = req.user.hostelId;
        const { baseFee, prices } = req.body;

        console.log("setMealPrices" );

        if (typeof prices !== 'object') {
            return res.status(400).json({ success: false, message: "Invalid prices format" });
        }

        // We use findOne and then manual update to ensure Map keys are handled properly by Mongoose
        let priceTable = await MealPrice.findOne({ hostelId });

        if (priceTable) {
            priceTable.baseFee = baseFee;
            priceTable.prices = prices; // Mongoose Map handles object assignment
            priceTable.updatedAt = Date.now();
            await priceTable.save();
        } else {
            priceTable = await MealPrice.create({
                hostelId,
                baseFee,
                prices,
                updatedAt: Date.now()
            });
        }

        res.status(200).json({
            success: true,
            message: "Price table updated successfully",
            data: priceTable,
        });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};