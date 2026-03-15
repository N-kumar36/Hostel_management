import nodemailer from "nodemailer";

export const sendEmail = async (email, message) => {
  try {
    const transporter = nodemailer.createTransport({
      // ✅ Use the direct IP instead of the hostname to bypass IPv6 issues
      host: "74.125.24.108", 
      port: 465,
      secure: true,
      auth: {
        user: process.env.GMAIL_EMAIL,
        pass: process.env.GMAIL_APP_PASSWORD
      },
      // ✅ Force IPv4 stack
      family: 4, 
      // ✅ Crucial for Gmail when using IP directly
      tls: {
        servername: 'smtp.gmail.com',
        rejectUnauthorized: false // Helps if Render has certificate trust issues
      },
      connectionTimeout: 20000, // Increased timeout for Render Free Tier
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
    console.error("❌ Email error details:", error);
  }
};