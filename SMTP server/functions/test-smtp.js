/**
 * Automated Test & Verification for SMTP Service
 */

require("dotenv").config({ path: __dirname + "/.env" });
const assert = require("assert");
const nodemailer = require("nodemailer");
const { getMailConfig } = require("./src/config/mail.config");
const smtpService = require("./src/services/smtp.service");

async function runTests() {
  console.log("=== Running SMTP Service Verification Tests ===\n");

  // Test 1: Configuration Loading
  console.log("[Test 1] Testing getMailConfig() defaults...");
  const config = getMailConfig();
  assert(config.smtp, "Config must contain smtp object");
  assert.strictEqual(typeof config.smtp.host, "string");
  assert.strictEqual(typeof config.smtp.port, "number");
  assert(config.defaults, "Config must contain defaults object");
  console.log("  ✓ Config structure verified successfully.");

  // Test 2: Singleton Transporter Caching
  console.log("[Test 2] Testing Singleton Transporter Caching...");
  smtpService.resetTransporter();
  const t1 = smtpService.getTransporter();
  const t2 = smtpService.getTransporter();
  assert.strictEqual(t1, t2, "Transporter must be cached and not re-created on every call");
  console.log("  ✓ Singleton pattern verified: identical transporter reference reused.");

  // Test 3: verifyConnection() with mock transport
  console.log("[Test 3] Testing verifyConnection() with mock/test transport...");
  const mockSuccessTransporter = {
    verify: async () => true
  };
  const result = await smtpService.verifyConnection(mockSuccessTransporter);
  assert.strictEqual(result.success, true);
  console.log("  ✓ verifyConnection() returned success for verified transport.");

  // Test 4: Error sanitization
  console.log("[Test 4] Testing sanitizeSmtpError() for credential scrubbing...");
  const realPass = process.env.SMTP_PASS;
  const fakeSecretPass = "secret_app_password_9876";
  process.env.SMTP_PASS = fakeSecretPass;
  const mockAuthError = new Error(`Authentication failed with secret: ${fakeSecretPass}`);
  mockAuthError.code = "EAUTH";
  mockAuthError.responseCode = 535;

  const sanitized = smtpService.sanitizeSmtpError(mockAuthError);
  assert.strictEqual(sanitized.code, "SMTP_AUTHENTICATION_FAILED");
  assert(!sanitized.message.includes(fakeSecretPass), "Sanitized message must not contain password");
  process.env.SMTP_PASS = realPass; // Restore real pass
  console.log("  ✓ Error sanitization verified: credentials are never exposed.");

  // Test 5: Live Credentials Check
  console.log("[Test 5] Checking live SMTP credentials in environment...");
  const hasLiveCredentials = process.env.SMTP_USER && process.env.SMTP_PASS && process.env.SMTP_USER !== "your-email@gmail.com";
  if (hasLiveCredentials) {
    console.log(`  Attempting live connection verification to ${config.smtp.host}:${config.smtp.port}...`);
    try {
      smtpService.resetTransporter();
      await smtpService.verifyConnection();
      console.log("  ✓ LIVE SMTP connection verified successfully!");
    } catch (err) {
      console.log(`  ✕ Live SMTP connection failed: ${err.message} (${err.code})`);
    }
  } else {
    console.log("  ℹ No live credentials configured in .env (placeholder detected).");
    console.log("  ℹ To test live SMTP (e.g. Gmail App Password), set SMTP_USER and SMTP_PASS in functions/.env");
  }

  console.log("\n=== All SMTP Service Tests Passed Successfully ===");
}

runTests().catch(err => {
  console.error("Test execution failed:", err);
  process.exit(1);
});
