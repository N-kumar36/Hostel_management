import Vote from "../models/Vote.js";

export const serveMeal = async (req, res) => {
  await Vote.findByIdAndUpdate(req.params.id, {
    isServed: true,
    servedAt: new Date()
  });
  res.json({ message: "Meal served" });
};
