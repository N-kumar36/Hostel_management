# EntireZe Nodemailer Service — Centralized Email Delivery API

Centralized serverless email delivery API service powered by **Node.js**, **Firebase Cloud Functions v2**, **Firebase Hosting**, and **Nodemailer SMTP transport**.

Deployed to project **hostelApp** (`hostelapp-88866`) in region **asia-south1**.

---

## Live Endpoints

| Endpoint | Method | Authentication | Description |
| :--- | :--- | :--- | :--- |
| `https://hostelapp-88866.web.app/api/v1/health` | `GET` | Public | Shallow health and uptime check |
| `https://hostelapp-88866.web.app/api/v1/status` | `GET` | Public | Service version & runtime info |
| `https://hostelapp-88866.web.app/api/v1/send` | `POST` | `Bearer <MAIL_API_KEY>` | Primary email delivery endpoint |

---

## Quick Start (cURL Examples)

### 1. Check Service Health
```bash
curl -X GET https://hostelapp-88866.web.app/api/v1/health
```
**Response:**
```json
{
  "success": true,
  "message": "EntireZe Nodemailer Service is healthy",
  "data": {
    "status": "UP",
    "region": "asia-south1",
    "timestamp": "2026-11-23T20:18:35.360Z"
  }
}
```

### 2. Send an Email
```bash
curl -X POST https://hostelapp-88866.web.app/api/v1/send \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer entireze_secret_key_prod_88866" \
  -d '{
    "to": "customer@gmail.com",
    "subject": "Your OTP Verification",
    "htmlContent": "<h1>Your OTP is 123456</h1>",
    "senderName": "EntireZe Accounts"
  }'
```

### 3. Send Multiple Recipients
```bash
curl -X POST https://hostelapp-88866.web.app/api/v1/send \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer entireze_secret_key_prod_88866" \
  -d '{
    "to": ["user1@gmail.com", "user2@gmail.com"],
    "subject": "Community Notification",
    "htmlContent": "<h1>Hello Everyone!</h1>"
  }'
```

---

## Calling from Your Express / Node.js Applications

Use the reusable client located at `client/emailClient.js`:

```javascript
// In your Express backend (e.g. Hostel Management System API)
const { sendOtpEmail, sendVerificationEmail, sendEmail } = require("./client/emailClient");

// Set environment variables in your Express backend:
// MAIL_API_URL=https://hostelapp-88866.web.app/api/v1/send
// MAIL_API_KEY=entireze_secret_key_prod_88866

// 1. Send OTP (Calling backend generates the OTP)
const otp = crypto.randomInt(100000, 999999).toString();
await sendOtpEmail("resident@hostel.com", otp, "HostelApp");

// 2. Send Account Verification
await sendVerificationEmail("student@hostel.com", "https://hostelapp.com/verify?token=xyz", "HostelApp");

// 3. Custom HTML Email
await sendEmail(
  ["resident1@gmail.com", "resident2@gmail.com"],
  "Maintenance Notice",
  "<h2>Water supply will be paused from 2 PM to 4 PM</h2>",
  { senderName: "Hostel Warden Office" }
);
```

---

## Updating SMTP Credentials

When you are ready to bind your personal or organizational Gmail / SMTP credentials:
1. Open `functions/.env.hostelapp-88866`
2. Update:
   ```env
   SMTP_HOST=smtp.gmail.com
   SMTP_PORT=465
   SMTP_SECURE=true
   SMTP_USER=your-email@gmail.com
   SMTP_PASS=your-16-char-google-app-password
   DEFAULT_FROM_NAME="EntireZe Mail Service"
   DEFAULT_FROM_EMAIL=your-email@gmail.com
   MAIL_API_KEY=your-custom-secret-key
   ```
3. Deploy updates with:
   ```bash
   firebase deploy --only functions
   ```
