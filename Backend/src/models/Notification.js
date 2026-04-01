import mongoose from "mongoose";

const notificationSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  hostelId: { type: mongoose.Schema.Types.ObjectId, ref: 'Hostel', required: true },
  title: { type: String, required: true },
  message: { type: String, required: true },
  type: { 
    type: String, 
    enum: ['vote', 'payment', 'served', 'notice', 'alert'], 
    default: 'notice' 
  },
  isRead: { type: Boolean, default: false },
  
  // NEW: Track exactly when it was read
  readAt: { type: Date, default: null },
  
  createdAt: { type: Date, default: Date.now }
});

// ✨ THE MAGIC: Create a TTL Index on the 'readAt' field
// 3 days = 3 * 24 * 60 * 60 = 259200 seconds
// MongoDB will automatically delete the document 3 days after the 'readAt' date.
notificationSchema.index({ readAt: 1 }, { expireAfterSeconds: 259200 });

export default mongoose.model("Notification", notificationSchema);