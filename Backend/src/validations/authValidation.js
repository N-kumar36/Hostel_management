import { body } from "express-validator";

export const registerValidation = [
  body("name")
    .trim()
    .notEmpty().withMessage("Name is required")
    .isLength({ min: 2 }).withMessage("Name must be at least 2 characters"),

  body("email")
    .trim()
    .isEmail()
    .withMessage("Valid email required"),

  body("password")
    .isLength({ min: 6 })
    .withMessage("Password must be at least 6 characters"),

  body("phone")
    .isMobilePhone("en-IN")
    .withMessage("Valid Indian phone number required"),

  body("hostelId")
    .notEmpty().withMessage("Hostel ID is required"),

  body("otp")
    .isLength({ min: 6, max: 6 })
    .withMessage("OTP must be 6 digits")
];

export const loginValidation = [
  body("email")
    .trim()
    .isEmail()
    .withMessage("Valid email required"),

  body("password")
    .notEmpty()
    .withMessage("Password is required")
];

export const forgetValidation = [
  body("email")
    .trim()
    .isEmail()
    .withMessage("Valid Email Required"),

  body("password")
    .isLength({ min: 6 })
    .withMessage("Password must be at least 6 characters"),

  body("otp")
    .isLength({ min: 6, max: 6 })
    .withMessage("OTP must be 6 digits")
];

export const otpValidation = [
  body("email")
    .trim()
    .isEmail()
    .withMessage("Valid email required")
];