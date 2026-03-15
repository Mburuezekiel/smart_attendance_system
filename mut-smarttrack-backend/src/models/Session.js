// models/Session.js
import mongoose from 'mongoose';
import crypto from 'crypto';

const sessionSchema = new mongoose.Schema({
  assignment: { type: mongoose.Schema.Types.ObjectId, ref: 'Assignment', required: true },
  lecturer:   { type: mongoose.Schema.Types.ObjectId, ref: 'User',       required: true },
  unit:       { type: mongoose.Schema.Types.ObjectId, ref: 'Unit',       required: true },

  // The token embedded in the QR code — a short-lived random string
  qrToken:    { type: String, required: true, unique: true },
  qrPayload:  { type: String, required: true },  // full JSON string encoded in QR

  expiresAt:  { type: Date,   required: true },   // now + 15 min
  isActive:   { type: Boolean, default: true },   // lecturer can end early

  location:   { type: String, trim: true },       // room, e.g. "LH-3"
}, { timestamps: true });

// Auto-expire index — MongoDB will delete docs 1 hour after expiry (for logs keep this high)
sessionSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 3600 });

// Generate a cryptographically secure token
sessionSchema.statics.generateToken = () => crypto.randomBytes(32).toString('hex');

export default mongoose.model('Session', sessionSchema);