import Router from 'express';

import { protect } from '../middleware/authMiddleware.js';

import {
  getUserNotifications,
  markAllAsRead,
  markNotificationRead,
  deleteNotification,
  createMealServedNotification,
} from '../controllers/notificationController.js';

const router = Router();


// =====================================================
// GET ALL NOTIFICATIONS FOR LOGGED-IN USER
// GET /notifications
// =====================================================
router.get(
  '/',
  protect,
  getUserNotifications
);


// =====================================================
// MARK ALL NOTIFICATIONS AS READ
// PUT /notifications/mark-all-as-read
// =====================================================
router.put(
  '/mark-all-as-read',
  protect,
  markAllAsRead
);


// =====================================================
// MARK SINGLE NOTIFICATION AS READ
// PUT /notifications/:notificationId/read
// =====================================================
router.put(
  '/:notificationId/read',
  protect,
  markNotificationRead
);


// =====================================================
// DELETE SINGLE NOTIFICATION
// DELETE /notifications/:notificationId
// =====================================================
router.delete(
  '/:notificationId',
  protect,
  deleteNotification
);


// =====================================================
// MEAL SERVED → CREATE STUDENT NOTIFICATION
// POST /notifications/meal-served
// =====================================================
router.post(
  '/meal-served',
  protect,
  createMealServedNotification
);


export default router;