import Fine from "../../models/fine.model.js";
import StudentSubscription from "../../models/StudentSubscription.js";

/**
 * Manages fine creations or reversals depending on availability flags
 */
export const handleFineAccounting = async ({
  isNowServed, studentId, activeManagerId, currentHostelId, 
  subscriptionKey, baseMenuKey, finalBilledAmount, forceFineBilling, fineReasonDescription, subscription
}) => {
  let fineGenerated = false;

  if (isNowServed) {
    // Determine dynamic max allowed limits reflecting active real-time updates
    const currentUsage = subscription?.usage?.[subscriptionKey] || 0;
    const maxAllowed = subscription?.maxLimits?.[subscriptionKey] || 0;

    // Check if a dynamic swap is possible (so they won't get fined)
    const isSwapEligible = subscriptionKey !== baseMenuKey && subscriptionKey !== "veg" && baseMenuKey !== "veg";
    const canSwap = isSwapEligible && (subscription?.maxLimits?.[baseMenuKey] || 0) > 0;

    // Only apply fine if they are out of alternative limits AND cannot swap/borrow from base menu
    if ((forceFineBilling || currentUsage >= maxAllowed) && !canSwap) {
      await Fine.create({
        studentId,
        managerId: activeManagerId, 
        hostelId: currentHostelId,
        title: forceFineBilling 
          ? `Walk-in Charge (Expired/Completed) - ${subscriptionKey.toUpperCase()}` 
          : `Extra Meal Charge - ${subscriptionKey.toUpperCase()}`,
        amount: finalBilledAmount,
        description: forceFineBilling ? fineReasonDescription : `Limit for ${subscriptionKey} was ${maxAllowed}. Charged for exceeding plan quota bounds.`,
        status: "pending",
        isMealPackage: false,
        date: new Date()
      });
      fineGenerated = true;
    }
  } else {
    await Fine.findOneAndDelete({
      studentId,
      hostelId: currentHostelId,
      status: "pending",
      title: { $regex: new RegExp(subscriptionKey, "i") }
    });
  }
  return fineGenerated;
};

/**
 * Handles package meal balancing, increments, or decrements atomically
 */
export const syncSubscriptionQuota = async (subscription, isNowServed, subscriptionKey, baseMenuKey, forceFineBilling) => {
  if (forceFineBilling || !subscription || (subscription.status !== "active" && subscription.status !== "pending")) {
    // Restore active state if completed and we are unserving
    if (!isNowServed && subscription && forceFineBilling && subscription.status === "completed") {
      const totalUsedNow = ["veg", "chicken", "fish", "egg", "paneer", "mutton"]
        .reduce((sum, key) => sum + (subscription.usage[key] || 0), 0);

      const purchaseDate = new Date(subscription.createdAt);
      const differenceInDays = (Date.now() - purchaseDate.getTime()) / (1000 * 3600 * 24);

      if (totalUsedNow < subscription.totalMealsBought && differenceInDays <= 60) {
        await StudentSubscription.updateOne({ _id: subscription._id }, { $set: { status: "active" } });
      }
    }
    return;
  }

  const usageInc = isNowServed ? 1 : -1;
  const updateQuery = { $inc: {} };

  // Alternate preference limit swapping (e.g. transfer limit from chicken -> egg)
  // Swapping rules: alternative chosen, neither key is veg, and max values stay >= 0
  const isSwapEligible = subscriptionKey !== baseMenuKey && subscriptionKey !== "veg" && baseMenuKey !== "veg";

  if (isSwapEligible) {
    if (isNowServed) {
      const baseMax = subscription.maxLimits?.[baseMenuKey] || 0;
      if (baseMax > 0) {
        // Decrement base limit by 1, increment alternative limit by 1
        updateQuery.$inc[`maxLimits.${baseMenuKey}`] = -1;
        updateQuery.$inc[`maxLimits.${subscriptionKey}`] = 1;
        console.log(`[QUOTA SWAP] Transferring 1 limit token from ${baseMenuKey} to ${subscriptionKey}`);
      }
    } else {
      const chosenMax = subscription.maxLimits?.[subscriptionKey] || 0;
      if (chosenMax > 0) {
        // Reverse swap: decrement alternative limit by 1, increment base limit by 1
        updateQuery.$inc[`maxLimits.${subscriptionKey}`] = -1;
        updateQuery.$inc[`maxLimits.${baseMenuKey}`] = 1;
        console.log(`[QUOTA SWAP REVERSAL] Restoring 1 limit token from ${subscriptionKey} to ${baseMenuKey}`);
      }
    }
  }

  // Handle standard usage increment/decrement
  if (!(!isNowServed && (subscription.usage[subscriptionKey] || 0) <= 0)) {
    updateQuery.$inc[`usage.${subscriptionKey}`] = usageInc;

    const updatedSub = await StudentSubscription.findByIdAndUpdate(
      subscription._id,
      updateQuery,
      { new: true }
    );

    if (updatedSub) {
      const totalUsedNow = ["veg", "chicken", "fish", "egg", "paneer", "mutton"]
        .reduce((sum, key) => sum + (updatedSub.usage[key] || 0), 0);

      if (totalUsedNow >= updatedSub.totalMealsBought) {
        await StudentSubscription.updateOne({ _id: subscription._id }, { $set: { status: "completed" } });
      }
    }
  }
};