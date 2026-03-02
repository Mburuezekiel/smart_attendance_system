import { Router } from 'express';
import { protect } from '../middleware/authMiddleware.js';
import { registerFingerprint, registerFaceId } from '../controllers/biometricController.js';

const router = Router();

router.post('/fingerprint', protect, registerFingerprint);
router.post('/faceid', protect, registerFaceId);

export default router;