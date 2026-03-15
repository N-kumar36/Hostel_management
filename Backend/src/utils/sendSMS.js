import nodemailer from "nodemailer";

export const sendEmail = async (email, message) => {
  // console.log(`📧 Sending Email to ${email} with message: "${message}"`);

  try {
    const transporter = nodemailer.createTransport({
      service: "gmail",
      host: "smpt.gmail.com",
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