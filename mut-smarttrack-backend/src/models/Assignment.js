// models/Assignment.js
import mongoose from 'mongoose';

// One document per lecturer+unit pair.
// The students array holds all students enrolled in that unit under that lecturer.
const assignmentSchema = new mongoose.Schema({
  unit:     { type: mongoose.Schema.Types.ObjectId, ref: 'Unit',    required: true },
  lecturer: { type: mongoose.Schema.Types.ObjectId, ref: 'User',    required: true },
  students: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  room:     { type: String, trim: true },                          // e.g. "LH-3"
  schedule: [{                                                     // weekly schedule
    day:       { type: String, enum: ['Mon','Tue','Wed','Thu','Fri','Sat'] },
    startTime: { type: String },   // "08:00"
    endTime:   { type: String },   // "10:00"
  }],
  isActive: { type: Boolean, default: true },
}, { timestamps: true });

// One lecturer can only be assigned a unit once
assignmentSchema.index({ unit: 1, lecturer: 1 }, { unique: true });

export default mongoose.model('Assignment', assignmentSchema);