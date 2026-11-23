/**
 * EntireZe Nodemailer Service - Bearer API Key Authentication Middleware
 * 
 * Enforces timing-safe token verification against MAIL_API_KEY.
 * Prevents open relay abuse by rejecting unauthenticated requests.
 */

const crypto = require("crypto");

/**
 * Timing-safe string comparison to mitigate timing attacks.
 * @param {string} a
 * @param {string} b
 * @returns {boolean}
 */
function safeCompare(a, b) {
  if (typeof a !== "string" || typeof b !== "string") return false;
  const bufA = Buffer.from(a);
  const bufB = Buffer.from(b);
  if (bufA.length !== bufB.length) return false;
  return crypto.timingSafeEqual(bufA, bufB);
}

/**
 * Express middleware for Bearer API Key verification.
 */
function authenticateApiKey(req, res, next) {
  const authHeader = req.headers.authorization;

  if (!authHeader || typeof authHeader !== "string") {
    return res.status(401).json({
      success: false,
      message: "Authentication required. Missing Authorization header",
      error: { code: "AUTH_HEADER_MISSING" }
    });
  }

  const parts = authHeader.trim().split(" ");
  if (parts.length !== 2 || parts[0].toLowerCase() !== "bearer") {
    return res.status(401).json({
      success: false,
      message: "Invalid Authorization header format. Expected 'Bearer <API_KEY>'",
      error: { code: "INVALID_AUTH_FORMAT" }
    });
  }

  const providedKey = parts[1];
  const configuredKeys = (process.env.MAIL_API_KEY || "")
    .split(",")
    .map((k) => k.trim())
    .filter(Boolean);

  // Fail closed: If no API key is configured on server, reject all requests
  if (configuredKeys.length === 0) {
    console.error("[Auth] CRITICAL: MAIL_API_KEY is not configured on server.");
    return res.status(500).json({
      success: false,
      message: "Service authentication is improperly configured on server",
      error: { code: "SERVER_AUTH_CONFIG_ERROR" }
    });
  }

  // Check against all valid configured keys using timing-safe comparison
  const isValid = configuredKeys.some((validKey) => safeCompare(providedKey, validKey));

  if (!isValid) {
    return res.status(403).json({
      success: false,
      message: "Forbidden: Invalid API key",
      error: { code: "INVALID_API_KEY" }
    });
  }

  // Attach auth metadata
  req.authenticated = true;
  return next();
}

module.exports = {
  authenticateApiKey,
  safeCompare
};
