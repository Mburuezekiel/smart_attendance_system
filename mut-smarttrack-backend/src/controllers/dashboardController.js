// controllers/dashboardController.js
import mongoose  from 'mongoose';
import Attendance from '../models/Attendance.js';
import Assignment from '../models/Assignment.js';
import Timetable  from '../models/Timetable.js';
import Session    from '../models/Session.js';

const getUserId  = (user) => user._id ?? user.id;
const toObjectId = (id) => {
  try { return new mongoose.Types.ObjectId(id.toString()); }
  catch { return null; }
};

const DAY_NAMES = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/dashboard/student
// ─────────────────────────────────────────────────────────────────────────────
export const getStudentDashboard = async (req, res) => {
  try {
    if (req.user.role !== 'student') {
      return res.status(403).json({ message: 'Student access required.' });
    }

    const rawId     = getUserId(req.user);
    const studentId = toObjectId(rawId);
    if (!studentId) return res.status(400).json({ message: 'Invalid user ID.' });

    const today     = new Date();
    const todayName = DAY_NAMES[today.getDay()];

    // ── 1. Attendance summary ─────────────────────────────────────────────────
    const overallArr = await Attendance.aggregate([
      { $match: { student: studentId } },
      { $group: {
          _id:     null,
          present: { $sum: { $cond: [{ $eq: ['$status', 'present'] }, 1, 0] } },
          late:    { $sum: { $cond: [{ $eq: ['$status', 'late']    }, 1, 0] } },
          failed:  { $sum: { $cond: [{ $eq: ['$status', 'failed']  }, 1, 0] } },
          total:   { $sum: 1 },
        }
      },
    ]);

    const raw  = overallArr[0] ?? { present: 0, late: 0, failed: 0, total: 0 };
    const stats = {
      present:    raw.present,
      late:       raw.late,
      absent:     raw.total - raw.present - raw.late,  // approx
      total:      raw.total,
      percentage: raw.total > 0
        ? Math.round((raw.present / raw.total) * 100)
        : 0,
    };

    // ── 2. Today's timetable ──────────────────────────────────────────────────
    const assignments = await Assignment.find({ students: studentId }).select('_id');
    const assignmentIds = assignments.map(a => a._id);

    const todayClasses = await Timetable.find({
      assignment: { $in: assignmentIds },
      day:        todayName,
      isActive:   true,
    })
      .populate('unit',     'name code')
      .populate('lecturer', 'fullName')
      .sort({ startTime: 1 });

    const nowMins = today.getHours() * 60 + today.getMinutes();

    let nextSet = false;
    const classesWithFlags = todayClasses.map(c => {
      const [sh, sm] = c.startTime.split(':').map(Number);
      const [eh, em] = c.endTime.split(':').map(Number);
      const startM   = sh * 60 + sm;
      const endM     = eh * 60 + em;
      const isNow    = nowMins >= startM && nowMins < endM;
      const isFuture = nowMins < startM;
      const isNext   = isFuture && !nextSet;
      if (isNext) nextSet = true;
      return {
        _id:       c._id,
        unitName:  c.unit?.name    ?? '—',
        unitCode:  c.unit?.code    ?? '—',
        lecturer:  c.lecturer?.fullName ?? '—',
        startTime: c.startTime,
        endTime:   c.endTime,
        room:      c.room,
        isNow,
        isNext,
      };
    });

    // ── 3. Recent activity ────────────────────────────────────────────────────
    const recent = await Attendance.find({ student: studentId })
      .populate('unit', 'name code')
      .sort({ markedAt: -1 })
      .limit(5);

    // ── 4. Enrolled units (deduplicated) ──────────────────────────────────────
    const tSlots = await Timetable.find({
      assignment: { $in: assignmentIds }, isActive: true,
    })
      .populate('unit',     'name code department')
      .populate('lecturer', 'fullName');

    const seen  = new Set();
    const units = [];
    for (const t of tSlots) {
      const id = t.unit?._id?.toString();
      if (id && !seen.has(id)) {
        seen.add(id);
        units.push({ unit: t.unit, lecturer: t.lecturer });
      }
    }

    res.json({
      stats,
      todayClasses:   classesWithFlags,
      recentActivity: recent.map(r => ({
        unitName: r.unit?.name ?? '—',
        unitCode: r.unit?.code ?? '—',
        status:   r.status,
        markedAt: r.markedAt ?? r.createdAt,
      })),
      enrolledUnits: units,
    });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/dashboard/lecturer
// ─────────────────────────────────────────────────────────────────────────────
export const getLecturerDashboard = async (req, res) => {
  try {
    if (req.user.role !== 'lecturer') {
      return res.status(403).json({ message: 'Lecturer access required.' });
    }

    const rawId      = getUserId(req.user);
    const lecturerId = toObjectId(rawId);
    if (!lecturerId) return res.status(400).json({ message: 'Invalid user ID.' });

    const today     = new Date();
    const todayName = DAY_NAMES[today.getDay()];
    const nowMins   = today.getHours() * 60 + today.getMinutes();

    // ── 1. Today's schedule ───────────────────────────────────────────────────
    const todayClasses = await Timetable.find({
      lecturer: lecturerId,
      day:      todayName,
      isActive: true,
    })
      .populate('unit', 'name code')
      .sort({ startTime: 1 });

    const scheduleWithStats = await Promise.all(todayClasses.map(async c => {
      const [sh, sm] = c.startTime.split(':').map(Number);
      const [eh, em] = c.endTime.split(':').map(Number);
      const isNow    = nowMins >= sh * 60 + sm && nowMins < eh * 60 + em;

      const asgn  = await Assignment.findById(c.assignment).select('students');
      const total = asgn?.students?.length ?? 0;

      const startOfDay = new Date(today); startOfDay.setHours(0, 0, 0, 0);
      const session = await Session.findOne({
        lecturer:  lecturerId,
        unit:      c.unit?._id,
        createdAt: { $gte: startOfDay },
      }).sort({ createdAt: -1 });

      const present = session
        ? await Attendance.countDocuments({ session: session._id })
        : 0;

      return {
        _id:       c._id,
        unitName:  c.unit?.name ?? '—',
        unitCode:  c.unit?.code ?? '—',
        startTime: c.startTime,
        endTime:   c.endTime,
        room:      c.room,
        present, total, isNow,
      };
    }));

    // ── 2. Overall stats ──────────────────────────────────────────────────────
    const assignments = await Assignment.find({ lecturer: lecturerId });
    const totalStudents = new Set(
      assignments.flatMap(a => a.students.map(s => s.toString()))
    ).size;

    const overallArr = await Attendance.aggregate([
      { $match: { lecturer: lecturerId } },
      { $group: {
          _id:     null,
          present: { $sum: { $cond: [{ $eq: ['$status', 'present'] }, 1, 0] } },
          total:   { $sum: 1 },
        }
      },
    ]);
    const avgAttendance = overallArr[0]?.total > 0
      ? Math.round((overallArr[0].present / overallArr[0].total) * 100)
      : 0;

    // ── 3. Per-unit attendance bars ───────────────────────────────────────────
    const unitAttendance = await Attendance.aggregate([
      { $match: { lecturer: lecturerId } },
      { $group: {
          _id:     '$unit',
          present: { $sum: { $cond: [{ $eq: ['$status', 'present'] }, 1, 0] } },
          total:   { $sum: 1 },
        }
      },
      { $lookup: { from: 'units', localField: '_id', foreignField: '_id', as: 'unitDoc' } },
      { $unwind: { path: '$unitDoc', preserveNullAndEmptyArrays: true } },
      { $project: {
          name: '$unitDoc.name',
          code: '$unitDoc.code',
          pct: {
            $cond: [
              { $eq: ['$total', 0] }, 0,
              { $round: [{ $multiply: [{ $divide: ['$present', '$total'] }, 100] }, 0] }
            ]
          },
        }
      },
      { $sort: { name: 1 } },
    ]);

    res.json({
      classesToday:   scheduleWithStats.length,
      totalStudents,
      avgAttendance,
      todaySchedule:  scheduleWithStats,
      unitAttendance,
    });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};