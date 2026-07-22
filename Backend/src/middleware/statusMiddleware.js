export const isApproved = (req, res, next) => {
  // Assume 'protect' middleware attached 'req.user'
  if (!req.user) {
    return res.status(401).json({ success: false, message: "Authentication required" });
  }

  // Strictly allow ONLY "active" users
  if (req.user.status !== "active") {
    return res.status(403).json({ 
      success: false, 
      message: "Access restricted. Your account is not active." 
    });
  }

  // User is active, proceed to controller
  next();
};