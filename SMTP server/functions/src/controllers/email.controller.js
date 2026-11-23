/**
 * EntireZe Nodemailer Service - Email HTTP Controller
 */

const emailService = require("../services/email.service");
const smtpService = require("../services/smtp.service");

/**
 * Handles POST /api/v1/send
 */
async function sendEmail(req, res) {
  try {
    const { to, subject, htmlContent, senderName, text, cc, bcc, replyTo, attachments } = req.body || {};

    const result = await emailService.sendEmail({
      to,
      subject,
      htmlContent,
      senderName,
      text,
      cc,
      bcc,
      replyTo,
      attachments
    });

    return res.status(200).json({
      success: true,
      message: "Email sent successfully",
      data: {
        messageId: result.messageId
      }
    });
  } catch (error) {
    const statusCode = error.statusCode || (error.code && error.code.startsWith("SMTP_") ? 500 : 400);

    return res.status(statusCode).json({
      success: false,
      message: error.message || "Failed to send email",
      error: {
        code: error.code || "EMAIL_SEND_FAILED"
      }
    });
  }
}

/**
 * Handles GET /api/v1/health
 */
function healthCheck(req, res) {
  return res.status(200).json({
    success: true,
    message: "EntireZe Nodemailer Service is healthy",
    data: {
      status: "UP",
      region: "asia-south1",
      timestamp: new Date().toISOString()
    }
  });
}

/**
 * Handles GET /api/v1/status
 */
async function statusCheck(req, res) {
  return res.status(200).json({
    success: true,
    message: "EntireZe Nodemailer Service Status",
    data: {
      service: "EntireZe Nodemailer Service",
      version: "1.0.0",
      transport: "Nodemailer SMTP"
    }
  });
}

module.exports = {
  sendEmail,
  healthCheck,
  statusCheck
};
