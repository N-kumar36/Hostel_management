import mongoose from "mongoose";

const finePriceSchema = new mongoose.Schema({
  hostelId: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: "Hostel", 
    required: true, 
    unique: true 
  },
  prices: {
    veg: { type: Number, default: 35 },
    egg: { type: Number, default: 45 },
    paneer: { type: Number, default: 45 },
    chicken: { type: Number, default: 65 },
    fish: { type: Number, default: 55 },
    mutton: { type: Number, default: 85 },
  },
  updatedAt: { 
    type: Date, 
    default: Date.now 
  }
});

export default mongoose.model("FinePrice", finePriceSchema);