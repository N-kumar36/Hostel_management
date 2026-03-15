
import Hostel from "../models/Hostel.js";

// GET all hostels (for registration dropdown)
export const getHostels = async (req, res) => {
    try {
        const hostels = await Hostel.find({}, "name _id");

        res.status(200).json({
            success: true,
            count: hostels.length,
            data: hostels
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
};

// CREATE hostel
export const createHostel = async (req, res) => {
    try {
        const name = req.body.name?.trim();
        const location = req.body.location?.trim();

        if (!name || !location) {
            return res.status(400).json({
                success: false,
                message: "Please provide all required fields: name and location"
            });
        }

        // Prevent duplicates
        const existingHostel = await Hostel.findOne({ name });
        if (existingHostel) {
            return res.status(409).json({
                success: false,
                message: "Hostel already exists"
            });
        }

        const newHostel = new Hostel({ name, location });
        await newHostel.save();

        res.status(201).json({
            success: true,
            message: "Hostel created successfully",
            hostel: newHostel
        });

    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
};
