// models/Unit.js
import mongoose from 'mongoose';

const unitSchema = new mongoose.Schema({
  name:   { type: String, required: true, trim: true },       // e.g. "Mathematics 201"
  code:   { type: String, required: true, unique: true, trim: true, uppercase: true }, // e.g. "MATH201"
  department: { type: String, required: true, trim: true },
  description:{ type: String, trim: true },
  year:   { type: Number, required: true, min: 1, max: 6 },   // year of study
  semester: { type: Number, required: true, min: 1, max: 3 },
  isActive: { type: Boolean, default: true },
}, { timestamps: true });

export default mongoose.model('Unit', unitSchema);