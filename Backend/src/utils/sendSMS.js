import nodemailer from "nodemailer";


export const sendEmail = async (email, message) => {
  try {
    const transporter = nodemailer.createTransport({
      host: "smtp-relay.brevo.com",
      port: 587,
      secure: false, // TLS
      auth: {
        user: "a50b40001@smtp-brevo.com",
        pass: process.env.BREVO_SMTP_KEY
      },
      family: 4
    });

    const mailOptions = {
      from: '"Hostel Mess" <nitya3666@gmail.com>',
      to: email,
      subject: "OTP Verification",
      html: message
    };

    const info = await transporter.sendMail(mailOptions);
    console.log(" Email sent via Brevo:", info.response);

  } catch (error) {
    // This will help us see if the key is actually missing
    if (!process.env.BREVO_SMTP_KEY) {
      console.error("❌ ERROR: BREVO_SMTP_KEY is missing from environment variables!");
    }
    console.error("❌ Brevo SMTP Error:", error.message);
  }
};