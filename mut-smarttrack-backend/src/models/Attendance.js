// models/Attendance.js
import mongoose from 'mongoose';

const attendanceSchema = new mongoose.Schema({
  session:    { type: mongoose.Schema.Types.ObjectId, ref: 'Session',    required: true },
  assignment: { type: mongoose.Schema.Types.ObjectId, ref: 'Assignment', required: true },
  unit:       { type: mongoose.Schema.Types.ObjectId, ref: 'Unit',       required: true },
  student:    { type: mongoose.Schema.Types.ObjectId, ref: 'User',       required: true },
  lecturer:   { type: mongoose.Schema.Types.ObjectId, ref: 'User',       required: true },

  // Verification chain — all three must be true for attendance to count
  qrVerified:        { type: Boolean, default: false },
  biometricVerified: { type: Boolean, default: false },
  faceVerified:      { type: Boolean, default: false },

  // Digital signature: HMAC-SHA256(studentId + sessionId + timestamp, serverSecret)
  // Generated server-side after all three checks pass — proves record was not forged
  digitalSignature:  { type: String },
  signedAt:          { type: Date },

  // Face verification metadata
  faceConfidence:    { type: Number },   // 0–1 score from ML kit
  faceImageRef:      { type: String },   // optional: path/key to stored face snapshot

  markedAt: { type: Date, default: Date.now },
  status: {
    type:    String,
    enum:    ['present', 'late', 'failed'],
    default: 'present',
  },

  // ── CANDLELIGHT relay chain fields ─────────────────────────────────────────
  //
  // How it works:
  //   1. When a student's attendance is verified the backend generates a
  //      single-use relayToken (HMAC tied to attendanceId+studentId+sessionId).
  //   2. That token is encoded into a relay QR the student shows to classmates.
  //   3. When a classmate scans it the backend finds this record by relayToken,
  //      confirms relayUsed=false, then IMMEDIATELY sets relayToken=null and
  //      relayUsed=true before processing — making screenshots worthless.
  //   4. When the lecturer ends the session ALL relayTokens in the session are
  //      wiped to null at once — every student QR dies instantly.

  // The single-use token embedded in this student's relay QR.
  // null  → token has been burned (used or session ended).
  relayToken: {
    type:    String,
    default: null,
  },

  // True once this student's relay token has been consumed by a classmate.
  relayUsed: {
    type:    Boolean,
    default: false,
  },

  // Audit trail: how many hops from the original lecturer QR.
  // 1 = student scanned the lecturer's QR directly.
  // 2 = student scanned a classmate's relay QR (1 hop away from lecturer).
  // 3+ = deeper relay chain.
  chainDepth: {
    type:    Number,
    default: 1,
  },

}, { timestamps: true });

// ── Indexes ───────────────────────────────────────────────────────────────────

// One attendance record per student per session (prevents duplicates)
attendanceSchema.index({ session: 1, student: 1 }, { unique: true });

// Fast relay token lookup — used on every student scan that carries a relay QR
attendanceSchema.index({ session: 1, relayToken: 1 });

export default mongoose.model('Attendance', attendanceSchema);