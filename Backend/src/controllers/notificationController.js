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