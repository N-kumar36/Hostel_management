import express from 'express';
import dotenv from 'dotenv';
import cors from 'cors';
import proxyRoutes from "./src/routes/proxyRoutes.js";
// import { checkServers } from "./src/services/healthCheck.js";

dotenv.config();
const app = express();

app.use(cors());
app.use(express.json());

// Main Router
app.use("/", proxyRoutes);

// Start the periodic health check runner (Every 10 seconds)
// setInterval(async () => {
//     console.log("🔍 Running periodic health checks...");
//     await checkServers();
// }, 10000);

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
});