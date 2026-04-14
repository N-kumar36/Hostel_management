import ManagerAssignment from "../models/ManagerAssignment.js";

export const checkPermission = (requiredPermission) => {
  return async (req, res, next) => {
    try {
      //  Removed month calculation
      const manager = await ManagerAssignment.findOne({
        userId: req.user.id,
        hostelId: req.user.hostelId,
        isActive: true // Just check if they are currently active
      });

      const admin = req.user.roles.includes("admin");

      if (admin) {
        return next(); // Admins bypass all checks
      }

      if (!manager) {
        return res.status(403).json({
          success: false,
          message: "Access Denied: You are not an active manager for this hostel."
        });
      }

      if (requiredPermission && !manager.permissions[requiredPermission]) {
        return res.status(403).json({
          success: false,
          message: `Permission denied: Missing ${requiredPermission} rights.`
        });
      }

      req.manager = manager;
      next();
    } catch (error) {
      res.status(500).json({ success: false, message: error.message });
    }
  };
};