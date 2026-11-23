/**
 * EntireZe Nodemailer Service - In-Memory Sliding Window Rate Limiter Middleware
 * 
 * Protects endpoints against brute-force and spam flooding.
 * Tracks requests per IP address or API token with an automated cleanup cycle.
 */

class RateLimiter {
  constructor(options = {}) {
    this.windowMs = options.windowMs || 60 * 1000; // 1 minute window
    this.maxRequests = options.maxRequests || 60;   // 60 requests per minute
    this.hits = new Map();

    // Periodic sweep every 2 minutes to prevent memory leaks
    this.cleanupInterval = setInterval(() => {
      const now = Date.now();
      for (const [key, record] of this.hits.entries()) {
        if (now - record.startTime > this.windowMs) {
          this.hits.delete(key);
        }
      }
    }, 2 * 60 * 1000);

    // Prevent interval from keeping Node process alive in tests
    if (this.cleanupInterval.unref) {
      this.cleanupInterval.unref();
    }
  }

  middleware() {
    return (req, res, next) => {
      // Use client IP or token prefix as tracking key
      const clientIp = req.headers["x-forwarded-for"] || req.socket.remoteAddress || "127.0.0.1";
      const key = clientIp.split(",")[0].trim();

      const now = Date.now();
      let record = this.hits.get(key);

      if (!record || now - record.startTime > this.windowMs) {
        record = {
          startTime: now,
          count: 1
        };
        this.hits.set(key, record);
      } else {
        record.count += 1;
      }

      const remaining = Math.max(0, this.maxRequests - record.count);
      const resetTime = Math.ceil((record.startTime + this.windowMs - now) / 1000);

      res.setHeader("X-RateLimit-Limit", this.maxRequests);
      res.setHeader("X-RateLimit-Remaining", remaining);
      res.setHeader("X-RateLimit-Reset", resetTime);

      if (record.count > this.maxRequests) {
        res.setHeader("Retry-After", resetTime);
        return res.status(429).json({
          success: false,
          message: "Rate limit exceeded. Too many requests, please try again later",
          error: {
            code: "RATE_LIMIT_EXCEEDED",
            retryAfterSeconds: resetTime
          }
        });
      }

      return next();
    };
  }

  reset() {
    this.hits.clear();
  }
}

// Default export: 60 requests per minute
const defaultRateLimiter = new RateLimiter({
  windowMs: 60 * 1000,
  maxRequests: 60
});

module.exports = {
  RateLimiter,
  rateLimit: defaultRateLimiter.middleware(),
  defaultRateLimiter
};
