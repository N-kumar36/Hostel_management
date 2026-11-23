/**
 * EntireZe Nodemailer Service - Email Business Service
 * 
 * Handles email validation, recipient normalization, sender spoofing prevention,
 * and dispatch delegation to smtp.service.
 */

const smtpService = require("./smtp.service");

// Standard RFC 5322 compliant email regex
const EMAIL_REGEX = /^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$/;

/**
 * Validates an email string.
 * @param {string} email
 * @returns {boolean}
 */
function isValidEmail(email) {
  if (!email || typeof email !== "string") return false;
  const trimmed = email.trim();
  return trimmed.length <= 254 && EMAIL_REGEX.test(trimmed);
}

/**
 * Normalizes and validates recipients.
 * Accepts single email string or array of email strings.
 * 
 * @param {string|string[]} to
 * @returns {string[]} Array of sanitized email addresses
 */
function validateAndNormalizeRecipients(to) {
  if (!to) {
    const error = new Error("Recipient 'to' field is required");
    error.statusCode = 400;
    error.code = "MISSING_RECIPIENT";
    throw error;
  }

  const list = Array.isArray(to) ? to : [to];

  if (list.length === 0) {
    const error = new Error("Recipient list cannot be empty");
    error.statusCode = 400;
    error.code = "EMPTY_RECIPIENT_LIST";
    throw error;
  }

  const cleaned = [];
  const invalid = [];

  for (const item of list) {
    if (typeof item === "string" && isValidEmail(item.trim())) {
      cleaned.push(item.trim());
    } else {
      invalid.push(String(item));
    }
  }

  if (invalid.length > 0) {
    const error = new Error(`Invalid email address(es): ${invalid.join(", ")}`);
    error.statusCode = 400;
    error.code = "INVALID_EMAIL_FORMAT";
    error.invalidEmails = invalid;
    throw error;
  }

  return cleaned;
}

/**
 * Sends an email with full validation and anti-spoofing guarantees.
 * 
 * @param {Object} payload
 * @param {string|string[]} payload.to - Single recipient or array of recipients
 * @param {string} payload.subject - Email subject
 * @param {string} payload.htmlContent - HTML body content
 * @param {string} [payload.senderName] - Optional custom display sender name
 * @param {string} [payload.text] - Optional plain text alternative
 * @param {string|string[]} [payload.cc] - Optional CC recipient(s)
 * @param {string|string[]} [payload.bcc] - Optional BCC recipient(s)
 * @param {string} [payload.replyTo] - Optional Reply-To address
 * @param {Array} [payload.attachments] - Optional attachments
 * @returns {Promise<{ messageId: string, accepted: string[], rejected: string[] }>}
 */
async function sendEmail({ to, subject, htmlContent, senderName, text, cc, bcc, replyTo, attachments }) {
  // 1. Validate & normalize recipients
  const recipients = validateAndNormalizeRecipients(to);

  // 2. Validate subject
  if (!subject || typeof subject !== "string" || subject.trim() === "") {
    const error = new Error("Email 'subject' is required and must not be empty");
    error.statusCode = 400;
    error.code = "MISSING_SUBJECT";
    throw error;
  }

  if (subject.length > 500) {
    const error = new Error("Email 'subject' exceeds maximum length of 500 characters");
    error.statusCode = 400;
    error.code = "SUBJECT_TOO_LONG";
    throw error;
  }

  // 3. Validate HTML content
  if (!htmlContent || typeof htmlContent !== "string" || htmlContent.trim() === "") {
    const error = new Error("Email 'htmlContent' is required and must not be empty");
    error.statusCode = 400;
    error.code = "MISSING_HTML_CONTENT";
    throw error;
  }

  // 4. Validate optional CC and BCC if provided
  let normalizedCc = undefined;
  if (cc) {
    normalizedCc = validateAndNormalizeRecipients(cc);
  }

  let normalizedBcc = undefined;
  if (bcc) {
    normalizedBcc = validateAndNormalizeRecipients(bcc);
  }

  // 5. Validate replyTo if provided
  if (replyTo && !isValidEmail(replyTo)) {
    const error = new Error(`Invalid 'replyTo' email address: ${replyTo}`);
    error.statusCode = 400;
    error.code = "INVALID_REPLY_TO";
    throw error;
  }

  // 6. Anti-Spoofing: sanitize optional senderName (strip newlines to prevent header injection)
  let sanitizedSenderName = undefined;
  if (senderName && typeof senderName === "string") {
    sanitizedSenderName = senderName.replace(/[\r\n\t]/g, " ").trim();
  }

  // 7. Plain text fallback generated from HTML if text not explicitly provided
  const plainText = text || htmlContent.replace(/<[^>]*>?/gm, "").trim();

  // 8. Dispatch via reusable SMTP service
  return await smtpService.sendMail({
    to: recipients,
    subject: subject.trim(),
    html: htmlContent,
    text: plainText,
    fromName: sanitizedSenderName,
    cc: normalizedCc,
    bcc: normalizedBcc,
    replyTo: replyTo ? replyTo.trim() : undefined,
    attachments: attachments || []
  });
}

module.exports = {
  isValidEmail,
  validateAndNormalizeRecipients,
  sendEmail
};
