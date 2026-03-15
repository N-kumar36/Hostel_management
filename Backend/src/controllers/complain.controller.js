import Complain from "../models/Complain.js";
import { uploadToFirebase } from "../ConfigMultar/multar.control.js"; 

export const createComplain = async (req, res) => {
  try {
    const { category, description } = req.body;
    let imageUrl = null;

    if (req.file) {
      imageUrl = await uploadToFirebase(req.file);
    }

    const newComplain = await Complain.create({
      studentId: req.user.id,
      hostelId: req.user.hostelId,
      category,
      description,
      imageUrl, 
    });

    res.status(201).json({ success: true, data: newComplain });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

export const getHostelComplains = async (req, res) => {
  try {
    const { hostelId } = req.user;
    const complains = await Complain.find({ hostelId })
      .populate("studentId", "name roomNumber department regNum") 
      .sort({ createdAt: -1 });

    res.status(200).json({ success: true, count: complains.length, complains });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};