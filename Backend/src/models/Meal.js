import mongoose from "mongoose";

// --- 1. Embedded Student Personal Vote Sub-Schema ---
const embeddedStudentVoteSchema = new mongoose.Schema({
  userId: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: "User", 
    required: true 
  },
  // ✨ NEW: Tracks the exact item variation the student selected to eat
  itemPreference: {
    type: String,
    enum: [
      "regular",        // Eats whatever default menu item is set by the manager
      "halal_chicken",  // Selects Halal version (Only valid if base menu is chicken)
      "egg_substitute", // Opts for Egg instead of the default Chicken/Fish/Mutton/Paneer
      "veg_forced"      // Forces a fallback Veg plate for that specific slot
    ],
    default: "regular",
    required: true
  },
  // Saved string snapshot showing exactly what item variation they are being prepared
  finalAllocatedMenu: { 
    type: String, 
    required: true 
  },
  votedAt: { type: Date, default: Date.now },
  isServed: { type: Boolean, default: false },
  servedAt: Date
});

// --- 2. Embedded Guest Request Sub-Schema ---
const embeddedGuestRequestSchema = new mongoose.Schema({
  studentId: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: "User", 
    required: true 
  },
  guestCount: { 
    type: Number, 
    required: true, 
    min: 1 
  },
  // ✨ NEW: Guests can also specify special plate variations
  guestItemPreference: {
    type: String,
    enum: ["regular", "halal_chicken", "egg_substitute", "veg_forced"],
    default: "regular"
  },
  status: { 
    type: String, 
    enum: ["pending", "approved", "rejected"], 
    default: "pending" 
  },
  requestedAt: { type: Date, default: Date.now },
  approvedAt: Date
});

// --- 3. Slot Time Configuration Wrapper ---
const mealTimeSlotSchema = new mongoose.Schema(
  {
    manu: {
      type: String,
      enum: ["veg", "egg", "paneer", "chicken", "fish", "mutton"],
      required: true,
    },
    mealsNum: { type: String, default: "0" }, 
    lockTime: { type: Date, required: true },
    isLocked: { type: Boolean, default: false },
    isCancelled: { type: Boolean, default: false },
    
    // Personal votes for this specific time slot
    studentVotes: [embeddedStudentVoteSchema],
    
    // Guest requests specifically for this time slot (Morning OR Night)
    guestRequests: [embeddedGuestRequestSchema]
  },
  { _id: false }
);

// --- 4. Master Daily Document ---
const dailyMealSchema = new mongoose.Schema(
  {
    hostelId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Hostel",
      required: true,
    },
    date: {
      type: String, // Format: "DD/MM/YYYY"
      required: true,
    },
    morning: {
      type: mealTimeSlotSchema,
      required: true,
    },
    night: {
      type: mealTimeSlotSchema,
      required: true,
    },
  },
  { timestamps: true }
);

// --- Compound Indexes ---
dailyMealSchema.index({ hostelId: 1, date: 1 }, { unique: true });
dailyMealSchema.index({ hostelId: 1, date: 1, "morning.studentVotes.userId": 1 }, { unique: true, sparse: true });
dailyMealSchema.index({ hostelId: 1, date: 1, "night.studentVotes.userId": 1 }, { unique: true, sparse: true });

export default mongoose.model("Meal", dailyMealSchema);