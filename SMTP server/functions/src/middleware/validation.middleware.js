/**
 * EntireZe Nodemailer Service - Request Validation Middleware
 * 
 * Strict input sanitization and boundary checking:
 * - RFC 5322 email syntax
 * - Header injection prevention (\r, \n)
 * - Recipient count limits (max 50)
 * - Subject length limits (max 500 chars)
 * - HTML content limits (max 500KB)
 * - Attachment size limits
 */

const EMAIL_REGEX = /^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$/;

const MAX_RECIPIENTS = 50;
const MAX_SUBJECT_LENGTH = 500;
const MAX_HTML_LENGTH = 500 * 1024; // 500 KB
const MAX_SENDER_NAME_LENGTH = 100;
const MAX_ATTACHMENTS = 10;
const MAX_SINGLE_ATTACHMENT_SIZE = 5 * 1024 * 1024; // 5 MB

/**
 * Validates an email address.
 * Rejects control characters, newlines, and non-RFC5322 syntax.
 */
function isValidEmail(email) {
  if (!email || typeof email !== "string") return false;
  const trimmed = email.trim();
  if (trimmed.length > 254) return false;
  if (/[\r\n\t]/.test(trimmed)) return false; // Prevent CRLF header injection
  return EMAIL_REGEX.test(trimmed);
}

/**
 * Middleware validating POST /api/v1/send payload
 */
function validateSendPayload(req, res, next) {
  const { to, subject, htmlContent, senderName, cc, bcc, replyTo, attachments } = req.body || {};

  // 1. Recipient 'to' validation
  if (!to) {
    return res.status(400).json({
      success: false,
      message: "Field 'to' is required (string or array of email addresses)",
      error: { code: "MISSING_RECIPIENT" }
    });
  }

  const recipients = Array.isArray(to) ? to : [to];

  if (recipients.length === 0) {
    return res.status(400).json({
      success: false,
      message: "Recipient list 'to' cannot be empty",
      error: { code: "EMPTY_RECIPIENT_LIST" }
    });
  }

  if (recipients.length > MAX_RECIPIENTS) {
    return res.status(400).json({
      success: false,
      message: `Recipient count exceeds maximum limit of ${MAX_RECIPIENTS}`,
      error: { code: "RECIPIENT_LIMIT_EXCEEDED" }
    });
  }

  const invalidRecipients = recipients.filter((email) => !isValidEmail(email));
  if (invalidRecipients.length > 0) {
    return res.status(400).json({
      success: false,
      message: `Invalid recipient email address(es): ${invalidRecipients.join(", ")}`,
      error: { code: "INVALID_EMAIL_FORMAT", details: invalidRecipients }
    });
  }

  // 2. Subject validation
  if (!subject || typeof subject !== "string" || subject.trim() === "") {
    return res.status(400).json({
      success: false,
      message: "Field 'subject' is required and must not be empty",
      error: { code: "MISSING_SUBJECT" }
    });
  }

  if (subject.length > MAX_SUBJECT_LENGTH) {
    return res.status(400).json({
      success: false,
      message: `Field 'subject' exceeds maximum length of ${MAX_SUBJECT_LENGTH} characters`,
      error: { code: "SUBJECT_TOO_LONG" }
    });
  }

  // Header injection check in subject
  if (/[\r\n]/.test(subject)) {
    return res.status(400).json({
      success: false,
      message: "Field 'subject' contains illegal newline characters",
      error: { code: "ILLEGAL_SUBJECT_CHARACTERS" }
    });
  }

  // 3. HTML content validation
  if (!htmlContent || typeof htmlContent !== "string" || htmlContent.trim() === "") {
    return res.status(400).json({
      success: false,
      message: "Field 'htmlContent' is required and must not be empty",
      error: { code: "MISSING_HTML_CONTENT" }
    });
  }

  if (htmlContent.length > MAX_HTML_LENGTH) {
    return res.status(400).json({
      success: false,
      message: `Field 'htmlContent' exceeds maximum allowed size of ${MAX_HTML_LENGTH / 1024} KB`,
      error: { code: "HTML_CONTENT_TOO_LARGE" }
    });
  }

  // 4. Sender name validation
  if (senderName) {
    if (typeof senderName !== "string" || senderName.length > MAX_SENDER_NAME_LENGTH) {
      return res.status(400).json({
        success: false,
        message: `Field 'senderName' must not exceed ${MAX_SENDER_NAME_LENGTH} characters`,
        error: { code: "SENDER_NAME_TOO_LONG" }
      });
    }
    if (/[\r\n]/.test(senderName)) {
      return res.status(400).json({
        success: false,
        message: "Field 'senderName' contains illegal newline characters",
        error: { code: "ILLEGAL_SENDER_NAME_CHARACTERS" }
      });
    }
  }

  // 5. CC validation
  if (cc) {
    const ccList = Array.isArray(cc) ? cc : [cc];
    if (ccList.length > MAX_RECIPIENTS) {
      return res.status(400).json({
        success: false,
        message: `CC recipient count exceeds maximum limit of ${MAX_RECIPIENTS}`,
        error: { code: "CC_LIMIT_EXCEEDED" }
      });
    }
    const invalidCc = ccList.filter((email) => !isValidEmail(email));
    if (invalidCc.length > 0) {
      return res.status(400).json({
        success: false,
        message: `Invalid CC email address(es): ${invalidCc.join(", ")}`,
        error: { code: "INVALID_CC_EMAIL_FORMAT", details: invalidCc }
      });
    }
  }

  // 6. BCC validation
  if (bcc) {
    const bccList = Array.isArray(bcc) ? bcc : [bcc];
    if (bccList.length > MAX_RECIPIENTS) {
      return res.status(400).json({
        success: false,
        message: `BCC recipient count exceeds maximum limit of ${MAX_RECIPIENTS}`,
        error: { code: "BCC_LIMIT_EXCEEDED" }
      });
    }
    const invalidBcc = bccList.filter((email) => !isValidEmail(email));
    if (invalidBcc.length > 0) {
      return res.status(400).json({
        success: false,
        message: `Invalid BCC email address(es): ${invalidBcc.join(", ")}`,
        error: { code: "INVALID_BCC_EMAIL_FORMAT", details: invalidBcc }
      });
    }
  }

  // 7. Reply-To validation
  if (replyTo && !isValidEmail(replyTo)) {
    return res.status(400).json({
      success: false,
      message: `Invalid 'replyTo' email address: ${replyTo}`,
      error: { code: "INVALID_REPLY_TO" }
    });
  }

  // 8. Attachments validation
  if (attachments) {
    if (!Array.isArray(attachments)) {
      return res.status(400).json({
        success: false,
        message: "Field 'attachments' must be an array",
        error: { code: "INVALID_ATTACHMENTS_FORMAT" }
      });
    }

    if (attachments.length > MAX_ATTACHMENTS) {
      return res.status(400).json({
        success: false,
        message: `Attachment count exceeds maximum limit of ${MAX_ATTACHMENTS}`,
        error: { code: "ATTACHMENT_COUNT_EXCEEDED" }
      });
    }

    for (let i = 0; i < attachments.length; i++) {
      const att = attachments[i];
      if (!att.filename || typeof att.filename !== "string") {
        return res.status(400).json({
          success: false,
          message: `Attachment at index ${i} is missing a valid 'filename'`,
          error: { code: "INVALID_ATTACHMENT_FILENAME" }
        });
      }
      if (att.content && typeof att.content === "string") {
        // Base64 or string content length check
        const approxSize = Buffer.byteLength(att.content, "utf8");
        if (approxSize > MAX_SINGLE_ATTACHMENT_SIZE) {
          return res.status(400).json({
            success: false,
            message: `Attachment '${att.filename}' exceeds size limit of ${MAX_SINGLE_ATTACHMENT_SIZE / (1024 * 1024)} MB`,
            error: { code: "ATTACHMENT_SIZE_EXCEEDED" }
          });
        }
      }
    }
  }

  return next();
}

module.exports = {
  isValidEmail,
  validateSendPayload,
  MAX_RECIPIENTS,
  MAX_SUBJECT_LENGTH,
  MAX_HTML_LENGTH
};
