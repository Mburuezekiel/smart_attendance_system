// routes/timetableRoutes.js

import express from 'express';
import { protect } from '../middleware/authMiddleware.js';   // adjust path if needed

import {
  getTimetable,
  createTimetableEntry,
  updateTimetableEntry,
  deleteTimetableEntry,
} from '../controllers/timetableController.js';

import {
  importUploadMiddleware,
  importTimetablePreview,
  confirmTimetableImport,
} from '../controllers/timetableImportController.js';

const router = express.Router();

// ── Standard CRUD ─────────────────────────────────────────────────────────────
router.get   ('/',    protect, getTimetable);
router.post  ('/',    protect, createTimetableEntry);
router.patch ('/:id', protect, updateTimetableEntry);
router.delete('/:id', protect, deleteTimetableEntry);

// ── Import routes (MUST be defined BEFORE the /:id wildcard above,
//    but Express matches by order so placing them after is fine as long
//    as the paths are fully explicit — "import" and "import/confirm"
//    will never collide with a Mongo ObjectId /:id) ─────────────────────────
router.post('/import',         protect, importUploadMiddleware, importTimetablePreview);
router.post('/import/confirm', protect, confirmTimetableImport);

export default router;