// models/Attendance.js
import mongoose from 'mongoose';

const attendanceSchema = new mongoose.Schema({
  session:    { type: mongoose.Schema.Types.ObjectId, ref: 'Session',    required: true },
  assignment: { type: mongoose.Schema.Types.ObjectId, ref: 'Assignment', required: true },
  unit:       { type: mongoose.Schema.Types.ObjectId, ref: 'Unit',       required: true },
  student:    { type: mongoose.Schema.Types.ObjectId, ref: 'User',       required: true },
  lecturer:   { type: mongoose.Schema.Types.ObjectId, ref: 'User',       required: true },

  // Verification chain — all three must be true for attendance to count
  qrVerified:          { type: Boolean, default: false },
  biometricVerified:   { type: Boolean, default: false },
  faceVerified:        { type: Boolean, default: false },

  // Digital signature: HMAC-SHA256(studentId + sessionId + timestamp, serverSecret)
  // Generated server-side after all three checks pass — proves record was not forged
  digitalSignature:    { type: String },
  signedAt:            { type: Date },

  // Face verification metadata
  faceConfidence:      { type: Number },   // 0–1 score from ML kit
  faceImageRef:        { type: String },   // optional: path/key to stored face snapshot

  markedAt:            { type: Date, default: Date.now },
  status: {
    type: String,
    enum: ['present', 'late', 'failed'],
    default: 'present',
  },
}, { timestamps: true });

// One attendance record per student per session
attendanceSchema.index({ session: 1, student: 1 }, { unique: true });

export default mongoose.model('Attendance', attendanceSchema);