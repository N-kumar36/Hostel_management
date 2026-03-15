import { Resend } from 'resend';

export const sendEmail = async (email, message) => {
 
  const resend = new Resend(process.env.RESEND_API_KEY);

  try {
    const { data, error } = await resend.emails.send({
      from: 'HostelMess <onboarding@resend.dev>',
      to: email,
      subject: 'OTP Verification',
      html: message,
    });

    if (error) return console.error("❌ Resend Error:", error);
    console.log("✅ Email sent:", data.id);
  } catch (error) {
    console.error("❌ System Error:", error.message);
  }
};