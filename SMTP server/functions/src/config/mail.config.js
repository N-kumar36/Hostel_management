/**
 * EntireZe Nodemailer Service - Mail Configuration
 * 
 * Configures generic standard SMTP transport:
 * Supports Gmail, Outlook/Office365, Amazon SES SMTP, Mailgun SMTP, Brevo SMTP,
 * or any custom/self-hosted SMTP server.
 * 
 * In production on Firebase Cloud Functions v2, these variables are bound
 * securely via Firebase Secret Manager.
 */

/**
 * Returns validated SMTP configuration from environment or Secret Manager.
 * @returns {Object} SMTP and default sender configuration
 */
function getMailConfig() {
  const host = process.env.SMTP_HOST || "smtp.gmail.com";
  const port = parseInt(process.env.SMTP_PORT || "465", 10);
  const secure = process.env.SMTP_SECURE === "true" || port === 465;
  const user = (process.env.SMTP_USER || "").trim();
  const pass = (process.env.SMTP_PASS || "").replace(/\s+/g, "");
  const defaultFromName = process.env.DEFAULT_FROM_NAME || "EntireZe Mail Service";
  const defaultFromEmail = process.env.DEFAULT_FROM_EMAIL || user || "noreply@entireze.local";

  return {
    smtp: {
      host,
      port,
      secure,
      auth: {
        user,
        pass
      },
      pool: true,
      maxConnections: parseInt(process.env.SMTP_MAX_CONNECTIONS || "5", 10),
      maxMessages: parseInt(process.env.SMTP_MAX_MESSAGES || "100", 10),
      connectionTimeout: parseInt(process.env.SMTP_CONN_TIMEOUT || "10000", 10), // 10s
      greetingTimeout: parseInt(process.env.SMTP_GREETING_TIMEOUT || "10000", 10),   // 10s
      socketTimeout: parseInt(process.env.SMTP_SOCKET_TIMEOUT || "15000", 10)       // 15s
    },
    defaults: {
      fromName: defaultFromName,
      fromEmail: defaultFromEmail,
      formattedFrom: defaultFromName ? `"${defaultFromName}" <${defaultFromEmail}>` : defaultFromEmail
    }
  };
}

module.exports = {
  getMailConfig
};
