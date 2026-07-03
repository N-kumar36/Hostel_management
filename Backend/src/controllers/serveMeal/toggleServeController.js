import mongoose from "mongoose";
import Meal from "../../models/Meal.js";
import { normalizeMenuKey, loadCycleContext, evaluateSubscriptionStatus } from "./helpers.js";
import { handleFineAccounting, syncSubscriptionQuota } from "./walkInService.js";

/**
 * @desc    Toggle Serving status entry points
 * @route   POST /api/vote/toggle-serve
 */
export const toggleServeStatus = async (req, res) => {
  try {
    const { studentId, mealDate, timeSlot } = req.body;
    const currentHostelId = req.user.hostelId;
    const targetSlot = timeSlot.toLowerCase();
    
    const rawManagerId = req.user._id || req.user.id; 
    if (!rawManagerId) {
      return res.status(401).json({ success: false, message: "Unauthorized. Manager context missing." });
    }
    const activeManagerId = new mongoose.Types.ObjectId(rawManagerId);

    if (!studentId || !mealDate || !timeSlot) {
      return res.status(400).json({ success: false, message: "Missing required query fields." });
    }

    // 1. Fetch current document configuration matrices 
    const mealDoc = await Meal.findOne({ date: mealDate, hostelId: currentHostelId });
    if (!mealDoc) return res.status(404).json({ success: false, message: "Meal schedule entry matrix missing." });

    const slotBlock = mealDoc[targetSlot];
    const existingVote = slotBlock.studentVotes.find(v => v.userId.toString() === studentId.toString());
    
    let isNowServed = false;
    let currentMealType = slotBlock.manu;
    let voteId = "";

    // 2. Perform Atomic Update modifications depending on structural layout paths
    if (!existingVote) {
      const newWalkIn = {
        userId: new mongoose.Types.ObjectId(studentId),
        itemPreference: "regular",
        finalAllocatedMenu: slotBlock.manu, 
        isServed: true,
        servedBy: activeManagerId,
        servedAt: new Date(),
        votedAt: new Date()
      };
      
      slotBlock.studentVotes.push(newWalkIn);
      await mealDoc.save();

      const freshVote = slotBlock.studentVotes.find(v => v.userId.toString() === studentId.toString());
      isNowServed = true;
      voteId = freshVote ? freshVote._id : "";
    } else {
      // ➔ REGISTERED VOTE MODE
      isNowServed = !existingVote.isServed;
      currentMealType = existingVote.finalAllocatedMenu;
      voteId = existingVote._id;

      const historyLog = {
        managerId: activeManagerId,
        action: isNowServed ? "serve" : "unserve",
        changedAt: new Date()
      };

      // Atomic deep embedded update securely targeting dynamic array index paths
      await Meal.updateOne(
        { date: mealDate, hostelId: currentHostelId, [`${targetSlot}.studentVotes.userId`]: new mongoose.Types.ObjectId(studentId) },
        { 
          $set: { 
            [`${targetSlot}.studentVotes.$.isServed`]: isNowServed,
            [`${targetSlot}.studentVotes.$.servedAt`]: isNowServed ? new Date() : existingVote.servedAt 
          },
          $push: {
            [`${targetSlot}.studentVotes.$.servedByHistory`]: historyLog 
          }
        }
      );
    }

    // 3. Resolve Financial Context Profiles & normalization keys
    const subscriptionKey = normalizeMenuKey(currentMealType);
    const baseMenuKey = normalizeMenuKey(slotBlock.manu);

    const { priceDoc, subscription, defaultFallbacks } = await loadCycleContext(studentId, currentHostelId);
    const finalBilledAmount = priceDoc?.prices?.[subscriptionKey] || defaultFallbacks[subscriptionKey];

    // 4. Validate Validity expiration state blocks
    const { forceFineBilling, fineReasonDescription } = await evaluateSubscriptionStatus(subscription);

    // 5. Compute Fines Ledger operations
    const fineGenerated = await handleFineAccounting({
      isNowServed, studentId, activeManagerId, currentHostelId,
      subscriptionKey, baseMenuKey, finalBilledAmount, forceFineBilling, fineReasonDescription, subscription
    });

    // 6. Recalculate Quota and Balance allocations 
    await syncSubscriptionQuota(subscription, isNowServed, subscriptionKey, baseMenuKey, forceFineBilling);

    return res.status(200).json({
      success: true,
      message: isNowServed
        ? (forceFineBilling
          ? `Billed as Extra: Pack status is Expired/Completed. Invoice of ₹${finalBilledAmount} generated!`
          : (fineGenerated ? `Extra ${subscriptionKey.toUpperCase()} served. Fine of ₹${finalBilledAmount} generated!` : `Marked ${subscriptionKey.toUpperCase()} as served`))
        : `Un-served ${subscriptionKey.toUpperCase()}. System records synchronized cleanly.`,
      isServed: isNowServed,
      mealType: currentMealType,
      voteId: voteId
    });

  } catch (error) {
    console.error("Critical Toggle Serve Flow Failure:", error);
    return res.status(500).json({ success: false, message: "Internal Server Error: " + error.message });
  }
};