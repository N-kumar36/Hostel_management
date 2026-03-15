import mongoose from "mongoose";

const hostelSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    trim: true
  },
  location: {
    type: String,
    required: true,
    trim: true
  }
});

const Hostel = mongoose.model("Hostel", hostelSchema);

export default Hostel;
