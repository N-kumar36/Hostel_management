import MealPlan from "../models/MealPlan.js";


export const getMealPlans = async (req, res) => {
  try {
  
    const hostelId = req.user.hostelId;

    if (!hostelId) {
      return res.status(400).json({ 
        success: false, 
        message: "User is not associated with any hostel." 
      });
    }

    // Find the plans (15 Day and 30 Day) for this specific hostel
    const plans = await MealPlan.find({ hostelId }).sort({ monthlyPrice: 1 });

    if (!plans || plans.length === 0) {
      return res.status(404).json({ 
        success: false, 
        message: "No meal plans found for this hostel. Please contact manager." 
      });
    }

    res.status(200).json({
      success: true,
      count: plans.length,
      data: plans
    });
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      message: "Server Error: " + error.message 
    });
  }
};