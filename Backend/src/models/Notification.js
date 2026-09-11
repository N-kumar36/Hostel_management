import mongoose from "mongoose";

const notificationSchema = new mongoose.Schema(
  {
    // =====================================================
    // NOTIFICATION OWNER
    // =====================================================
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    // =====================================================
    // HOSTEL
    // =====================================================
    hostelId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Hostel",
      required: true,
    },

    // =====================================================
    // CONTENT
    // =====================================================
    title: {
      type: String,
      required: true,
      trim: true,
    },

    message: {
      type: String,
      required: true,
      trim: true,
    },

    // =====================================================
    // NOTIFICATION TYPE
    // =====================================================
    type: {
      type: String,

      enum: [
        // Existing types
        "vote",
        "payment",
        "served",
        "notice",
        "alert",

        // Meal events
        "meal_cancelled",
        "meal_served",
        "take_your_meal",
        "meal_balance_warning",

        // Cycle events
        "new_cycle",

        // Meeting
        "meeting_arranged",

        // Manager / gate
        "gate_closed",
      ],

      default: "notice",
    },

    // =====================================================
    // READ STATUS
    // =====================================================
    isRead: {
      type: Boolean,
      default: false,
    },

    // Exact time notification was read
    readAt: {
      type: Date,
      default: null,
    },

    // =====================================================
    // CREATED TIME
    // =====================================================
    createdAt: {
      type: Date,
      default: Date.now,
    },
  }
);


// =========================================================
// TTL INDEX
// =========================================================
// MongoDB automatically deletes a notification
// 3 days after it has been marked as read.
//
// 3 days = 259200 seconds
//
// IMPORTANT:
// readAt is null for unread notifications,
// so unread notifications are NOT deleted by this TTL.
// =========================================================
notificationSchema.index(
  { readAt: 1 },
  { expireAfterSeconds: 259200 }
);


export default mongoose.model(
  "Notification",
  notificationSchema
);