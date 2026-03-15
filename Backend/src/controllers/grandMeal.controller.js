import GrandMeal from "../models/GrandMeal.js";
import Finance from "../models/MonthlyFinance.js";

export const createGrandMeal = async (req, res) => {
  const finance = await Finance.findOne({
    hostelId: req.user.hostelId,
    month: req.body.month
  });

  if (finance.balance < req.body.totalCost)
    return res.status(400).json({ message: "Insufficient balance" });

  const meal = await GrandMeal.create({
    ...req.body,
    createdBy: req.user.id
  });

  finance.balance -= req.body.totalCost;
  await finance.save();

  res.json(meal);
};
