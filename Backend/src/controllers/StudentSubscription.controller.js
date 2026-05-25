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
        if (!newPlan) {
            return res.status(404).json({ success: false, message: "Requested meal subscription plan package template map not found." });
        }

        // 1. Fetch the latest running subscription 
        const activeSub = await StudentSubscription.findOne({
            studentId,
            hostelId,
            status: { $in: ["pending", "active"] }
        });

        let finalPrice = newPlan.monthlyPrice;
        let isUpgrade = false;

        // 2. Evaluate structural upgrade constraints against active/pending states
        if (activeSub) {
            const currentSubPrice = activeSub.monthlyPrice || activeSub.amount || 0;

            // Lock block constraint if user has an active "60 veg meals" subscription running
            if (activeSub.planType === "60 veg meals") {
                return res.status(400).json({
                    success: false,
                    message: "Modifying your running subscription style is restricted. Changing plans while on 60 Veg Meals is not permitted."
                });
            }

            if (activeSub.planType === "30 meals" && newPlan.planType === "60 meals") {
                // Valid Upgrade Path Matrix
                finalPrice = newPlan.monthlyPrice - currentSubPrice;
                isUpgrade = true;
            } else if (activeSub.planType === newPlan.planType) {
                return res.status(400).json({
                    success: false,
                    message: "You already have this subscription layout tier actively configured on your profile."
                });
            } else {
                return res.status(400).json({
                    success: false,
                    message: "Modifying your running subscription style is restricted. Only 30 to 60 meals upgrade paths are permitted."
                });
            }
        }

        // 3. Process Document Pipeline (Mutate active/pending tracking frame vs Create fresh block for completed tiers)
        let subscription;
        if (isUpgrade && activeSub) {
            // UPDATE: Target the running pending/active profile layout block
            subscription = await StudentSubscription.findByIdAndUpdate(
                activeSub._id,
                {
                    mealsPlanId: newPlan._id,
                    planType: newPlan.planType,
                    monthlyPrice: newPlan.monthlyPrice,
                    amount: newPlan.monthlyPrice,
                    maxLimits: newPlan.limits,
                    status: "pending", // Reset lock state flag indicators until verification payment passes
                    ...(currentMonth ? { month: currentMonth } : {})
                },
                { new: true }
            );
        } else {
            // CREATE: Executes if no subscription exists OR if the previous matching query layer hit a "completed" status block
            subscription = await StudentSubscription.create({
                studentId,
                hostelId,
                month: currentMonth || "Ongoing",
                mealsPlanId: newPlan._id,
                planType: newPlan.planType,
                monthlyPrice: newPlan.monthlyPrice,
                amount: newPlan.monthlyPrice,
                maxLimits: newPlan.limits,
                status: "pending",
                usage: { chicken: 0, fish: 0, paneer: 0, mutton: 0, egg: 0, veg: 0 }
            });
        }

        // 4. Generate Account Statement Invoice (Fine framework)
        // ✅ Quiet background lookup without returning 404 block closures if manager is missing
        const manager = await User.findOne({ hostelId, role: "manager" });

        // Fallback safety to prevent validation crashes while fulfilling required database patterns
        const assignedManagerId = manager ? manager._id : studentId;

        const fineBill = await Fine.create({
            studentId,
            managerId: assignedManagerId, // Pass safe identity parameter pointer directly
            hostelId,
            title: isUpgrade ? `Plan Upgrade Fee` : `Mess Bill - ${newPlan.planType}`,
            amount: finalPrice,
            description: isUpgrade
                ? `Upgrade transition tier price delta calculation transaction execution step balance adjustment invoice.`
                : `New baseline standard monthly meal package subscription statement invocation profile configuration framework.`,
            isMealPackage: true,
            subscriptionId: subscription._id,
            status: "pending"
        });

        return res.status(200).json({
            success: true,
            message: isUpgrade
                ? "Upgrade request created successfully! Clear checkout invoice payment step options to finalize activation changes."
                : "Plan selected! Complete checkout verification to confirm active running status profile blocks changes.",
            subscription,
            bill: fineBill
        });

    } catch (error) {
        console.error("Select Package Matrix Runtime Processing Failure Error Stack Log:", error);
        return res.status(500).json({ success: false, message: "System pipeline compilation handler failure execution context dropped: " + error.message });
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




// Backend Node.js Controller
export const getManagerSubscriptions = async (req, res) => {
    try {
        const hostelId = req.user.hostelId; // From manager's token

        // Fetch ALL subscriptions for this hostel and populate student info
        const subscriptions = await StudentSubscription.find({ hostelId })
            .populate("studentId", "name regNum department roomNumber")
            .populate("mealsPlanId", "planName")
            .sort({ createdAt: -1 }); // Newest first

        res.status(200).json({
            success: true,
            count: subscriptions.length,
            data: subscriptions
        });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
};


// Update a student's subscription (Manager Only)
// export const updateSubscriptionByManager = async (req, res) => {
//     try {
//         const { id } = req.params; // The ID of the StudentSubscription
//         const { planId, status } = req.body;
//         const hostelId = req.user.hostelId;

//         // 1. Find the subscription
//         const subscription = await StudentSubscription.findOne({ _id: id, hostelId });
//         if (!subscription) {
//             return res.status(404).json({ success: false, message: "Subscription not found" });
//         }

//         // 2. If the manager is changing the plan type (e.g., 60 meals down to 30 meals)
//         if (planId && planId !== subscription.mealsPlanId.toString()) {
//             const newPlan = await MealPlan.findOne({ _id: planId, hostelId });
//             if (!newPlan) {
//                 return res.status(404).json({ success: false, message: "New meal plan not found" });
//             }

//             // Completely override the current plan with the new plan's data
//             subscription.mealsPlanId = newPlan._id;
//             subscription.planType = newPlan.planType;
//             subscription.amount = newPlan.monthlyPrice;
//             subscription.maxLimits = newPlan.limits;
//         }

//         // 3. Update the status if changed
//         if (status) {
//             subscription.status = status;
//         }

//         await subscription.save();

//         res.status(200).json({ 
//             success: true, 
//             message: "Subscription successfully updated!", 
//             data: subscription 
//         });

//     } catch (error) {
//         console.error("Update Subscription Error:", error);
//         res.status(500).json({ success: false, message: error.message });
//     }
// };



export const updateSubscriptionByManager = async (req, res) => {
    try {
        const { id } = req.params; // The ID of the StudentSubscription
        const { planId, status } = req.body;
        const hostelId = req.user.hostelId;
        const managerId = req.user._id || req.user.id; // Safely get manager ID

        // 1. Find the existing subscription
        const subscription = await StudentSubscription.findOne({ _id: id, hostelId });
        if (!subscription) {
            return res.status(404).json({ success: false, message: "Subscription not found" });
        }

        // 2. If the manager is changing the plan type
        if (planId && planId !== subscription.mealsPlanId.toString()) {
            const newPlan = await MealPlan.findOne({ _id: planId, hostelId });
            if (!newPlan) {
                return res.status(404).json({ success: false, message: "New meal plan not found" });
            }

            const oldPlanType = subscription.planType;
            const newPrice = newPlan.monthlyPrice;

            // ==========================================
            // ✨ SMART FINE & BILLING LOGIC (NO CREATION/DELETION) ✨
            // ==========================================

            // Find the existing fine associated with this subscription
            const existingFine = await Fine.findOne({
                subscriptionId: subscription._id,
                isMealPackage: true
            });

            if (existingFine) {
                // Safely update ONLY the billing details. 
                // The paymentScreenshot and status remain completely untouched!
                existingFine.title = `Mess Bill - ${newPlan.planType}`;
                existingFine.amount = newPrice;
                existingFine.description = `Manager updated plan from ${oldPlanType} to ${newPlan.planType}.`;
                existingFine.MealPlanID = newPlan._id;

                await existingFine.save();
            }
            // ==========================================

            // Safely update the current subscription plan's data
            subscription.mealsPlanId = newPlan._id;
            subscription.planType = newPlan.planType;
            subscription.amount = newPrice;
            subscription.maxLimits = newPlan.limits;
        }

        // 3. Update the status if changed
        if (status) {
            subscription.status = status;
        }

        // Save the updated subscription
        await subscription.save();

        res.status(200).json({
            success: true,
            message: "Subscription and billing successfully updated without losing data!",
            data: subscription
        });

    } catch (error) {
        console.error("Update Subscription Error:", error);
        res.status(500).json({ success: false, message: error.message });
    }
};



// ==========================================
// DELETE SUBSCRIPTION (Manager Only)
// ==========================================
export const deleteSubscriptionByManager = async (req, res) => {
    try {
        const { id } = req.params;
        const hostelId = req.user.hostelId;

        // 1. Find and delete the subscription, ensuring it belongs to this manager's hostel
        const deletedSub = await StudentSubscription.findOneAndDelete({
            _id: id,
            hostelId: hostelId
        });

        if (!deletedSub) {
            return res.status(404).json({ success: false, message: "Subscription not found or already deleted." });
        }

        // 2. ✨ NEW: Automatically delete any fines associated with this subscription
        await Fine.deleteMany({
            subscriptionId: deletedSub._id
        });

        res.status(200).json({
            success: true,
            message: "Subscription and associated bills successfully deleted."
        });

    } catch (error) {
        console.error("Delete Subscription Error:", error);
        res.status(500).json({ success: false, message: error.message });
    }
};