import MealPlan from "../models/MealPlan.js";
import StudentSubscription from "../models/StudentSubscription.js";

export const getMealPlans = async (req, res) => {
  try {
    const studentId = req.user._id;
    const hostelId = req.user.hostelId;

    // 1. Fetch standard packages configuration matrices as lean plain JS objects
    const basePlans = await MealPlan.find({ hostelId }).lean();

    // 2. Scan if this specific student has an open, unfinished subscription status
    const activeSub = await StudentSubscription.findOne({
      studentId,
      hostelId,
      status: { $in: ["active", "pending"] }
    });

    // --- CONDITION 1: Student has NO active or pending subscription plan ---
    if (!activeSub) {
      const responseData = basePlans.map(plan => ({
        ...plan,
        isUpgradeOption: false,
        isDowngradeOption: false,
        isActivePlan: false,
        originalPrice: plan.monthlyPrice
      }));

      return res.status(200).json({
        success: true,
        data: responseData
      });
    }

    // Capture parameters from the currently running subscription
    const currentPrice = activeSub.monthlyPrice || activeSub.amount || 0;
    const currentPlanType = activeSub.planType;

    // --- CONDITION 2: Student ALREADY has an active plan running ---
    const dynamicPlans = basePlans.map(plan => {
      const targetPrice = plan.monthlyPrice;

      // Initialize state tracking variables
      let adjustedPrice = targetPrice;
      let isUpgradeOption = false;
      let isDowngradeOption = false;
      let isActivePlan = false;

      // Rule A: Identify if this exact item is what they are currently on
      if (currentPlanType === plan.planType) {
        isActivePlan = true;
      }
      // Rule B: If current plan is "60 veg meals", disable all updates/upgrades for everything else
      else if (currentPlanType === "60 veg meals") {
        isDowngradeOption = true;
        isUpgradeOption = false;
      }
      // Rule C: If current plan is "30 meals", check its targets carefully
      else if (currentPlanType === "30 meals") {
        if (plan.planType === "60 meals") {
          // Allowed path: Upgrade to premium mixed 60 meals
          isUpgradeOption = true;
          adjustedPrice = targetPrice - currentPrice; // Calculate price delta (e.g. ₹500)
        } else {
          // Blocked path: Cannot side-grade from 30 meals over to 60 veg meals dynamically
          isDowngradeOption = true;
          isUpgradeOption = false;
        }
      }
      // Rule D: Fallback calculation for standard tier financial adjustments
      else if (targetPrice > currentPrice) {
        isUpgradeOption = true;
        adjustedPrice = targetPrice - currentPrice;
      }
      else {
        isDowngradeOption = true;
      }

      return {
        ...plan,
        monthlyPrice: adjustedPrice,          // Maps directly to pkg['monthlyPrice'] in Flutter
        originalPrice: targetPrice,           // Original baseline reference price
        isActivePlan,
        isUpgradeOption,
        isDowngradeOption
      };
    });

    return res.status(200).json({
      success: true,
      data: dynamicPlans
    });

  } catch (error) {
    return res.status(500).json({
      success: false,
      message: "Failed to generate dynamic meal configurations: " + error.message
    });
  }
};