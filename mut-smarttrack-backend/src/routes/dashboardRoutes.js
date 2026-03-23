// routes/dashboardRoutes.js
import express from 'express';
import {
  getStudentDashboard,
  getLecturerDashboard,
} from '../controllers/dashboardController.js';
import { protect } from '../middleware/authMiddleware.js';

const router = express.Router();

router.get('/student',  protect, getStudentDashboard);
router.get('/lecturer', protect, getLecturerDashboard);

export default router;