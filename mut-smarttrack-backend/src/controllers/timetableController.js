// controllers/timetableController.js
import Timetable  from '../models/Timetable.js';
import Assignment from '../models/Assignment.js';

const getUserId = (user) => user._id ?? user.id;

// ── GET /api/timetable  ────────────────────────────────────────────────────────
// Student  → returns all timetable entries for their enrolled assignments
// Lecturer → returns all timetable entries they created
// Admin    → returns everything
export const getTimetable = async (req, res) => {
  try {
    const { role } = req.user;
    const userId   = getUserId(req.user);
    let filter     = { isActive: true };

    if (role === 'lecturer') {
      filter.lecturer = userId;
    } else if (role === 'student') {
      // Find every assignment this student is enrolled in
      const assignments = await Assignment.find({ students: userId }).select('_id');
      filter.assignment = { $in: assignments.map(a => a._id) };
    }

    const entries = await Timetable.find(filter)
      .populate('unit',     'name code department')
      .populate('lecturer', 'fullName email')
      .populate({
        path:     'assignment',
        select:   'academicYear semester',
        populate: { path: 'students', select: 'fullName registrationNumber' },
      })
      .sort({ day: 1, startTime: 1 });

    res.json({ timetable: entries });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// ── POST /api/timetable  (Lecturer only) ──────────────────────────────────────
// Lecturer creates a timetable slot for one of their assignments
export const createTimetableEntry = async (req, res) => {
  try {
    if (req.user.role !== 'lecturer') {
      return res.status(403).json({ message: 'Lecturer access required.' });
    }

    const lecturerId = getUserId(req.user);
    const { assignmentId, day, startTime, endTime, room, notes } = req.body;

    if (!assignmentId || !day || !startTime || !endTime) {
      return res.status(400).json({
        message: 'assignmentId, day, startTime and endTime are required.',
      });
    }

    // Verify the lecturer owns this assignment
    const assignment = await Assignment.findOne({
      _id: assignmentId, lecturer: lecturerId,
    }).populate('unit', 'name code');

    if (!assignment) {
      return res.status(404).json({
        message: 'Assignment not found or not assigned to you.',
      });
    }

    const entry = await Timetable.create({
      assignment: assignmentId,
      unit:       assignment.unit._id,
      lecturer:   lecturerId,
      day,
      startTime,
      endTime,
      room:  room  ?? '',
      notes: notes ?? '',
    });

    const populated = await entry.populate([
      { path: 'unit',     select: 'name code department' },
      { path: 'lecturer', select: 'fullName email' },
    ]);

    res.status(201).json({ message: 'Timetable entry created.', entry: populated });
  } catch (err) {
    if (err.code === 11000) {
      return res.status(409).json({
        message: 'A timetable entry already exists for this unit on that day and time.',
      });
    }
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// ── PATCH /api/timetable/:id  (Lecturer only) ─────────────────────────────────
export const updateTimetableEntry = async (req, res) => {
  try {
    if (req.user.role !== 'lecturer') {
      return res.status(403).json({ message: 'Lecturer access required.' });
    }

    const lecturerId = getUserId(req.user);
    const allowed    = ['day', 'startTime', 'endTime', 'room', 'notes', 'isActive'];
    const updates    = Object.fromEntries(
      Object.entries(req.body).filter(([k]) => allowed.includes(k))
    );

    const entry = await Timetable.findOneAndUpdate(
      { _id: req.params.id, lecturer: lecturerId },
      { $set: updates },
      { new: true }
    ).populate('unit', 'name code').populate('lecturer', 'fullName');

    if (!entry) return res.status(404).json({ message: 'Timetable entry not found.' });
    res.json({ message: 'Updated.', entry });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// ── DELETE /api/timetable/:id  (Lecturer only) ────────────────────────────────
export const deleteTimetableEntry = async (req, res) => {
  try {
    if (req.user.role !== 'lecturer') {
      return res.status(403).json({ message: 'Lecturer access required.' });
    }
    const lecturerId = getUserId(req.user);
    const entry = await Timetable.findOneAndDelete({
      _id: req.params.id, lecturer: lecturerId,
    });
    if (!entry) return res.status(404).json({ message: 'Timetable entry not found.' });
    res.json({ message: 'Deleted.' });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};