import Fine from "../../models/fine.model.js";
import StudentSubscription from "../../models/StudentSubscription.js";

/**
 * Manages fine creations or reversals depending on availability flags
 */
export const handleFineAccounting = async ({
  isNowServed, studentId, activeManagerId, currentHostelId, 
  subscriptionKey, finalBilledAmount, forceFineBilling, fineReasonDescription, subscription
}) => {
  let fineGenerated = false;

  if (isNowServed) {
    const currentUsage = subscription?.usage?.[subscriptionKey] || 0;
    const maxAllowed = subscription?.maxLimits?.[subscriptionKey] || 0;

    if (forceFineBilling || currentUsage >= maxAllowed) {
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
export const syncSubscriptionQuota = async (subscription, isNowServed, subscriptionKey, forceFineBilling) => {
  if (!forceFineBilling && subscription && (subscription.status === "active" || subscription.status === "pending")) {
    const incValue = isNowServed ? 1 : -1;
    
    if (!(!isNowServed && (subscription.usage[subscriptionKey] || 0) <= 0)) {
      const updatedSub = await StudentSubscription.findByIdAndUpdate(
        subscription._id,
        { $set: { [`usage.${subscriptionKey}`]: (subscription.usage[subscriptionKey] || 0) + incValue } },
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
  } else if (!isNowServed && subscription && forceFineBilling && subscription.status === "completed") {
    const totalUsedNow = ["veg", "chicken", "fish", "egg", "paneer", "mutton"]
      .reduce((sum, key) => sum + (subscription.usage[key] || 0), 0);

    const purchaseDate = new Date(subscription.createdAt);
    const differenceInDays = (Date.now() - purchaseDate.getTime()) / (1000 * 3600 * 24);

    if (totalUsedNow < subscription.totalMealsBought && differenceInDays <= 60) {
      await StudentSubscription.updateOne({ _id: subscription._id }, { $set: { status: "active" } });
    }
  }
};

