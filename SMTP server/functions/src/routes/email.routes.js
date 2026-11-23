/**
 * EntireZe Nodemailer Service - Email API Routes
 */

const express = require("express");
const emailController = require("../controllers/email.controller");
const { authenticateApiKey } = require("../middleware/auth.middleware");
const { validateSendPayload } = require("../middleware/validation.middleware");
const { rateLimit } = require("../middleware/rate-limit.middleware");

const router = express.Router();

// Public monitoring endpoints
router.get("/health", emailController.healthCheck);
router.get("/status", emailController.statusCheck);

// Protected email send endpoint with layered security pipeline:
// 1. Rate Limiting (Abuse and DDoS prevention)
// 2. Timing-Safe API Key Authentication
// 3. Strict Input & Attachment Validation
// 4. Controller Execution
router.post(
  "/send",
  rateLimit,
  authenticateApiKey,
  validateSendPayload,
  emailController.sendEmail
);

module.exports = router;
