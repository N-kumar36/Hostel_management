import axios from "axios";

/**
 * Sends an email via the centralized Firebase Cloud Functions Email API.
 * 
 * @param {string|string[]} email - Recipient email or array of emails
 * @param {string} subject - Email subject
 * @param {string} message - HTML or text content
 * @param {Object} [options={}] - Optional settings (e.g. senderName)
 * @returns {Promise<Object|null>} - Returns response data on success, null on error
 */
export const sendEmail = async (email, subject, message, options = {}) => {
  const apiUrl = process.env.MAIL_API_URL || "https://emailapi-ahrobjcruq-el.a.run.app/send";
  const apiKey = process.env.MAIL_API_KEY || "your-high-entropy-api-key";

  if (!apiUrl || !apiKey) {
    console.error("❌ [Email Service] Missing MAIL_API_URL or MAIL_API_KEY in environment variables.");
    return null;
  }

  try {
    const payload = {
      to: email,
      subject,
      htmlContent: message,
      senderName: options.senderName || "Hostel Management"
    };

    const response = await axios.post(apiUrl, payload, {
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`
      },
      timeout: 15000 // 15s timeout
    });

    console.log("✅ [SMTP Service] Email delivered! Message ID:", response.data?.data?.messageId);
    return response.data;
  } catch (error) {
    console.error("❌ [SMTP Service Error]:", error.response?.data?.message || error.message);
    if (error.response?.data) {
      console.error("Details:", JSON.stringify(error.response.data));
    }
    return null;
  }
};

/**
 * Helper to send branded OTP verification emails
 * 
 * @param {string} email - Recipient email
 * @param {string|number} otp - Generated OTP code
 * @param {string} [appName="BOYS Hostel"] - Application name
 * @returns {Promise<Object|null>}
 */
export const sendOtpEmail = async (email, otp, appName = "BOYS Hostel") => {
  const subject = `${appName} OTP Verification`;
  const htmlContent = `
  <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background:#f4f6f8; padding:30px 15px;">
    <div style="max-width:500px; margin:0 auto; background:#ffffff; padding:35px; border-radius:10px; text-align:center; box-shadow:0 4px 15px rgba(0,0,0,0.06); border:1px solid #e2e8f0;">
      <h2 style="color:#1e293b; margin-top:0; font-size:22px;">${appName}</h2>
      <p style="color:#475569; font-size:15px; line-height:1.6;">
        Your One-Time Password (OTP) for verification is:
      </p>
      <div style="background-color:#f8fafc; border:2px dashed #cbd5e1; border-radius:8px; padding:18px; text-align:center; margin:25px 0;">
        <span style="font-size:32px; font-weight:800; letter-spacing:8px; color:#0284c7; font-family:monospace;">${otp}</span>
      </div>
      <p style="color:#64748b; font-size:13px; line-height:1.5;">
        This OTP is valid for <b>5 minutes</b>. If you did not request this OTP, please ignore this email.
      </p>
      <hr style="border:none; border-top:1px solid #e2e8f0; margin:25px 0;" />
      <p style="color:#94a3b8; font-size:11px; margin-bottom:0;">
        © ${new Date().getFullYear()} ${appName} Management System. All rights reserved.
      </p>
    </div>
  </div>
  `.trim();

  return await sendEmail(email, subject, htmlContent, { senderName: `${appName} Security` });
};

export default {
  sendEmail,
  sendOtpEmail
};