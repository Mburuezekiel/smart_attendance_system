// models/Timetable.js
import mongoose from 'mongoose';

const timetableSchema = new mongoose.Schema({
  assignment: {
    type:     mongoose.Schema.Types.ObjectId,
    ref:      'Assignment',
    required: true,
  },
  unit: {
    type:     mongoose.Schema.Types.ObjectId,
    ref:      'Unit',
    required: true,
  },
  lecturer: {
    type:     mongoose.Schema.Types.ObjectId,
    ref:      'User',
    required: true,
  },

  // Day of the week the class runs
  day: {
    type:     String,
    enum:     ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
    required: true,
  },

  startTime: { type: String, required: true },  // e.g. "08:00"
  endTime:   { type: String, required: true },  // e.g. "10:00"
  room:      { type: String, default: '' },     // e.g. "LH-3"

  // Optional notes visible to students
  notes:     { type: String, default: '' },

  isActive:  { type: Boolean, default: true },

}, { timestamps: true });

// A lecturer cannot schedule the same unit twice in the same day/time slot
timetableSchema.index({ assignment: 1, day: 1, startTime: 1 }, { unique: true });

export default mongoose.model('Timetable', timetableSchema);