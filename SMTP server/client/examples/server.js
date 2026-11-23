/**
 * Express Application Example
 * 
 * Shows how to integrate EntireZe Email Client into an Express server.
 * 
 * Environment variables needed in the calling application:
 * - MAIL_API_URL=https://your-firebase-domain.web.app/api/v1/send
 * - MAIL_API_KEY=your-secret-api-key
 */

require("dotenv").config();
const express = require("express");
const authController = require("./auth.controller");

const app = express();
app.use(express.json());

// Auth & notification routes consuming the emailClient
app.post("/api/auth/register", authController.register);
app.post("/api/auth/request-otp", authController.requestLoginOtp);
app.post("/api/auth/verify-otp", authController.verifyLoginOtp);
app.post("/api/auth/forgot-password", authController.forgotPassword);
app.post("/api/admin/notify-residents", authController.notifyResidents);

const PORT = process.env.PORT || 3000;
if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`Express application running on port ${PORT}`);
    console.log("Ready to dispatch emails via EntireZe Centralized Email Service");
  });
}

module.exports = app;
