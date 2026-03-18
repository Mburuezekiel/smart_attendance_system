// models/Assignment.js
import mongoose from 'mongoose';

const assignmentSchema = new mongoose.Schema({
  unit:     { type: mongoose.Schema.Types.ObjectId, ref: 'Unit',  required: true },
  lecturer: { type: mongoose.Schema.Types.ObjectId, ref: 'User',  required: true },
  students: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  room:     { type: String, default: '' },
  schedule: { type: Array,  default: [] },
  // academicYear and semester are optional — not enforced at DB level
  academicYear: { type: String, default: '' },
  semester:     { type: Number, default: 1 },
  isActive:     { type: Boolean, default: true },
}, { timestamps: true });

// Simple index — just prevent exact duplicate (same unit + lecturer only)
// Remove the academicYear/semester compound index that was blocking saves
assignmentSchema.index({ unit: 1, lecturer: 1 }, { unique: true });

export default mongoose.model('Assignment', assignmentSchema);