// routes/userRoutes.js
import express from 'express';
import {
  getDashboardStats,
  getLecturerStats,
  getUsers,
  getUserById,
  updateUser,
  deleteUser,
} from '../controllers/userController.js';
import { protect } from '../middleware/authMiddleware.js';

const router = express.Router();

// ── IMPORTANT: specific named routes MUST come before /:id ──────────────────
// If /:id is registered first, Express treats 'dashboard-stats' and
// 'lecturer-stats' as id parameters and never reaches these handlers.

router.get('/dashboard-stats', protect, getDashboardStats);  // Admin dashboard KPIs
router.get('/lecturer-stats',  protect, getLecturerStats);   // Lecturer dashboard KPIs

// ── General CRUD (wildcard /:id goes last) ───────────────────────────────────
router.get('/',       protect, getUsers);
router.get('/:id',    protect, getUserById);
router.patch('/:id',  protect, updateUser);
router.delete('/:id', protect, deleteUser);

export default router;