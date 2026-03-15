import UpiDetail from "../models/upi.model.js";

export const saveUpiDetails = async (req, res) => {
  try {
    const { upiId, merchantName } = req.body;
    const { hostelId, _id: managerId } = req.user;

    const upi = await UpiDetail.findOneAndUpdate(
      { hostelId },
      { managerId, upiId, merchantName, updatedAt: Date.now() },
      { upsert: true, new: true }
    );

    res.status(200).json({ success: true, data: upi });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

export const getHostelUpi = async (req, res) => {
  try {
    const upi = await UpiDetail.findOne({ hostelId: req.user.hostelId });
    res.status(200).json({ success: true, data: upi });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};