import express from 'express';
// IMPORTANT: Added .js extension for ES Modules
import { loginUser, registerUser, sendOTP, getProfile, forgetPassword, OtpForgetPass, getAllStudents } from '../controllers/auth.controller.js';
import { protect } from '../middleware/authMiddleware.js';
import { registerValidation, loginValidation, forgetValidation, otpValidation } from '../validations/authValidation.js';
import { validate } from '../validations/validate.js';

const router = express.Router();

// Fixed: added leading "/"
router.post("/send-otp", otpValidation, sendOTP);
router.post("/register", registerValidation, validate, registerUser);
router.post("/forget-otp", otpValidation, validate, OtpForgetPass);
router.put("/forget-pass",forgetValidation, forgetPassword)
router.post("/login", loginValidation, validate, loginUser);
router.get("/profile", protect, getProfile);

// manager
router.get("/all-students", protect, getAllStudents);


export default router;