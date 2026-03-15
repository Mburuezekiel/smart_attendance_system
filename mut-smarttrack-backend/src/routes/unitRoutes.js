// routes/unitRoutes.js
import express from 'express';
import { getUnits, createUnit, updateUnit, deleteUnit } from '../controllers/unitController.js';
import { protect } from '../middleware/authMiddleware.js';

const router = express.Router();

router.get('/',       protect, getUnits);
router.post('/',      protect, createUnit);
router.patch('/:id',  protect, updateUnit);
router.delete('/:id', protect, deleteUnit);

export default router;