// routes/timetableRoutes.js
import express from 'express';
import {
  getTimetable,
  createTimetableEntry,
  updateTimetableEntry,
  deleteTimetableEntry,
} from '../controllers/timetableController.js';
import { protect } from '../middleware/authMiddleware.js';

const router = express.Router();

router.get('/',      protect, getTimetable);           // student / lecturer / admin
router.post('/',     protect, createTimetableEntry);   // lecturer creates slot
router.patch('/:id', protect, updateTimetableEntry);   // lecturer edits slot
router.delete('/:id',protect, deleteTimetableEntry);   // lecturer deletes slot

export default router;