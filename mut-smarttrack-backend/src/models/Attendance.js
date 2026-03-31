// models/Attendance.js
import mongoose from 'mongoose';

const attendanceSchema = new mongoose.Schema({
  session:    { type: mongoose.Schema.Types.ObjectId, ref: 'Session',    required: true },
  assignment: { type: mongoose.Schema.Types.ObjectId, ref: 'Assignment', required: true },
  unit:       { type: mongoose.Schema.Types.ObjectId, ref: 'Unit',       required: true },
  student:    { type: mongoose.Schema.Types.ObjectId, ref: 'User',       required: true },
  lecturer:   { type: mongoose.Schema.Types.ObjectId, ref: 'User',       required: true },

  // Verification chain
  qrVerified:        { type: Boolean, default: false },
  biometricVerified: { type: Boolean, default: false },
  faceVerified:      { type: Boolean, default: false },

  // Digital signature
  digitalSignature:  { type: String },
  signedAt:          { type: Date },

  // Face verification metadata
  faceConfidence:    { type: Number },
  faceImageRef:      { type: String },

  // Location at time of sign-in
  location: {
    latitude:  { type: Number },
    longitude: { type: Number },
  },
   autoMarked: { type: Boolean, default: false },

  markedAt: { type: Date, default: Date.now },
  status: {
    type:    String,
    enum:    ['present', 'late', 'failed'],
    default: 'present',
  },

  // ── CANDLELIGHT + GEOFENCE relay fields ────────────────────────────────────
  // A verified student can generate MULTIPLE relay tokens but only while
  // physically inside the classroom geofence. Each token is still single-use.
  //
  // relayTokens: array of { token, used, issuedAt }
  //   - New tokens are pushed here each time the student requests one
  //     (via POST /api/sessions/relay-token) while inside the geofence.
  //   - Each token is burned (used: true) the moment a classmate scans it.
  //   - All tokens are wiped when the lecturer ends the session.
  relayTokens: [
    {
      token:    { type: String, required: true },
      used:     { type: Boolean, default: false },
      issuedAt: { type: Date,    default: Date.now },
    }
  ],

  // How many hops from the original lecturer QR (audit trail)
  // 1 = scanned lecturer QR directly
  // 2+ = scanned a classmate's relay QR
  chainDepth: {
    type:    Number,
    default: 1,
  },

}, { timestamps: true });

// ── Indexes ───────────────────────────────────────────────────────────────────
// One record per student per session
attendanceSchema.index({ session: 1, student: 1 }, { unique: true });

// Fast lookup when validating a relay token on scan
attendanceSchema.index({ session: 1, 'relayTokens.token': 1 });

export default mongoose.model('Attendance', attendanceSchema);