// routes/assignmentRoutes.js
import express from 'express';
import {
  getAssignments, getAssignmentById,
  createAssignment, updateAssignment,
  updateAssignmentStudents, deleteAssignment,
} from '../controllers/assignmentController.js';
import { protect } from '../middleware/authMiddleware.js';

const router = express.Router();

// Named routes BEFORE /:id to avoid conflicts
router.get('/',               protect, getAssignments);
router.post('/',              protect, createAssignment);
router.get('/:id',            protect, getAssignmentById);
router.patch('/:id',          protect, updateAssignment);
router.patch('/:id/students', protect, updateAssignmentStudents);
router.delete('/:id',         protect, deleteAssignment);

export default router;