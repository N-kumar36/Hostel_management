import mongoose from "mongoose";

const voteSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
  hostelId: { type: mongoose.Schema.Types.ObjectId, ref: "Hostel", required: true },
  mealId: { type: mongoose.Schema.Types.ObjectId, ref: "Meal", required: true },
  timeSlot: { type: String, enum: ["morning", "night"], required: true },
  mealType: { type: String, required: true }, 
  
  //  Guest Specific Fields
  isGuest: { type: Boolean, default: false },
  // guestName stores "Guest 1 (Nitya)", "Guest 2 (Nitya)", etc.
  guestName: { type: String, default: null }, 
  guestMealId: { type: mongoose.Schema.Types.ObjectId, ref: "GuestMeal" },

  votedAt: { type: Date, default: Date.now },
  isServed: { type: Boolean, default: false },
  servedAt: Date
});

//  FIX: Include guestName in the unique index.
// This allows a student to have one regular vote (where guestName is null)
// AND multiple guest votes (where each guestName is unique).
voteSchema.index(
  { userId: 1, mealId: 1, timeSlot: 1, isGuest: 1, guestName: 1 }, 
  { unique: true }
);

export default mongoose.model("Vote", voteSchema);