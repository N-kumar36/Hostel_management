import Router from 'express';
import { protect } from '../middleware/authMiddleware.js';
import { getUserNotifications, markAllAsRead } from '../controllers/notificationController.js';

const router = Router();


router.get('/', protect, getUserNotifications);
router.put('/mark-all-as-read', protect, markAllAsRead);
 
  




export default router;