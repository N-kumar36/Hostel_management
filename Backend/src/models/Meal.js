import mongoose from "mongoose";


// --- 1. Embedded Student Personal Vote Sub-Schema ---
const embeddedStudentVoteSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "User",
    required: true
  },
  itemPreference: {
    type: String,
    enum: ["regular", "halal_chicken", "egg_substitute", "veg_forced"],
    default: "regular",
    required: true
  },
  finalAllocatedMenu: {
    type: String,
    required: true
  },
  votedAt: { type: Date, default: Date.now },
  isServed: { type: Boolean, default: false },

  //  FIX: Diubah menjadi array object history untuk mencatat log aktivitas pelayanan manager
  servedByHistory: [
    {
      managerId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
        required: true
      },
      action: {
        type: String,
        enum: ["serve", "unserve"], // Mencatat apakah dia menyajikan atau membatalkan
        required: true
      },
      changedAt: {
        type: Date,
        default: Date.now
      }
    }
  ],
  servedAt: Date // Menyimpan tanggal penyajian terakhir rill
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
    studentVotes: [embeddedStudentVoteSchema],
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
      type: String,
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

export default mongoose.models.Meal || mongoose.model("Meal", dailyMealSchema);