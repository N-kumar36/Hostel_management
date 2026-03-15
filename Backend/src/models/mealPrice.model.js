import mongoose from "mongoose";

const mealPriceSchema = new mongoose.Schema({
  hostelId: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: "Hostel", 
    required: true, 
    unique: true 
  },
  baseFee: { 
    type: Number, 
    default: 1500 
  },
  // 🔥 Using a Map allows dynamic keys like "milk", "biryani", etc.
  prices: {
    type: Map,
    of: Number,
    default: {
      veg: 35,
      egg: 45,
      paneer: 45,
      chicken: 65,
      fish: 55,
      mutton: 85
    }
  },
  updatedAt: { type: Date, default: Date.now }
});

export default mongoose.model("MealPrice", mealPriceSchema);