// routes/timetableRoutes.js
import express from 'express';
import {
  getTimetable,
  createTimetableEntry,
  updateTimetableEntry,
  deleteTimetableEntry,
} from '../controllers/timetableController.js';
import { importUploadMiddleware, importTimetablePreview, confirmTimetableImport }
  from './controllers/timetableImportController.js';
import { protect } from '../middleware/authMiddleware.js';


const router = express.Router();

router.get('/',      protect, getTimetable);           // student / lecturer / admin
router.post('/',     protect, createTimetableEntry);   // lecturer creates slot
router.patch('/:id', protect, updateTimetableEntry);   // lecturer edits slot
router.delete('/:id',protect, deleteTimetableEntry);   // lecturer deletes slot


router.post('/timetable/import',         protect, importUploadMiddleware, importTimetablePreview);
router.post('/timetable/import/confirm', protect, confirmTimetableImport);

export default router;