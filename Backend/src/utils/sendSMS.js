import nodemailer from "nodemailer";

export const sendEmail = async (email, message) => {
  try {
    const transporter = nodemailer.createTransport({
      host: "smtp.gmail.com",
      port: 465,
      secure: true, // Use SSL
      auth: {
        user: process.env.GMAIL_EMAIL,
        pass: process.env.GMAIL_APP_PASSWORD
      },
      // ✅ FORCES IPv4 (Fixes ENETUNREACH on Render)
      family: 4, 
      // Improves performance by reusing connections
      pool: true, 
      // Prevents the connection from hanging too long
      connectionTimeout: 10000, 
      greetingTimeout: 5000,
    });

    const mailOptions = {
      from: `"Hostel Mess" <${process.env.GMAIL_EMAIL}>`,
      to: email,
      subject: "OTP Verification",
      html: message
    };

    const info = await transporter.sendMail(mailOptions);
    console.log("✅ Email sent successfully:", info.response);

  } catch (error) {
    // If it still fails, this log will help us see exactly why
    console.error("❌ Email error details:", {
      code: error.code,
      command: error.command,
      message: error.message
    });
  }
};