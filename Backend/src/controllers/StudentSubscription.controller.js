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