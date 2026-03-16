// routes/sessionRoutes.js
import express from 'express';
import {
  createSession, endSession,
  getSessionStats, verifyAndMarkAttendance,
  getMyAttendance,
} from '../controllers/sessionController.js';
import { protect } from '../middleware/authMiddleware.js';

const router = express.Router();

// ── Specific named routes BEFORE /:id ────────────────────────────────────────
router.get('/my-attendance',   protect, getMyAttendance);      // student history
router.post('/verify',         protect, verifyAndMarkAttendance); // student marks attendance

router.post('/',               protect, createSession);         // lecturer starts session
router.get('/:id/stats',       protect, getSessionStats);       // live scan counter
router.delete('/:id',          protect, endSession);            // lecturer ends session

export default router;