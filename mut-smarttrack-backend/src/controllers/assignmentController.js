// controllers/assignmentController.js
import mongoose from 'mongoose';
import Assignment from '../models/Assignment.js';
import Unit       from '../models/Unit.js';
import User       from '../models/User.js';

// ── GET /api/assignments ───────────────────────────────────────────────────────
export const getAssignments = async (req, res) => {
  try {
    const { role, _id } = req.user;
    let filter = {};

    if (role === 'lecturer') {
      // Cast to ObjectId — string comparison against ObjectId field returns 0 results
      filter.lecturer = new mongoose.Types.ObjectId(_id);
    } else if (role === 'student') {
      filter.students = new mongoose.Types.ObjectId(_id);
    }
    // admin: no filter — gets all

    const assignments = await Assignment.find(filter)
      .populate('unit',     'name code department year semester')
      .populate('lecturer', 'fullName email registrationNumber')
      .populate('students', 'fullName email registrationNumber')
      .sort({ createdAt: -1 });

    res.json({ assignments });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// ── GET /api/assignments/:id ───────────────────────────────────────────────────
export const getAssignmentById = async (req, res) => {
  try {
    const assignment = await Assignment.findById(req.params.id)
      .populate('unit',     'name code department year semester')
      .populate('lecturer', 'fullName email registrationNumber')
      .populate('students', 'fullName email registrationNumber');

    if (!assignment) return res.status(404).json({ message: 'Assignment not found.' });

    if (req.user.role === 'student' &&
        !assignment.students.some(s => s._id.toString() === req.user._id.toString())) {
      return res.status(403).json({ message: 'Access denied.' });
    }
    if (req.user.role === 'lecturer' &&
        assignment.lecturer._id.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: 'Access denied.' });
    }

    res.json({ assignment });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// ── POST /api/assignments  (Admin only) ────────────────────────────────────────
export const createAssignment = async (req, res) => {
  try {
    if (req.user.role !== 'admin') return res.status(403).json({ message: 'Admin access required.' });

    const {
      unitId, lecturerId,
      studentIds = [], room = '', schedule = [],
      academicYear = '', semester = 1,
    } = req.body;

    if (!unitId || !lecturerId) {
      return res.status(400).json({ message: 'unitId and lecturerId are required.' });
    }

    const [unit, lecturer] = await Promise.all([
      Unit.findById(unitId),
      User.findOne({ _id: lecturerId, role: 'lecturer' }),
    ]);
    if (!unit)     return res.status(404).json({ message: 'Unit not found.' });
    if (!lecturer) return res.status(404).json({ message: 'Lecturer not found.' });

    if (studentIds.length > 0) {
      const valid = await User.countDocuments({ _id: { $in: studentIds }, role: 'student' });
      if (valid !== studentIds.length) {
        return res.status(400).json({ message: 'One or more student IDs are invalid.' });
      }
    }

    const assignment = await Assignment.create({
      unit: unitId, lecturer: lecturerId,
      students: studentIds, room, schedule, academicYear, semester,
    });

    const populated = await assignment.populate([
      { path: 'unit',     select: 'name code department' },
      { path: 'lecturer', select: 'fullName email' },
      { path: 'students', select: 'fullName email registrationNumber' },
    ]);

    res.status(201).json({ message: 'Assignment created.', assignment: populated });
  } catch (err) {
    if (err.code === 11000) {
      return res.status(409).json({ message: 'This lecturer is already assigned to this unit.' });
    }
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// ── PATCH /api/assignments/:id/students  (Admin only) ─────────────────────────
export const updateAssignmentStudents = async (req, res) => {
  try {
    if (req.user.role !== 'admin') return res.status(403).json({ message: 'Admin access required.' });

    const { add = [], remove = [] } = req.body;
    const assignment = await Assignment.findById(req.params.id);
    if (!assignment) return res.status(404).json({ message: 'Assignment not found.' });

    if (add.length > 0) {
      const valid = await User.countDocuments({ _id: { $in: add }, role: 'student' });
      if (valid !== add.length) return res.status(400).json({ message: 'Invalid student IDs in add list.' });
    }

    const update = {};
    if (add.length    > 0) update.$addToSet = { students: { $each: add } };
    if (remove.length > 0) update.$pull     = { students: { $in: remove } };

    const updated = await Assignment.findByIdAndUpdate(req.params.id, update, { new: true })
      .populate('unit',     'name code')
      .populate('lecturer', 'fullName email')
      .populate('students', 'fullName email registrationNumber');

    res.json({ message: 'Students updated.', assignment: updated });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// ── PATCH /api/assignments/:id  (Admin only) ───────────────────────────────────
export const updateAssignment = async (req, res) => {
  try {
    if (req.user.role !== 'admin') return res.status(403).json({ message: 'Admin access required.' });

    const allowed = ['room', 'schedule', 'isActive', 'academicYear', 'semester'];
    const updates = Object.fromEntries(Object.entries(req.body).filter(([k]) => allowed.includes(k)));

    if (req.body.lecturerId) {
      const lec = await User.findOne({ _id: req.body.lecturerId, role: 'lecturer' });
      if (!lec) return res.status(404).json({ message: 'Lecturer not found.' });
      updates.lecturer = req.body.lecturerId;
    }

    const assignment = await Assignment.findByIdAndUpdate(
      req.params.id, { $set: updates }, { new: true }
    ).populate('unit', 'name code').populate('lecturer', 'fullName email');

    if (!assignment) return res.status(404).json({ message: 'Assignment not found.' });
    res.json({ message: 'Assignment updated.', assignment });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// ── DELETE /api/assignments/:id  (Admin only) ──────────────────────────────────
export const deleteAssignment = async (req, res) => {
  try {
    if (req.user.role !== 'admin') return res.status(403).json({ message: 'Admin access required.' });
    const a = await Assignment.findByIdAndDelete(req.params.id);
    if (!a) return res.status(404).json({ message: 'Assignment not found.' });
    res.json({ message: 'Assignment deleted.' });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};