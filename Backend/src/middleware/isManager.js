import ManagerAssignment from "../models/ManagerAssignment.js";

export const checkPermission = (requiredPermission) => {
  return async (req, res, next) => {
    try {
      // 1. ✨ Safe Admin Check FIRST (saves a database query if user is already an admin)
      // Using optional chaining (?.) prevents crashes if req.user or req.user.roles is undefined.
      // Also checking both req.user.roles array and a direct req.user.role string just to be safe.
      const isAdmin = req.user?.roles?.includes("admin") || req.user?.role === "admin";

      if (isAdmin) {
        return next(); // Admins bypass all checks immediately
      }

      // 2. Not an admin? Check for an active manager assignment
      const manager = await ManagerAssignment.findOne({
        userId: req.user.id || req.user._id, // Safely handles both id formats
        hostelId: req.user.hostelId,
        isActive: true // Must be currently active
      });

      if (!manager) {
        return res.status(403).json({
          success: false,
          message: "Access Denied: You are not an active manager for this hostel."
        });
      }

      // 3. Check for specific required permission (if one was requested)
      if (requiredPermission && !manager.permissions[requiredPermission]) {
        return res.status(403).json({
          success: false,
          message: `Permission denied: Missing '${requiredPermission}' rights.`
        });
      }

      // 4. Attach manager to request for downstream use and proceed
      req.manager = manager;
      next();
      
    } catch (error) {
      console.error("Permission Check Error:", error);
      res.status(500).json({ 
        success: false, 
        message: "Internal server error during permission check." 
      });
    }
  };
};