import bcrypt from "bcryptjs";
import User from "../models/User.js";
import ManagerAssignment from "../models/ManagerAssignment.js"; // Import this!
import Otp from "../models/Otp.js";

import { sendEmail } from "../utils/sendSMS.js";
import { generateToken } from "../utils/generateToken.js";

export const sendOTP = async (req, res) => {
  const { email, phone } = req.body;
  try {
    const exists = await User.findOne({ email: email.toLowerCase() });
    if (exists) {
      return res.status(400).json({ success: false, message: "User already exists" });
    }

    const otp = Math.floor(100000 + Math.random() * 900000).toString();

    // Use lowercase email for consistency
    await Otp.findOneAndUpdate(
      { email: email.toLowerCase() },
      { otp, createdAt: Date.now() },
      { upsert: true, new: true }
    );

    await sendEmail(email, "KNU Hostel OTP Verification", `
  <div style="font-family: Arial, sans-serif; background:#f4f4f4; padding:30px;">
    <div style="max-width:500px; margin:auto; background:#ffffff; padding:25px; border-radius:8px; text-align:center;">
      
      <h2 style="color:#333;">KNU Boys Hostel</h2>
      <p style="font-size:16px; color:#555;">
        Your One-Time Password (OTP) for verification is:
      </p>

      <div style="font-size:32px; font-weight:bold; color:#2d89ef; letter-spacing:6px; margin:20px 0;">
        ${otp}
      </div>

      <p style="font-size:14px; color:#777;">
        This OTP is valid for <b>5 minutes</b>.
      </p>

      <p style="font-size:13px; color:#999; margin-top:20px;">
        If you did not request this OTP, please ignore this email.
      </p>

      <hr style="margin:25px 0;" />

      <p style="font-size:12px; color:#aaa;">
        KNU Boys Hostel Management System
      </p>

    </div>
  </div>
  `);

    res.json({ success: true, message: "OTP sent successfully" });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};



export const registerUser = async (req, res) => {
  const {
    name,
    email,
    password,
    phone,
    otp,
    hostelId,
    regNum,
    department,
    year
  } = req.body;

  try {
    // 1. OTP VALIDATION
    const otpRecord = await Otp.findOne({ email: email.toLowerCase() });
    if (!otpRecord || otpRecord.otp !== otp) {
      return res.status(400).json({ success: false, message: "Invalid OTP" });
    }

    // 2. DUPLICATE CHECK
    const existingUser = await User.findOne({
      $or: [{ email: email.toLowerCase() }, { regNum }]
    });

    if (existingUser) {
      const conflictField = existingUser.email === email.toLowerCase() ? "Email" : "Registration Number";
      return res.status(400).json({
        success: false,
        message: `${conflictField} is already registered.`
      });
    }

    // 3. CHECK IF THIS IS THE FIRST USER FOR THIS HOSTEL
    const userCountInHostel = await User.countDocuments({ hostelId });
    
    // Determine Role and Approval Status
    let role = "student";
    let pendingStatus = "pending";

    if (userCountInHostel <= 1) { // If no users or only 1 user exists, make this user a manager
      role = "manager";
      pendingStatus = "approve"; // First user is auto-approved
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    // 4. CREATE THE USER
    const user = await User.create({
      name,
      email: email.toLowerCase(),
      phone,
      hostelId,
      regNum,
      department,
      year,
      password: hashedPassword,
      role: role,
      pending: pendingStatus
    });

    // 5. IF FIRST USER, ASSIGN MANAGER PERMISSIONS AUTOMATICALLY
    if (role === "manager") {
      await ManagerAssignment.create({
        hostelId: hostelId,
        userId: user._id,
        permissions: {
          mealEdit: true,
          serveMeal: true,
          fineManage: true
        },
        isActive: true
      });
      console.log(`✅ First user ${user.name} registered as Manager with full rights.`);
    }

    await Otp.deleteOne({ email: email.toLowerCase() });

    res.status(201).json({
      success: true,
      user: { id: user._id, name: user.name, role: user.role, status: user.pending }
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// export const registerUser = async (req, res) => {
//   // 1. EXTRACTION: Ensure names match the Flutter keys exactly
//   const {
//     name,
//     email,
//     password,
//     phone,
//     otp,
//     hostelId,
//     regNum,       // Must match 'regNum' from Flutter
//     department,   // Must match 'department' from Flutter
//     year          // Must match 'year' from Flutter
//   } = req.body;

//   console.log("Received registration data:", req.body); // Debug log to check incoming data

//   try {
//     // 2. OTP VALIDATION
//     const otpRecord = await Otp.findOne({ email: email.toLowerCase() });
//     if (!otpRecord || otpRecord.otp !== otp) {
//       return res.status(400).json({ success: false, message: "Invalid OTP" });
//     }

//     // 3. DUPLICATE CHECK
//     const existingUser = await User.findOne({
//       $or: [{ email: email.toLowerCase() }, { regNum }]
//     });

//     console.log(existingUser);

//     if (existingUser) {
//       const conflictField = existingUser.email === email.toLowerCase() ? "Email" : "Registration Number";
//       return res.status(400).json({
//         success: false,
//         message: `${conflictField} is already registered.`
//       });
//     }

//     const hashedPassword = await bcrypt.hash(password, 10);

//     // 4. CREATION: Pass the new academic fields
//     const user = await User.create({
//       name,
//       email: email.toLowerCase(),
//       phone,
//       hostelId,
//       regNum,
//       department,
//       year,
//       password: hashedPassword,
//     });

//     await Otp.deleteOne({ email: email.toLowerCase() });

//     res.status(201).json({
//       success: true,
//       user: { id: user._id, name: user.name, role: user.role }
//     });
//   } catch (err) {
//     res.status(500).json({ success: false, message: err.message });
//   }
// };


export const loginUser = async (req, res) => {
  const { email, password } = req.body;

  console.log("Login was call", req.body);

  try {
    const user = await User.findOne({ email: email.toLowerCase() });

    if (!user || !(await bcrypt.compare(password, user.password))) {
      return res.status(401).json({ success: false, message: "Invalid credentials" });
    }

    res.json({
      success: true,
      user,
      token: generateToken({
        id: user._id,
        hostelId: user.hostelId,
        email: user.email,
      }),
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};



export const getProfile = async (req, res) => {

  console.log("getProfile called with user:", req.user); // Debug log to check req.user

  try {
    // Ensure the middleware actually found a user
    if (!req.user || !req.user.id) {
      return res.status(401).json({ success: false, message: "Not authorized, no user data" });
    }

    const user = await User.findById(req.user.id).select("-password");

    if (!user) {
      return res.status(404).json({ success: false, message: "User not found in database" });
    }

    res.json({ success: true, user });
  } catch (err) {
    res.status(500).json({ success: false, message: "Server Error: " + err.message });
  }
};


export const OtpForgetPass = async (req, res) => {
  const { email, phone } = req.body;

  try {
    const exists = await User.findOne({ email: email.toLowerCase() });
    if (!exists) {
      return res.status(400).json({ success: false, message: "User Not Exists" });
    }

    const otp = Math.floor(100000 + Math.random() * 900000).toString();

    // Use lowercase email for consistency
    await Otp.findOneAndUpdate(
      { email: email.toLowerCase() },
      { otp, createdAt: Date.now() },
      { upsert: true, new: true }
    );

    await sendEmail(
      email,
      "KNU Hostel OTP Verification",
      `
  <div style="font-family: Arial, sans-serif; background:#f4f6f8; padding:30px;">
    <div style="max-width:500px; margin:auto; background:#ffffff; padding:25px; border-radius:8px; text-align:center; box-shadow:0 2px 8px rgba(0,0,0,0.1);">
      
      <h2 style="color:#333;">KNU Hostel</h2>
      
      <p style="font-size:16px; color:#555;">
        You requested to reset your password.
      </p>

      <p style="font-size:15px; color:#666;">
        Use the OTP below to reset your password:
      </p>

      <div style="font-size:32px; font-weight:bold; color:#2d89ef; letter-spacing:6px; margin:20px 0;">
        ${otp}
      </div>

      <p style="font-size:14px; color:#777;">
        This OTP will expire in <b>5 minutes</b>.
      </p>

      <p style="font-size:13px; color:#999; margin-top:20px;">
        If you did not request a password reset, please ignore this email.
      </p>

      <hr style="margin:25px 0;" />

      <p style="font-size:12px; color:#aaa;">
        KNU Boys Hostel Management System
      </p>

    </div>
  </div>
  `
    );

    res.json({ success: true, message: "OTP sent successfully" });


  } catch (error) {
    res.status(500).json({ success: false, message: error.message });

  }
}

// --- FORGET PASSWORD (FIXED) ---
export const forgetPassword = async (req, res) => {
  const { email, password, otp } = req.body;

  try {
    const lowerEmail = email.toLowerCase();

    // 1. Validate OTP
    const otpRecord = await Otp.findOne({ email: lowerEmail });
    if (!otpRecord || otpRecord.otp !== otp) {
      return res.status(400).json({ success: false, message: "Invalid or expired OTP" });
    }

    // 2. Find User
    const user = await User.findOne({ email: lowerEmail });
    if (!user) {
      return res.status(404).json({ success: false, message: "User not found" });
    }

    // 3. Update Password
    const hashedPassword = await bcrypt.hash(password, 10);
    user.password = hashedPassword;
    await user.save();

    // 4. Cleanup
    await Otp.deleteOne({ email: lowerEmail });

    res.json({ success: true, message: "Password reset successful" });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};



/// manager

export const getAllStudents = async (req, res) => {
  try {
    // We get the hostelId from the protect middleware (the logged-in manager)
    const hostelId = req.user.hostelId;

    const students = await User.find({
      hostelId: hostelId,
      role: 'student'
    }).select("name email photoURL roomNumber"); // Only return necessary fields

    res.status(200).json({
      success: true,
      data: students,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};