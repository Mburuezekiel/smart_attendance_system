// routes/attendanceRoutes.js
import express from 'express';
import {
  getMyHistory,
  getLecturerReports,
  exportAttendance,
} from '../controllers/attendanceController.js';
import { protect } from '../middleware/authMiddleware.js';

const router = express.Router();

router.get('/my-history',       protect, getMyHistory);        // student records + stats
router.get('/lecturer-reports', protect, getLecturerReports);  // lecturer per-unit stats
router.get('/export',           protect, exportAttendance);    // CSV / JSON export

export default router;