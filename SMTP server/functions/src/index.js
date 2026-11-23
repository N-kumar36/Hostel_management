/**
 * EntireZe Nodemailer Service - Express Application Core
 * Decoupled from Cloud Functions runtime for testability.
 */

const express = require("express");
const cors = require("cors");
const emailRoutes = require("./routes/email.routes");

const app = express();

// Security: Disable x-powered-by header
app.disable("x-powered-by");

// CORS Configuration:
// NOTE: CORS is browser-only access control and MUST NEVER be treated as authentication.
const corsOptions = {
  origin: "*",
  methods: ["GET", "POST", "OPTIONS"],
  allowedHeaders: ["Content-Type", "Authorization", "X-Requested-With"],
  maxAge: 86400 // 24 hours preflight cache
};

app.use(cors(corsOptions));

// Request body size limit: 2MB to prevent memory exhaustion
app.use(express.json({ limit: "2mb" }));
app.use(express.urlencoded({ extended: true, limit: "2mb" }));

// Mount Versioned Routes
app.use("/api/v1", emailRoutes);
// Also mount at root for Firebase Hosting rewrite flexibility
app.use("/", emailRoutes);

// 404 Handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: `Cannot ${req.method} ${req.originalUrl}`,
    error: {
      code: "ROUTE_NOT_FOUND"
    }
  });
});

// Secure Error Handler (Never leaks stack traces, internal paths, or credentials)
app.use((err, req, res, next) => {
  console.error("[App Error]", err.message || err);

  const status = err.statusCode || 500;
  res.status(status).json({
    success: false,
    message: err.message || "Internal server error",
    error: {
      code: err.code || "INTERNAL_SERVER_ERROR"
    }
  });
});

module.exports = app;
