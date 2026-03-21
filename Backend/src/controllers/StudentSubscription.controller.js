import StudentSubscription from "../models/StudentSubscription.js";
import MealPlan from "../models/MealPlan.js";
import Fine from "../models/fine.model.js";
import User from "../models/User.js"

export const selectPackage = async (req, res) => {
    try {
        const { planId, currentMonth } = req.body;
        const studentId = req.user._id || req.user.id;
        const hostelId = req.user.hostelId;

        const newPlan = await MealPlan.findById(planId);
        if (!newPlan) return res.status(404).json({ success: false, message: "Plan not found" });

        // 1. Check for existing subscription that is NOT 'completed'
        // If it's active or pending, we treat it as the current plan.
        // If it's completed, we allow the student to create a brand new one.
        const existingSub = await StudentSubscription.findOne({ 
            studentId, 
            month: currentMonth,
            status: { $in: ["pending", "active"] } // Ignore 'completed' plans
        });

        let finalPrice = newPlan.monthlyPrice;
        let isUpgrade = false;

        // 2. Validation Logic
        if (existingSub) {
            // Check if they are trying to go from 30 -> 60 (Upgrade)
            if (existingSub.planType === "30 meals" && newPlan.planType === "60 meals") {
                finalPrice = newPlan.monthlyPrice - existingSub.amount;
                isUpgrade = true;
            } else if (existingSub.planType === newPlan.planType) {
                return res.status(400).json({
                    success: false,
                    message: "You already have this plan active for this month."
                });
            } else {
                return res.status(400).json({
                    success: false,
                    message: "Current subscription must be completed or upgraded from 30 to 60 meals."
                });
            }
        }

        // 3. Create or Update Subscription
        // If isUpgrade is true, we update the existing pending/active one.
        // If isUpgrade is false, it means existingSub is null (either none exists or previous was completed)
        let subscription;
        if (isUpgrade) {
            subscription = await StudentSubscription.findByIdAndUpdate(
                existingSub._id,
                {
                    mealsPlanId: newPlan._id,
                    planType: newPlan.planType,
                    amount: newPlan.monthlyPrice,
                    maxLimits: newPlan.limits,
                    status: "pending", 
                },
                { new: true }
            );
        } else {
            // CREATE NEW (This handles both first-time and re-buying after 'completed')
            subscription = await StudentSubscription.create({
                studentId,
                hostelId,
                month: currentMonth,
                mealsPlanId: newPlan._id,
                planType: newPlan.planType,
                amount: newPlan.monthlyPrice,
                maxLimits: newPlan.limits,
                status: "pending",
                usage: { chicken: 0, fish: 0, paneer: 0, mutton: 0, egg: 0, veg: 0 }
            });
        }

        const manager = await User.findOne({ hostelId, role: "manager" });
        if (!manager) return res.status(404).json({ success: false, message: "Manager not found" });

        // 4. Create the Bill
        const fineBill = await Fine.create({
            studentId,
            managerId: manager._id,
            hostelId,
            title: isUpgrade ? `Plan Upgrade (${currentMonth})` : `Mess Bill - ${newPlan.planType}`,
            amount: finalPrice,
            description: isUpgrade ? `Upgrade difference for 60 meals.` : `New monthly subscription.`,
            isMealPackage: true,
            subscriptionId: subscription._id,
            status: "pending"
        });

        res.status(200).json({
            success: true,
            message: isUpgrade ? "Upgrade request sent!" : "Plan selected! Pay bill to activate.",
            subscription,
            bill: fineBill
        });

    } catch (error) {
        console.error("Select Package Error:", error);
        res.status(500).json({ success: false, message: error.message });
    }
};

export const getAllSubscriptions = async (req, res) => {
    try {
        const studentId = req.user._id || req.user.id;
        const hostelId = req.user.hostelId;

        // Sort by createdAt descending (-1) so the newest plan is first
        const subscriptions = await StudentSubscription.find({
            studentId: studentId,
            hostelId: hostelId
        }).sort({ createdAt: -1 }); 

        res.status(200).json({
            success: true,
            count: subscriptions.length,
            data: subscriptions
        });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};