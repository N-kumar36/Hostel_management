/**
 * Automated Verification for emailClient.js
 */

const assert = require("assert");
const emailClient = require("./emailClient");

process.env.MAIL_API_URL = "http://localhost:5001/api/v1/send";
process.env.MAIL_API_KEY = "test_secret_key_12345";

async function runClientTests() {
  console.log("=== Running EntireZe Email Client SDK Tests ===\n");

  let lastRequestConfig = null;

  // Mock axios instance to test Axios integration
  const mockAxios = {
    post: async (url, data, config) => {
      lastRequestConfig = { url, data, config };
      return {
        status: 200,
        data: {
          success: true,
          message: "Email sent successfully",
          data: { messageId: "<client-mock-12345@entireze.local>" }
        }
      };
    }
  };

  emailClient.setAxiosInstance(mockAxios);

  // Test 1: Single recipient sendEmail()
  console.log("[Test 1] Testing sendEmail() with single recipient...");
  const res1 = await emailClient.sendEmail(
    "user@gmail.com",
    "Welcome",
    "<h1>Welcome!</h1>",
    { senderName: "My App" }
  );
  assert.strictEqual(res1.success, true);
  assert.strictEqual(lastRequestConfig.url, process.env.MAIL_API_URL);
  assert.strictEqual(lastRequestConfig.config.headers.Authorization, `Bearer ${process.env.MAIL_API_KEY}`);
  assert.strictEqual(lastRequestConfig.data.to, "user@gmail.com");
  assert.strictEqual(lastRequestConfig.data.senderName, "My App");
  console.log("  ✓ Headers, URL, and payload verified successfully.");

  // Test 2: Multiple recipients sendEmail()
  console.log("[Test 2] Testing sendEmail() with multiple recipients array...");
  const recipients = ["user1@gmail.com", "user2@gmail.com"];
  await emailClient.sendEmail(recipients, "Broadcast", "<h1>Notice</h1>");
  assert.deepStrictEqual(lastRequestConfig.data.to, recipients);
  console.log("  ✓ Multiple recipients array passed accurately.");

  // Test 3: sendOtpEmail()
  console.log("[Test 3] Testing sendOtpEmail()...");
  const myGeneratedOtp = "789123";
  await emailClient.sendOtpEmail("student@hostel.com", myGeneratedOtp, "HostelApp");
  assert(lastRequestConfig.data.htmlContent.includes(myGeneratedOtp), "HTML must embed the generated OTP");
  assert(lastRequestConfig.data.subject.includes("Verification Code"));
  console.log("  ✓ OTP code properly rendered in template.");

  // Test 4: sendVerificationEmail()
  console.log("[Test 4] Testing sendVerificationEmail()...");
  const verifyUrl = "https://hostelapp.com/verify?token=xyz987";
  await emailClient.sendVerificationEmail("resident@hostel.com", verifyUrl, "HostelApp");
  assert(lastRequestConfig.data.htmlContent.includes(verifyUrl), "HTML must embed the verification link");
  console.log("  ✓ Verification URL properly rendered in template.");

  // Test 5: sendPasswordResetEmail()
  console.log("[Test 5] Testing sendPasswordResetEmail()...");
  const resetUrl = "https://hostelapp.com/reset?token=abc1234";
  await emailClient.sendPasswordResetEmail("resident@hostel.com", resetUrl, "HostelApp");
  assert(lastRequestConfig.data.htmlContent.includes(resetUrl), "HTML must embed the password reset link");
  console.log("  ✓ Password reset URL properly rendered in template.");

  console.log("\n=== All 5 Email Client Tests Passed Successfully! ===");
}

runClientTests().catch((err) => {
  console.error("Client test failed:", err);
  process.exit(1);
});
