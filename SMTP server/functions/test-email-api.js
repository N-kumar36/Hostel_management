/**
 * Automated Verification for EntireZe Email API Authentication & Security
 */

const assert = require("assert");
const app = require("./src/index");
const smtpService = require("./src/services/smtp.service");
const { defaultRateLimiter, RateLimiter } = require("./src/middleware/rate-limit.middleware");

const TEST_API_KEY = "test_secret_api_key_entireze_2026";
process.env.MAIL_API_KEY = TEST_API_KEY;

function invokeApp(method, url, body = null, headers = {}) {
  return new Promise((resolve) => {
    const reqHeaders = {
      "content-type": "application/json",
      ...headers
    };

    const req = {
      method,
      url,
      originalUrl: url,
      path: url,
      headers: reqHeaders,
      body: body || {},
      _body: true,
      socket: { remoteAddress: "127.0.0.1" }
    };

    let statusCode = 200;
    const resHeaders = {};
    const res = {
      status(code) {
        statusCode = code;
        return this;
      },
      set(field, val) {
        if (typeof field === "object") {
          Object.assign(resHeaders, field);
        } else {
          resHeaders[String(field).toLowerCase()] = val;
        }
        return this;
      },
      setHeader(field, val) {
        resHeaders[String(field).toLowerCase()] = val;
        return this;
      },
      getHeader(field) {
        return resHeaders[String(field).toLowerCase()];
      },
      json(data) {
        resolve({ status: statusCode, body: data, headers: resHeaders });
      },
      send(data) {
        let parsed = data;
        try {
          parsed = JSON.parse(data);
        } catch (_) {}
        resolve({ status: statusCode, body: parsed, headers: resHeaders });
      }
    };

    app.handle(req, res);
  });
}

async function runSecurityTests() {
  console.log("=== Running EntireZe Email API Authentication & Security Tests ===\n");

  // Setup: Mock transporter in smtpService
  let lastSentMailOptions = null;
  const mockTransporter = {
    sendMail: async (options) => {
      lastSentMailOptions = options;
      return {
        messageId: "<mock-secure-msg-id@entireze.local>",
        accepted: Array.isArray(options.to) ? options.to : [options.to],
        rejected: []
      };
    },
    verify: async () => true
  };
  smtpService.setTransporter(mockTransporter);

  // Reset rate limiter hits
  defaultRateLimiter.reset();

  // Test 1: Reject request with missing Authorization header
  console.log("[Test 1] Missing Authorization header -> Expected 401...");
  const res1 = await invokeApp("POST", "/api/v1/send", {
    to: "user@gmail.com",
    subject: "Test",
    htmlContent: "<p>Test</p>"
  });
  assert.strictEqual(res1.status, 401);
  assert.strictEqual(res1.body.error.code, "AUTH_HEADER_MISSING");
  console.log("  ✓ Rejected with 401 AUTH_HEADER_MISSING.");

  // Test 2: Reject request with malformed Authorization header
  console.log("[Test 2] Malformed Authorization header -> Expected 401...");
  const res2 = await invokeApp("POST", "/api/v1/send", {
    to: "user@gmail.com",
    subject: "Test",
    htmlContent: "<p>Test</p>"
  }, { authorization: "Basic some_basic_token" });
  assert.strictEqual(res2.status, 401);
  assert.strictEqual(res2.body.error.code, "INVALID_AUTH_FORMAT");
  console.log("  ✓ Rejected with 401 INVALID_AUTH_FORMAT.");

  // Test 3: Reject request with invalid Bearer API key
  console.log("[Test 3] Invalid Bearer API key -> Expected 403...");
  const res3 = await invokeApp("POST", "/api/v1/send", {
    to: "user@gmail.com",
    subject: "Test",
    htmlContent: "<p>Test</p>"
  }, { authorization: "Bearer wrong_invalid_api_key" });
  assert.strictEqual(res3.status, 403);
  assert.strictEqual(res3.body.error.code, "INVALID_API_KEY");
  console.log("  ✓ Rejected with 403 INVALID_API_KEY.");

  // Test 4: Success with valid Bearer API key
  console.log("[Test 4] Valid Bearer API key -> Expected 200 OK...");
  const authHeader = { authorization: `Bearer ${TEST_API_KEY}` };
  const res4 = await invokeApp("POST", "/api/v1/send", {
    to: "customer@gmail.com",
    subject: "Your OTP Verification",
    htmlContent: "<h1>Your OTP is 123456</h1>"
  }, authHeader);
  assert.strictEqual(res4.status, 200);
  assert.strictEqual(res4.body.success, true);
  assert(res4.body.data && res4.body.data.messageId);
  console.log("  ✓ Authenticated request succeeded with 200 OK.");

  // Test 5: Recipient limit enforcement (> 50 recipients)
  console.log("[Test 5] Recipient limit enforcement (> 50 recipients)...");
  const excessiveRecipients = [];
  for (let i = 0; i < 55; i++) {
    excessiveRecipients.push(`user${i}@example.com`);
  }
  const res5 = await invokeApp("POST", "/api/v1/send", {
    to: excessiveRecipients,
    subject: "Mass spam attempt",
    htmlContent: "<p>Spam</p>"
  }, authHeader);
  assert.strictEqual(res5.status, 400);
  assert.strictEqual(res5.body.error.code, "RECIPIENT_LIMIT_EXCEEDED");
  console.log("  ✓ Blocked mass recipients with 400 RECIPIENT_LIMIT_EXCEEDED.");

  // Test 6: Header injection prevention in subject (\r\n)
  console.log("[Test 6] Header injection attempt in subject line...");
  const res6 = await invokeApp("POST", "/api/v1/send", {
    to: "victim@example.com",
    subject: "Injected Subject\r\nBcc: secret@hacker.com",
    htmlContent: "<p>Exploit</p>"
  }, authHeader);
  assert.strictEqual(res6.status, 400);
  assert.strictEqual(res6.body.error.code, "ILLEGAL_SUBJECT_CHARACTERS");
  console.log("  ✓ Blocked CRLF injection with 400 ILLEGAL_SUBJECT_CHARACTERS.");

  // Test 7: HTML content size limit enforcement
  console.log("[Test 7] Massive HTML content exceeding 500KB limit...");
  const hugeHtml = "<p>" + "A".repeat(501 * 1024) + "</p>";
  const res7 = await invokeApp("POST", "/api/v1/send", {
    to: "user@gmail.com",
    subject: "Huge payload",
    htmlContent: hugeHtml
  }, authHeader);
  assert.strictEqual(res7.status, 400);
  assert.strictEqual(res7.body.error.code, "HTML_CONTENT_TOO_LARGE");
  console.log("  ✓ Blocked oversized HTML with 400 HTML_CONTENT_TOO_LARGE.");

  // Test 8: Invalid attachment structure
  console.log("[Test 8] Invalid attachment structure (missing filename)...");
  const res8 = await invokeApp("POST", "/api/v1/send", {
    to: "user@gmail.com",
    subject: "Invoice",
    htmlContent: "<p>See attached</p>",
    attachments: [{ content: "abc" }] // missing filename
  }, authHeader);
  assert.strictEqual(res8.status, 400);
  assert.strictEqual(res8.body.error.code, "INVALID_ATTACHMENT_FILENAME");
  console.log("  ✓ Blocked malformed attachment with 400 INVALID_ATTACHMENT_FILENAME.");

  // Test 9: Rate limiter enforcement (exceeding max requests)
  console.log("[Test 9] Rate limiter test (burst flooding)...");
  const strictLimiter = new RateLimiter({ windowMs: 10000, maxRequests: 3 });
  const testMiddleware = strictLimiter.middleware();
  let blocked = false;
  let retryAfterHeader = null;

  for (let i = 0; i < 5; i++) {
    const mockReq = { headers: {}, socket: { remoteAddress: "192.168.1.100" } };
    const mockRes = {
      statusCode: 200,
      headers: {},
      setHeader(k, v) { this.headers[k] = v; },
      status(c) { this.statusCode = c; return this; },
      json(data) {
        if (this.statusCode === 429) {
          blocked = true;
          retryAfterHeader = this.headers["Retry-After"];
        }
      }
    };
    testMiddleware(mockReq, mockRes, () => {});
  }
  assert.strictEqual(blocked, true, "Rate limiter must block after exceeding limit");
  assert(retryAfterHeader, "Rate limiter must set Retry-After header");
  console.log("  ✓ Rate limiter blocked excess requests with 429 RATE_LIMIT_EXCEEDED.");

  // Test 10: Public health check bypasses auth
  console.log("[Test 10] Public health endpoint /api/v1/health (no auth)...");
  const res10 = await invokeApp("GET", "/api/v1/health");
  assert.strictEqual(res10.status, 200);
  assert.strictEqual(res10.body.data.status, "UP");
  console.log("  ✓ Public endpoint accessible without auth.");

  console.log("\n=== All 10 Authentication & Security Tests Passed Successfully! ===");
}

runSecurityTests().catch((err) => {
  console.error("Security test failed:", err);
  process.exit(1);
});
