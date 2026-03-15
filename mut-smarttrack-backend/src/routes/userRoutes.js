// routes/userRoutes.js
import express from 'express';
import { getUsers, getUserById, updateUser, deleteUser } from '../controllers/userController.js';
import { protect } from '../middleware/authMiddleware.js'; // your JWT middleware

const router = express.Router();

router.get('/',      protect, getUsers);
router.get('/:id',   protect, getUserById);
router.patch('/:id', protect, updateUser);
router.delete('/:id',protect, deleteUser);

export default router;