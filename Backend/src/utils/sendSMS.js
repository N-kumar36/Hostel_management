import nodemailer from "nodemailer";

export const sendEmail = async (email, message) => {
  try {
    const transporter = nodemailer.createTransport({
      host: "smtp.gmail.com",
      port: 465,
      secure: true,
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

    console.log("Email sent:", info.response);

  } catch (error) {
    console.error("❌ Email error:", error);
  }
};