import WeeklyRoutine from "../models/WeeklyRoutine.js";

export const upsertWeeklyRoutine = async (req, res) => {
  try {
    const { routine } = req.body;

    console.log("Call Routine api", req.user);

    if (!routine || typeof routine !== "object") {
      return res.status(400).json({
        success: false,
        message: "Weekly routine is required",
      });
    }

    // Validate days (1–7)
    for (const day of Object.keys(routine)) {
      if (!["1", "2", "3", "4", "5", "6", "7"].includes(day)) {
        return res.status(400).json({
          success: false,
          message: `Invalid day key: ${day}. Use 1–7`,
        });
      }

      if (!routine[day].morning || !routine[day].night) {
        return res.status(400).json({
          success: false,
          message: `Morning and night meals are required for day ${day}`,
        });
      }
    }

    const weeklyRoutine = await WeeklyRoutine.findOneAndUpdate(
      { hostelId: req.user.hostelId },
      {
        hostelId: req.user.hostelId,
        routine,
      },
      {
        new: true,
        upsert: true, //  create if not exists
        runValidators: true,
      }
    );

    res.status(200).json({
      success: true,
      message: "Weekly routine saved successfully",
      weeklyRoutine,
    });

  } catch (err) {
    console.error("Weekly Routine Error:", err);

    res.status(500).json({
      success: false,
      message: err.message,
    });
  }
};

export const getWeeklyRoutine = async (req, res) => {
  try {
    const weeklyRoutine = await WeeklyRoutine.findOne({
      hostelId: req.user.hostelId,
    });

    if (!weeklyRoutine) {
      return res.status(404).json({
        success: false,
        message: "Weekly routine not found",
      });
    }

    res.status(200).json({
      success: true,
      weeklyRoutine,
    });

  } catch (err) {
    console.error("Get Weekly Routine Error:", err);

    res.status(500).json({
      success: false,
      message: err.message,
    });
  }
};