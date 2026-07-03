import express from "express";
import dotenv from "dotenv";
import cors from "cors";
import connectDB from "./config/db.js";

// routes
import authRoutes from "./routes/auth.routes.js";
import financeRoutes from "./routes/finance.routes.js";
import managerRoutes from "./routes/manager.routes.js";
import meals from "./routes/meals.routes.js";
import hostelRoutes from "./routes/hostel.routes.js";
import voteRoute from "./routes/vote.routes.js";
import ComplainRoute from "./routes/complain.route.js";
import FineRoute from "./routes/fine.routes.js";
import guestMealRoutes from "./routes/guestMeal.routes.js";
import userRouter from "./routes/user.route.js";
import upiRoute from "./routes/upi.route.js"
import MealPlanRouter from "./routes/mealPlan.route.js"; 
import shoppingRouter from "./routes/shopping.router.js";
import notificationRoutes from "./routes/notification.routes.js";


// app.get("/api/test", (req, res) => {
//   res.json({message: "hi  Hello word"})
// })

dotenv.config();
const app = express();

// Connect to Database
connectDB();

// Middleware
app.use(cors());
app.use(express.json());


// API Routes
app.use("/api/user", userRouter);
app.use("/api/auth", authRoutes);
app.use("/api/finance", financeRoutes);
app.use("/api/managers", managerRoutes);
app.use("/api/meals", meals);
app.use("/api/hostels", hostelRoutes);
app.use("/api/vote", voteRoute);
app.use("/api/complains", ComplainRoute);
app.use("/api/fines", FineRoute);
app.use("/api/guest-meals", guestMealRoutes);
app.use("/api/upi", upiRoute);
app.use("/api/meal-plan", MealPlanRouter);
app.use("/api/shopping-list", shoppingRouter);
app.use("/api/notifications", notificationRoutes);



// 404 Handler
app.use((req, res) => {
  res.status(404).json({ success: false, message: "Route not found" });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ success: false, message: "Internal Server Error" });
});

const PORT = process.env.PORT || 5000;

app.listen(PORT, () =>
  console.log(` Server running on http://localhost:${PORT}`)
);