import { BrevoClient } from '@getbrevo/brevo';

export const sendEmail = async (email, message) => {
  // 1. Initialize the new BrevoClient
  const client = new BrevoClient({
    apiKey: process.env.BREVO_API_KEY,
  });

  try {
    // 2. Use the simplified transactionalEmails method
    const result = await client.transactionalEmails.sendTransacEmail({
      subject: "OTP Verification",
      htmlContent: message,
      sender: { 
        name: "Hostel Mess", 
        email: "nitya3666@gmail.com" 
      },
      to: [{ 
        email: email 
      }],
    });

    console.log("✅ Email sent successfully! Message ID:", result.messageId);

  } catch (error) {
    // 3. Robust error handling
    console.error("❌ Brevo API Error:", error.message);
    if (error.body) {
      console.error("Details:", JSON.stringify(error.body));
    }
  }
};