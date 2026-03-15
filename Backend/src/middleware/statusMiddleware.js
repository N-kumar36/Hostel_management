

export const isApproved = (req, res, next) => {
  // We assume 'protect' middleware has already run and attached the user to 'req.user'
  if (!req.user) {
    return res.status(401).json({ success: false, message: "Authentication required" });
  }

  // Check the 'pending' field from your User Model
  if (req.user.pending === "pending") {
    return res.status(403).json({ 
      success: false, 
      message: "Your account is pending approval from the hostel manager. You cannot perform this action yet." 
    });
  }

  // If approved, move to the next function (controller)
  next();
};