import UpiDetail from "../models/UpiDetail.js";

export const getHostelUpi = async (req, res) => {
  try {
    const upi = await UpiDetail.findOne({ hostelId: req.user.hostelId });
    res.status(200).json({ success: true, data: upi });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};