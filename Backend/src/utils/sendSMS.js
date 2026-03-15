import nodemailer from "nodemailer";

export const sendEmail = async (email, message) => {
  try {
    const transporter = nodemailer.createTransport({
      service: "gmail",
      host: "smtp.gmail.com",
      port: 587,
      secure: false,
      auth: {
        user: process.env.GMAIL_EMAIL,
        pass: process.env.GMAIL_APP_PASSWORD
      }
    });

    const mailOptions = {
      from: process.env.GMAIL_EMAIL,
      to: email,
      subject: "OTP Verification",
      html: message
    };

    const info = await transporter.sendMail(mailOptions);

    console.log(`✅ Email sent to ${email}`, info.response);
  } catch (error) {
    console.error("❌ Email error:", error.message);
  }
};