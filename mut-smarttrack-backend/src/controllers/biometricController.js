// src/controllers/biometricController.js
import User from '../models/User.js';

// POST /api/biometric/fingerprint
export const registerFingerprint = async (req, res, next) => {
  try {
    const user = await User.findByIdAndUpdate(
      req.user.id,
      { 'biometric.fingerprintRegistered': true },
      { new: true }
    );

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    return res.status(200).json({
      message: 'Fingerprint registered',
      biometric: user.biometric,
    });
  } catch (err) {
    next(err instanceof Error ? err : new Error(String(err)));
  }
};

// POST /api/biometric/faceid
export const registerFaceId = async (req, res, next) => {
  try {
    const user = await User.findByIdAndUpdate(
      req.user.id,
      { 'biometric.faceIdRegistered': true },
      { new: true }
    );

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    return res.status(200).json({
      message: 'Face ID registered',
      biometric: user.biometric,
    });
  } catch (err) {
    next(err instanceof Error ? err : new Error(String(err)));
  }
};