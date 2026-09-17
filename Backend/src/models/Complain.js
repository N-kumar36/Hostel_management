import mongoose from "mongoose";

const complainSchema = new mongoose.Schema(
  {
    studentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    hostelId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Hostel",
      required: true,
    },

    // ============================================================
    // REQUEST TYPE
    // ============================================================

    requestType: {
      type: String,
      enum: [
        "Complaint",
        "App Problem",
        "Suggestion",
        "Meeting",
      ],
      default: "Complaint",
      required: true,
    },

    // ============================================================
    // CATEGORY
    // ============================================================

    category: {
      type: String,
      enum: [
        // Complaint
        "Food Quality",
        "Hygiene Issue",
        "Staff Behavior",
        "Meal Timing",
        "Mess Facilities",

        // App Problem
        "Login / Authentication",
        "Meal Voting",
        "Profile Problem",
        "Notification Problem",
        "Photo Upload Problem",
        "App Crash / Bug",

        // Suggestion
        "Food / Menu",
        "Mess Management",
        "App Improvement",
        "Hostel Facility",
        "New Feature",

        // Meeting
        "Mess Committee Discussion",
        "Food / Menu Discussion",
        "Hostel Issue",
        "Personal Discussion",
        "App / Technical Discussion",
        "Suggestion Discussion",

        // Common
        "Other",
      ],
      required: true,
    },

    // ============================================================
    // DESCRIPTION
    // ============================================================

    description: {
      type: String,
      required: true,
      trim: true,
    },

    // ============================================================
    // MEETING DETAILS
    // ============================================================

    meetingDate: {
      type: Date,
      default: null,
    },

    meetingTime: {
      type: String,
      default: null,
      trim: true,
    },

    // ============================================================
    // STATUS
    // ============================================================

    status: {
      type: String,
      enum: [
        "Pending",
        "In Progress",
        "Resolved",
        "Rejected",
      ],
      default: "Pending",
    },

    // ============================================================
    // IMAGE
    // ============================================================

    imageUrl: {
      type: String,
      default: null,
    },
  },
  {
    timestamps: true,
  }
);

export default mongoose.model("Complain", complainSchema);