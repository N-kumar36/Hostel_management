import router from "express";
import { protect } from "../middleware/authMiddleware.js";
import { isApproved } from "../middleware/statusMiddleware.js";
import { createShoppingList, getShoppingList, updateShoppingList, deleteShoppingList } from "../controllers/shopping.controller.js";



const shoppingRouter = router.Router();

// Create a shopping list
shoppingRouter.post("/", protect, isApproved, createShoppingList);

// Get a shopping list
shoppingRouter.get("/", protect, isApproved, getShoppingList);

// Update a shopping list
shoppingRouter.put("/:id", protect, isApproved, updateShoppingList);

// Delete a shopping list
shoppingRouter.delete("/:id", protect, isApproved, deleteShoppingList);

export default shoppingRouter;