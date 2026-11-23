/**
 * Example Express.js Authentication Controller
 * 
 * Demonstrates how external Express.js backend services consume `emailClient.js`.
 * 
 * CRITICAL ARCHITECTURE RULE:
 * - The OTP / Tokens are generated and validated entirely by THIS application (the caller).
 * - The Email Delivery Service is only a transport pipe.
 * - Mobile apps (Flutter/React Native) or Web SPAs talk to THIS controller, NEVER to the email service directly.
 */

const crypto = require("crypto");
const {
  sendEmail,
  sendOtpEmail,
  sendVerificationEmail,
  sendPasswordResetEmail
} = require("../emailClient");

// Simulated Database / Cache store for OTPs and Reset tokens
const inMemoryStore = {
  users: new Map(),
  otpCodes: new Map(),
  resetTokens: new Map()
};

/**
 * Controller: User Registration
 * Generates a verification token and sends verification email.
 * POST /api/auth/register
 */
async function register(req, res) {
  try {
    const { email, password, name } = req.body;

    if (!email || !password) {
      return res.status(400).json({ success: false, message: "Email and password are required" });
    }

    // 1. Generate secure random verification token (Caller generates token)
    const verificationToken = crypto.randomBytes(32).toString("hex");
    const verificationLink = `https://your-app.com/verify-email?token=${verificationToken}&email=${encodeURIComponent(email)}`;

    // Save user & token to DB (simulated)
    inMemoryStore.users.set(email, { name, password, isVerified: false });

    // 2. Dispatch verification email via EntireZe Email Service
    const emailResult = await sendVerificationEmail(email, verificationLink, "HostelApp");

    return res.status(201).json({
      success: true,
      message: "Registration successful. Please check your email to verify your account.",
      data: {
        messageId: emailResult.data?.messageId
      }
    });
  } catch (error) {
    console.error("[Register Error]", error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
}

/**
 * Controller: Request 2FA Login OTP
 * Generates a 6-digit random code and dispatches OTP email.
 * POST /api/auth/request-otp
 */
async function requestLoginOtp(req, res) {
  try {
    const { email } = req.body;

    if (!email) {
      return res.status(400).json({ success: false, message: "Email is required" });
    }

    // 1. Generate 6-digit cryptographically secure OTP (Caller generates OTP)
    const otp = crypto.randomInt(100000, 999999).toString();

    // 2. Store OTP with expiration (e.g. 10 minutes)
    inMemoryStore.otpCodes.set(email, {
      code: otp,
      expiresAt: Date.now() + 10 * 60 * 1000
    });

    // 3. Dispatch OTP email via EntireZe Email Service
    const emailResult = await sendOtpEmail(email, otp, "HostelApp", {
      senderName: "HostelApp Security"
    });

    return res.status(200).json({
      success: true,
      message: "OTP sent to your email address",
      data: {
        messageId: emailResult.data?.messageId
      }
    });
  } catch (error) {
    console.error("[OTP Request Error]", error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
}

/**
 * Controller: Verify 2FA OTP
 * POST /api/auth/verify-otp
 */
async function verifyLoginOtp(req, res) {
  const { email, otp } = req.body;

  const record = inMemoryStore.otpCodes.get(email);
  if (!record) {
    return res.status(400).json({ success: false, message: "No OTP requested for this email" });
  }

  if (Date.now() > record.expiresAt) {
    inMemoryStore.otpCodes.delete(email);
    return res.status(400).json({ success: false, message: "OTP has expired. Please request a new one." });
  }

  if (record.code !== otp) {
    return res.status(400).json({ success: false, message: "Invalid OTP code" });
  }

  // OTP is valid! Delete used OTP and log user in
  inMemoryStore.otpCodes.delete(email);

  return res.status(200).json({
    success: true,
    message: "OTP verified successfully. Authenticated!"
  });
}

/**
 * Controller: Request Password Reset Link
 * POST /api/auth/forgot-password
 */
async function forgotPassword(req, res) {
  try {
    const { email } = req.body;

    if (!email) {
      return res.status(400).json({ success: false, message: "Email is required" });
    }

    // 1. Generate reset token
    const resetToken = crypto.randomBytes(32).toString("hex");
    const resetLink = `https://your-app.com/reset-password?token=${resetToken}`;

    // Store token in DB
    inMemoryStore.resetTokens.set(resetToken, { email, expiresAt: Date.now() + 60 * 60 * 1000 });

    // 2. Dispatch Password Reset email
    const emailResult = await sendPasswordResetEmail(email, resetLink, "HostelApp");

    return res.status(200).json({
      success: true,
      message: "Password reset instructions have been sent to your email",
      data: {
        messageId: emailResult.data?.messageId
      }
    });
  } catch (error) {
    console.error("[Forgot Password Error]", error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
}

/**
 * Controller: Send Broadcast / Multi-Recipient Notification
 * POST /api/admin/notify-residents
 */
async function notifyResidents(req, res) {
  try {
    const { emails, title, announcementHtml } = req.body;

    if (!Array.isArray(emails) || emails.length === 0) {
      return res.status(400).json({ success: false, message: "Array of emails is required" });
    }

    // Dispatch to multiple recipients array in a single call
    const emailResult = await sendEmail(emails, title, announcementHtml, {
      senderName: "Hostel Warden Office"
    });

    return res.status(200).json({
      success: true,
      message: `Announcement sent to ${emails.length} residents successfully`,
      data: {
        messageId: emailResult.data?.messageId
      }
    });
  } catch (error) {
    console.error("[Notify Error]", error.message);
    return res.status(500).json({ success: false, message: error.message });
  }
}

module.exports = {
  register,
  requestLoginOtp,
  verifyLoginOtp,
  forgotPassword,
  notifyResidents
};
