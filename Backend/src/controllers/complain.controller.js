import Complain from "../models/Complain.js";
import { uploadToFirebase } from "../ConfigMultar/multar.control.js";

// ============================================================
// VALID ENUMS
// ============================================================

const REQUEST_TYPES = [
  "Complaint",
  "App Problem",
  "Suggestion",
  "Meeting",
];

const CATEGORIES = [
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
];

const STATUS_VALUES = [
  "Pending",
  "In Progress",
  "Resolved",
  "Rejected",
];

// ============================================================
// CATEGORY GROUPS
// ============================================================

const CATEGORY_GROUPS = {
  Complaint: [
    "Food Quality",
    "Hygiene Issue",
    "Staff Behavior",
    "Meal Timing",
    "Mess Facilities",
    "Other",
  ],

  "App Problem": [
    "Login / Authentication",
    "Meal Voting",
    "Profile Problem",
    "Notification Problem",
    "Photo Upload Problem",
    "App Crash / Bug",
    "Other",
  ],

  Suggestion: [
    "Food / Menu",
    "Mess Management",
    "App Improvement",
    "Hostel Facility",
    "New Feature",
    "Other",
  ],

  Meeting: [
    "Mess Committee Discussion",
    "Food / Menu Discussion",
    "Hostel Issue",
    "Personal Discussion",
    "App / Technical Discussion",
    "Suggestion Discussion",
    "Other",
  ],
};

// ============================================================
// 1. CREATE COMPLAINT
// ============================================================

export const createComplain = async (req, res) => {
  try {
    const {
      requestType = "Complaint",
      category,
      description,
      meetingDate,
      meetingTime,
    } = req.body;

    // ----------------------------------------------------------
    // BASIC VALIDATION
    // ----------------------------------------------------------

    if (!REQUEST_TYPES.includes(requestType)) {
      return res.status(400).json({
        success: false,
        message: "Invalid request type.",
        allowedRequestTypes: REQUEST_TYPES,
      });
    }

    if (!category || !CATEGORIES.includes(category)) {
      return res.status(400).json({
        success: false,
        message: "Invalid complaint category.",
        allowedCategories: CATEGORIES,
      });
    }

    if (!description || description.trim().length < 5) {
      return res.status(400).json({
        success: false,
        message: "Please provide a valid description.",
      });
    }

    // ----------------------------------------------------------
    // CATEGORY / REQUEST TYPE VALIDATION
    // ----------------------------------------------------------

    const allowedCategories = CATEGORY_GROUPS[requestType];

    if (!allowedCategories.includes(category)) {
      return res.status(400).json({
        success: false,
        message: `"${category}" is not a valid category for "${requestType}".`,
        requestType,
        allowedCategories,
      });
    }

    // ----------------------------------------------------------
    // MEETING VALIDATION
    // ----------------------------------------------------------

    let normalizedMeetingDate = null;
    let normalizedMeetingTime = null;

    if (requestType === "Meeting") {
      if (!meetingDate) {
        return res.status(400).json({
          success: false,
          message: "Meeting date is required.",
        });
      }

      if (!meetingTime || meetingTime.trim().isEmpty) {
        return res.status(400).json({
          success: false,
          message: "Meeting time is required.",
        });
      }

      normalizedMeetingDate = new Date(meetingDate);

      if (isNaN(normalizedMeetingDate.getTime())) {
        return res.status(400).json({
          success: false,
          message: "Invalid meeting date.",
        });
      }

      normalizedMeetingTime = meetingTime.trim();
    }

    // ----------------------------------------------------------
    // IMAGE
    // ----------------------------------------------------------

    let imageUrl = null;

    if (req.file) {
      imageUrl = await uploadToFirebase(req.file);
    }

    // ----------------------------------------------------------
    // USER
    // ----------------------------------------------------------

    const studentId = req.user._id || req.user.id;

    if (!studentId) {
      return res.status(401).json({
        success: false,
        message: "Authenticated student not found.",
      });
    }

    if (!req.user.hostelId) {
      return res.status(400).json({
        success: false,
        message: "Hostel information is missing.",
      });
    }

    // ----------------------------------------------------------
    // CREATE
    // ----------------------------------------------------------

    const newComplain = await Complain.create({
      studentId,
      hostelId: req.user.hostelId,

      requestType,
      category,

      description: description.trim(),

      meetingDate: normalizedMeetingDate,
      meetingTime: normalizedMeetingTime,

      imageUrl,
      status: "Pending",
    });

    // ----------------------------------------------------------
    // RESPONSE
    // ----------------------------------------------------------

    return res.status(201).json({
      success: true,
      message: "Request submitted successfully.",
      data: newComplain,
    });
  } catch (error) {
    console.error("Create Complaint Error:", error);

    return res.status(500).json({
      success: false,
      message: error.message || "Failed to submit request.",
    });
  }
};

// ============================================================
// 2. GET ALL COMPLAINTS
// ============================================================

export const getHostelComplains = async (req, res) => {
  try {
    const { hostelId } = req.user;

    if (!hostelId) {
      return res.status(400).json({
        success: false,
        message: "Hostel information is missing.",
      });
    }

    const complains = await Complain.find({ hostelId })
      .populate(
        "studentId",
        "name roomNumber department regNum phone photoURL email"
      )
      .sort({ createdAt: -1 });

    return res.status(200).json({
      success: true,
      count: complains.length,
      complains,
    });
  } catch (error) {
    console.error("Get Hostel Complaints Error:", error);

    return res.status(500).json({
      success: false,
      message: error.message || "Failed to load complaints.",
    });
  }
};

// ============================================================
// 3. UPDATE COMPLAINT STATUS
// ============================================================

export const updateComplainStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    // ----------------------------------------------------------
    // STATUS VALIDATION
    // ----------------------------------------------------------

    if (!STATUS_VALUES.includes(status)) {
      return res.status(400).json({
        success: false,
        message: "Invalid status provided.",
        allowedStatuses: STATUS_VALUES,
      });
    }

    // ----------------------------------------------------------
    // FIND + UPDATE
    // ----------------------------------------------------------

    const updatedComplain = await Complain.findOneAndUpdate(
      {
        _id: id,
        hostelId: req.user.hostelId,
      },
      {
        $set: {
          status,
        },
      },
      {
        new: true,
        runValidators: true,
      }
    ).populate(
      "studentId",
      "name roomNumber department regNum phone photoURL email"
    );

    if (!updatedComplain) {
      return res.status(404).json({
        success: false,
        message: "Complaint not found or unauthorized.",
      });
    }

    return res.status(200).json({
      success: true,
      message: `Request marked as ${status} successfully.`,
      complain: updatedComplain,
    });
  } catch (error) {
    console.error("Update Complaint Error:", error);

    return res.status(500).json({
      success: false,
      message: "Failed to update request status.",
      error: error.message,
    });
  }
};