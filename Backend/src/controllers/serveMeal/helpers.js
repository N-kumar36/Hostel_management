import FinePrice from "../../models/FinePrice.js"; 
import StudentSubscription from "../../models/StudentSubscription.js"; 

/**
 * Normalizes different variations of menu text to match finePrice schema keys
 */
export const normalizeMenuKey = (menuType) => {
  let key = menuType.toLowerCase();
  if (key.includes("chicken")) return "chicken";
  if (key.includes("egg")) return "egg";
  if (key !== "paneer" && key !== "fish" && key !== "mutton") return "veg";
  return key;
};

/**
 * Fetches setup configuration parameters and active subscriptions in parallel
 */
export const loadCycleContext = async (studentId, hostelId) => {
  const [priceDoc, subscription] = await Promise.all([
    FinePrice.findOne({ hostelId }).lean(),
    StudentSubscription.findOne({
      studentId,
      hostelId,
      status: { $in: ["pending", "active", "completed"] }
    }).sort({ createdAt: -1 })
  ]);

  const defaultFallbacks = { veg: 35, egg: 45, paneer: 45, chicken: 65, fish: 55, mutton: 85 };
  return { priceDoc, subscription, defaultFallbacks };
};

/**
 * Checks if a subscription package is completed or expired (older than 60 days)
 */
export const evaluateSubscriptionStatus = async (subscription) => {
  let forceFineBilling = false;
  let fineReasonDescription = "";

  if (subscription) {
    const purchaseDate = new Date(subscription.createdAt);
    const differenceInDays = (Date.now() - purchaseDate.getTime()) / (1000 * 3600 * 24);

    if (differenceInDays > 60) {
      if (subscription.status !== "completed") {
        await StudentSubscription.updateOne({ _id: subscription._id }, { $set: { status: "completed" } });
      }
      forceFineBilling = true;
      fineReasonDescription = "Student subscription package has exceeded its 60-day validity window and is expired.";
    }

    if (subscription.status === "completed") {
      forceFineBilling = true;
      if (!fineReasonDescription) {
        fineReasonDescription = "Student has an already completed/exhausted subscription package layout.";
      }
    }
  } else {
    forceFineBilling = true;
    fineReasonDescription = "Student has no subscription history context found.";
  }

  return { forceFineBilling, fineReasonDescription };
};