/**
 * EntireZe Nodemailer Service - Reusable SMTP Service
 * 
 * Manages singleton transporter instance, connection pool,
 * verification, error sanitization, and dispatch.
 */

const nodemailer = require("nodemailer");
const { getMailConfig } = require("../config/mail.config");

// Singleton cached transporter instance to prevent recreating on every request
let cachedTransporter = null;

/**
 * Returns the cached Nodemailer transporter or creates a new pooled instance.
 * @param {Object} [customOptions] - Optional overrides (e.g. for testing)
 * @returns {import("nodemailer").Transporter}
 */
function getTransporter(customOptions = null) {
  if (customOptions) {
    return nodemailer.createTransport(customOptions);
  }

  if (cachedTransporter) {
    return cachedTransporter;
  }

  const { smtp } = getMailConfig();

  // Validate credentials present
  if (!smtp.auth.user || !smtp.auth.pass) {
    console.warn("[SmtpService] Warning: SMTP_USER or SMTP_PASS is missing or empty.");
  }

  cachedTransporter = nodemailer.createTransport(smtp);

  return cachedTransporter;
}

/**
 * Sets or overrides the cached transporter (useful for testing or custom transports).
 * @param {import("nodemailer").Transporter} transporter
 */
function setTransporter(transporter) {
  cachedTransporter = transporter;
}

/**
 * Resets the cached transporter (useful when credentials change or for tests).
 */
function resetTransporter() {
  if (cachedTransporter && typeof cachedTransporter.close === "function") {
    try {
      cachedTransporter.close();
    } catch (_) {}
  }
  cachedTransporter = null;
}

/**
 * Verifies the connection and authentication with the configured SMTP server.
 * 
 * @param {import("nodemailer").Transporter} [transporterInstance]
 * @returns {Promise<{ success: boolean, message: string }>}
 */
async function verifyConnection(transporterInstance = null) {
  const transporter = transporterInstance || getTransporter();

  try {
    await transporter.verify();
    return {
      success: true,
      message: "SMTP server connection and authentication verified successfully"
    };
  } catch (error) {
    const sanitized = sanitizeSmtpError(error);
    const err = new Error(sanitized.message);
    err.code = sanitized.code;
    err.responseCode = sanitized.responseCode;
    throw err;
  }
}

/**
 * Sends an email using the cached SMTP transporter.
 * 
 * @param {Object} options
 * @param {string|string[]} options.to - Recipient(s)
 * @param {string} options.subject - Subject line
 * @param {string} [options.text] - Plain text content
 * @param {string} [options.html] - HTML content
 * @param {string|string[]} [options.cc] - Carbon copy
 * @param {string|string[]} [options.bcc] - Blind carbon copy
 * @param {string} [options.replyTo] - Reply-To address
 * @param {string} [options.fromName] - Custom sender display name
 * @param {Array} [options.attachments] - Nodemailer attachments array
 * @returns {Promise<{ messageId: string, accepted: string[], rejected: string[] }>}
 */
async function sendMail(options) {
  const transporter = getTransporter();
  const { defaults } = getMailConfig();

  const fromHeader = options.fromName
    ? `"${options.fromName}" <${defaults.fromEmail}>`
    : defaults.formattedFrom;

  const mailOptions = {
    from: fromHeader,
    to: Array.isArray(options.to) ? options.to.join(", ") : options.to,
    subject: options.subject,
    text: options.text,
    html: options.html,
    cc: Array.isArray(options.cc) ? options.cc.join(", ") : options.cc,
    bcc: Array.isArray(options.bcc) ? options.bcc.join(", ") : options.bcc,
    replyTo: options.replyTo || defaults.fromEmail,
    attachments: options.attachments || []
  };

  try {
    const info = await transporter.sendMail(mailOptions);
    return {
      messageId: info.messageId,
      accepted: info.accepted || [],
      rejected: info.rejected || []
    };
  } catch (error) {
    const sanitized = sanitizeSmtpError(error);
    const err = new Error(sanitized.message);
    err.code = sanitized.code;
    err.responseCode = sanitized.responseCode;
    throw err;
  }
}

/**
 * Sanitizes SMTP errors so credentials, tokens, or raw sockets are never exposed.
 * 
 * @param {Error} error
 * @returns {{ code: string, message: string, responseCode?: number }}
 */
function sanitizeSmtpError(error) {
  const rawCode = error.code || "";
  const responseCode = error.responseCode;
  let code = "SMTP_TRANSACTION_FAILED";
  let message = "SMTP transaction failed";

  if (rawCode === "EAUTH" || responseCode === 535) {
    code = "SMTP_AUTHENTICATION_FAILED";
    message = "SMTP authentication failed. Check SMTP_USER and SMTP_PASS (app password).";
  } else if (rawCode === "ETIMEDOUT" || rawCode === "ECONNTIMEOUT") {
    code = "SMTP_CONNECTION_TIMEOUT";
    message = "Connection to the SMTP server timed out.";
  } else if (rawCode === "ESOCKET" || rawCode === "ECONNREFUSED" || rawCode === "ENOTFOUND") {
    code = "SMTP_HOST_UNREACHABLE";
    message = "Cannot connect to the SMTP host. Verify SMTP_HOST and SMTP_PORT.";
  } else if (responseCode >= 550 && responseCode <= 559) {
    code = "SMTP_RECIPIENT_REJECTED";
    message = "One or more recipient addresses were rejected by the mail server.";
  } else if (responseCode >= 500 && responseCode <= 599) {
    code = "SMTP_COMMAND_REJECTED";
    message = "The SMTP server rejected the command.";
  } else if (error.message) {
    // Strip any user/pass strings from error message
    const scrubbed = error.message
      .replace(new RegExp(process.env.SMTP_PASS || "____never____", "gi"), "[REDACTED]")
      .replace(new RegExp(process.env.SMTP_USER || "____never____", "gi"), "[USER]");
    message = scrubbed;
  }

  return {
    code,
    message,
    responseCode
  };
}

module.exports = {
  getTransporter,
  setTransporter,
  resetTransporter,
  verifyConnection,
  sendMail,
  sanitizeSmtpError
};
