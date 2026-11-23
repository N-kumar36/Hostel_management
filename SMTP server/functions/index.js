/**
 * EntireZe Nodemailer Service
 * Firebase Cloud Functions v2 Entry Point
 * Region: asia-south1
 */

const { onRequest } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2");
const app = require("./src/index");

// Configure Cloud Functions v2 global options
setGlobalOptions({
  region: "asia-south1",
  maxInstances: 10,
  concurrency: 80,
  timeoutSeconds: 60,
  memory: "256MiB"
});

// Export Express application as Cloud Function HTTP handler
exports.emailApi = onRequest(
  {
    cors: true,
    invoker: "public"
  },
  app
);
