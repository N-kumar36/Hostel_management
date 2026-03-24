import StudentSubscription from "../models/StudentSubscription.js";
import MealPlan from "../models/MealPlan.js";
import Fine from "../models/fine.model.js"; // Verify this exact filename is correct
import User from "../models/User.js"

export const selectPackage = async (req, res) => {
    try {
        const { planId, currentMonth } = req.body;
        const studentId = req.user._id || req.user.id;
        const hostelId = req.user.hostelId;

        const newPlan = await MealPlan.findById(planId);
        if (!newPlan) return res.status(404).json({ success: false, message: "Plan not found" });

        // 1. Fetch ONLY Active or Pending subscriptions for this month.
        // We do NOT care about 'completed' ones because they are allowed to buy a new one.
        const activeSub = await StudentSubscription.findOne({
            studentId,
            month: currentMonth,
            status: { $in: ["pending", "active"] }
        });

        let finalPrice = newPlan.monthlyPrice;
        let isUpgrade = false;

        // 2. Validate against existing ACTIVE/PENDING plans
        if (activeSub) {
            if (activeSub.planType === "30 meals" && newPlan.planType === "60 meals") {
                // It's a valid upgrade
                finalPrice = newPlan.monthlyPrice - activeSub.amount;
                isUpgrade = true;
            } else if (activeSub.planType === newPlan.planType) {
                return res.status(400).json({
                    success: false,
                    message: "You already have this plan active for this month."
                });
            } else {
                return res.status(400).json({
                    success: false,
                    message: "You cannot change your active subscription unless upgrading from 30 to 60 meals."
                });
            }
        }

        // 3. Create or Update
        let subscription;
        if (isUpgrade && activeSub) {
            // Update the existing active/pending one
            subscription = await StudentSubscription.findByIdAndUpdate(
                activeSub._id,
                {
                    mealsPlanId: newPlan._id,
                    planType: newPlan.planType,
                    amount: newPlan.monthlyPrice, // The total value of the new plan
                    maxLimits: newPlan.limits,
                    status: "pending", // Lock the plan until the upgrade fee is paid
                },
                { new: true }
            );
        } else {
            // CREATE NEW 
            // This happens if it's the first plan of the month, OR if their previous plan was 'completed'
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

        // 4. Generate the Bill
        const manager = await User.findOne({ hostelId, role: "manager" });
        if (!manager) return res.status(404).json({ success: false, message: "Manager not found" });

        const fineBill = await Fine.create({
            studentId,
            managerId: manager._id,
            hostelId,
            title: isUpgrade ? `Plan Upgrade (${currentMonth})` : `Mess Bill - ${newPlan.planType}`,
            amount: finalPrice, // The actual amount they owe right now
            description: isUpgrade ? `Upgrade difference for 60 meals.` : `New monthly subscription.`,
            isMealPackage: true,
            subscriptionId: subscription._id,
            status: "pending"
        });

        res.status(200).json({
            success: true,
            message: isUpgrade ? "Upgrade request sent! Pay bill to activate." : "Plan selected! Pay bill to activate.",
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