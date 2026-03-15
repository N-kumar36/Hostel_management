import ManagerAssignment from "../models/ManagerAssignment.js";

export const checkPermission = (requiredPermission) => {
  return async (req, res, next) => {
    try {
      const month = new Date().toISOString().slice(0, 7);
      console.log("The month", month);
      const manager = await ManagerAssignment.findOne({
        userId: req.user.id,
        hostelId: req.user.hostelId,
        month,
        isActive: true
      });

      if (!manager) {
        return res.status(403).json({ success: false, message: "Active Manager record not found for this month." });
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