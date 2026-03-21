// models/Session.js
import mongoose from 'mongoose';
import crypto   from 'crypto';

const sessionSchema = new mongoose.Schema({
  assignment: { type: mongoose.Schema.Types.ObjectId, ref: 'Assignment', required: true },
  lecturer:   { type: mongoose.Schema.Types.ObjectId, ref: 'User',       required: true },
  unit:       { type: mongoose.Schema.Types.ObjectId, ref: 'Unit',       required: true },

  // The token embedded in the QR code — a short-lived random string
  qrToken:   { type: String, required: true, unique: true },
  qrPayload: { type: String, required: true },  // full JSON string encoded in QR

  expiresAt: { type: Date,    required: true },  // now + 15 min
  isActive:  { type: Boolean, default: true  },  // lecturer can end early

  location:  { type: String, trim: true },       // room label e.g. "LH-3"

  // ── GEOFENCE ───────────────────────────────────────────────────────────────
  // Set by the lecturer when starting the session (optional).
  // If latitude/longitude are null the geofence check is skipped — every
  // student location is accepted (backward-compatible with older clients).
  //
  // The centre point should be the lecturer's GPS position at session start,
  // or a known classroom coordinate. radiusMeters defaults to 50 m which
  // comfortably covers most lecture halls without leaking into adjacent rooms.
  geofence: {
    latitude:     { type: Number, default: null },
    longitude:    { type: Number, default: null },
    radiusMeters: { type: Number, default: 50   },  // metres
  },

}, { timestamps: true });

// ── Indexes ───────────────────────────────────────────────────────────────────

// Auto-delete documents 1 hour after they expire (keeps audit logs briefly)
sessionSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 3600 });

// ── Statics ───────────────────────────────────────────────────────────────────

// Generate a cryptographically secure QR token
sessionSchema.statics.generateToken = () =>
  crypto.randomBytes(32).toString('hex');

// Haversine distance between two GPS coordinates — returns metres.
// Used by sessionController to check if a student/lecturer is inside
// the classroom geofence before issuing or validating relay tokens.
//
// Usage:
//   const dist = Session.distanceMeters(lat1, lon1, lat2, lon2);
//   if (dist <= session.geofence.radiusMeters) { /* inside */ }
sessionSchema.statics.distanceMeters = (lat1, lon1, lat2, lon2) => {
  const R  = 6_371_000; // Earth radius in metres
  const φ1 = lat1 * Math.PI / 180;
  const φ2 = lat2 * Math.PI / 180;
  const Δφ = (lat2 - lat1) * Math.PI / 180;
  const Δλ = (lon2 - lon1) * Math.PI / 180;
  const a  = Math.sin(Δφ / 2) ** 2 +
             Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
};

export default mongoose.model('Session', sessionSchema);