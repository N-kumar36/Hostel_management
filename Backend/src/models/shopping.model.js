import mongoose from "mongoose";

const shoppingItemSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, "Item name is required"],
      trim: true,
    },
    description: {
      type: String,
      trim: true,
      default: "",
    },
    price: {
      type: Number,
      required: [true, "Item price calculation is required"],
      min: [0, "Price cannot be a negative value"],
      default: 0.0,
    },
    isBought: {
      type: Boolean,
      required: true,
      default: false,
    },
    dateTime: {
      type: String, 
    },
    // ⚡ CRITICAL FIX: Add this field so MongoDB can index and find items by Hostel!
    hostelId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Hostel",
      required: true,
    },
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
  },
  {
    timestamps: true,
  }
);

export default mongoose.model("ShoppingItem", shoppingItemSchema);