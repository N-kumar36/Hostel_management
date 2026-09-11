import Notification from "../models/Notification.js";

// Mark all unread notifications as read and start the 3-day deletion timer
export const markAllAsRead = async (req, res) => {
  try {
    const userId = req.user._id;

    await Notification.updateMany(
      { userId: userId, isRead: false },
      { 
        $set: { 
          isRead: true, 
          readAt: new Date() // ✨ NEW: Set the clock for the TTL index!
        } 
      }
    );
import Notification from "../models/Notification.js";
import User from "../models/User.js";

// ============================================================
// MARK ALL UNREAD NOTIFICATIONS AS READ
// Also starts the 3-day TTL deletion timer
// ============================================================

export const markAllAsRead = async (req, res) => {
  try {
    const userId = req.user._id;

    await Notification.updateMany(
      {
        userId: userId,
        isRead: false,
      },
      {
        $set: {
          isRead: true,
          readAt: new Date(),
        },
      }
    );

    return res.status(200).json({
      success: true,
      message:
        "Marked all as read. Deletion timer started.",
    });
  } catch (error) {
    console.error(
      "Mark All Notifications Error:",
      error
    );

    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// ============================================================
// FETCH ALL NOTIFICATIONS FOR LOGGED-IN USER
// ============================================================

export const getUserNotifications = async (req, res) => {
  try {
    const userId = req.user._id;

    const notifications = await Notification.find({
      userId: userId,
    }).sort({
      createdAt: -1,
    });

    return res.status(200).json({
      success: true,
      data: notifications,
    });
  } catch (error) {
    console.error(
      "Get Notifications Error:",
      error
    );

    return res.status(500).json({
      success: false,
      message: error.message,
      data: [],
    });
  }
};

// ============================================================
// MARK ONE NOTIFICATION AS READ
// ============================================================

export const markNotificationRead = async (req, res) => {
  try {
    const { notificationId } = req.params;

    const notification =
      await Notification.findOne({
        _id: notificationId,
        userId: req.user._id,
      });

    if (!notification) {
      return res.status(404).json({
        success: false,
        message: "Notification not found.",
      });
    }

    notification.isRead = true;
    notification.readAt = new Date();

    await notification.save();

    return res.status(200).json({
      success: true,
      message: "Notification marked as read.",
    });
  } catch (error) {
    console.error(
      "Mark Notification Read Error:",
      error
    );

    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// ============================================================
// DELETE ONE NOTIFICATION
// ============================================================

export const deleteNotification = async (req, res) => {
  try {
    const { notificationId } = req.params;

    const notification =
      await Notification.findOneAndDelete({
        _id: notificationId,
        userId: req.user._id,
      });

    if (!notification) {
      return res.status(404).json({
        success: false,
        message: "Notification not found.",
      });
    }

    return res.status(200).json({
      success: true,
      message: "Notification deleted successfully.",
    });
  } catch (error) {
    console.error(
      "Delete Notification Error:",
      error
    );

    return res.status(500).json({
      success: false,
      message: error.message,
    });
  }
};

// ============================================================
// CREATE MEAL SERVED NOTIFICATION
// ============================================================
//
// Called after a manager successfully serves a student's meal.
//
// POST /notifications/meal-served
//
// Body:
//
// {
//   "studentId": "...",
//   "meal": "Chicken",
//   "timeSlot": "Morning",
//   "mealDate": "2026-09-12"
// }
//
// ============================================================

export const createMealServedNotification = async (
  req,
  res
) => {
  try {
    const {
      studentId,
      meal,
      timeSlot,
      mealDate,
    } = req.body;

    // --------------------------------------------------------
    // VALIDATION
    // --------------------------------------------------------

    if (!studentId) {
      return res.status(400).json({
        success: false,
        message: "studentId is required.",
      });
    }

    if (!timeSlot) {
      return res.status(400).json({
        success: false,
        message: "timeSlot is required.",
      });
    }

    // --------------------------------------------------------
    // FIND STUDENT
    // --------------------------------------------------------

    const student =
      await User.findById(studentId);

    if (!student) {
      return res.status(404).json({
        success: false,
        message: "Student not found.",
      });
    }

    // --------------------------------------------------------
    // DETERMINE HOSTEL
    // --------------------------------------------------------

    const hostelId =
      student.hostelId ||
      req.user.hostelId;

    if (!hostelId) {
      return res.status(400).json({
        success: false,
        message:
          "Student hostel could not be determined.",
      });
    }

    // --------------------------------------------------------
    // NORMALIZE DATA
    // --------------------------------------------------------

    const normalizedTimeSlot =
      timeSlot.toString().toLowerCase() ===
      "morning"
        ? "Morning"
        : "Night";

    const mealName =
      meal?.toString().trim() ||
      "your meal";

    const dateText =
      mealDate?.toString().trim() || "";

    // --------------------------------------------------------
    // CREATE NOTIFICATION
    // --------------------------------------------------------

    const notification =
      await Notification.create({
        userId: student._id,
        hostelId: hostelId,

        title: "🍽️ Take Your Meal",

        message:
          `Your ${mealName} meal for ` +
          `${normalizedTimeSlot}` +
          `${
            dateText
              ? ` (${dateText})`
              : ""
          } has been served. ` +
          `Please collect your meal.`,

        type: "take_your_meal",

        isRead: false,

        readAt: null,

        createdAt: new Date(),
      });

    // --------------------------------------------------------
    // SUCCESS
    // --------------------------------------------------------

    return res.status(201).json({
      success: true,
      message:
        "Meal notification sent to student.",
      data: notification,
    });
  } catch (error) {
    console.error(
      "Create Meal Served Notification Error:",
      error
    );

    return res.status(500).json({
      success: false,
      message:
        "Failed to create meal notification.",
      error: error.message,
    });
  }
};
    res.status(200).json({ success: true, message: "Marked all as read. Deletion timer started." });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// Fetch all notifications for the logged-in user
export const getUserNotifications = async (req, res) => {
  try {
    const userId = req.user._id;

    const notifications = await Notification.find({ userId })
      .sort({ createdAt: -1 }); // Newest first

    res.status(200).json({ success: true, data: notifications });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};