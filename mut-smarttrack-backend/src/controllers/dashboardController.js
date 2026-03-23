// controllers/dashboardController.js
import Attendance from '../models/Attendance.js';
import Assignment from '../models/Assignment.js';
import Timetable  from '../models/Timetable.js';
import Session    from '../models/Session.js';

const getUserId = (user) => user._id ?? user.id;

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/dashboard/student
// Returns everything the student home page needs in one call
// ─────────────────────────────────────────────────────────────────────────────
export const getStudentDashboard = async (req, res) => {
  try {
    if (req.user.role !== 'student') {
      return res.status(403).json({ message: 'Student access required.' });
    }

    const studentId = getUserId(req.user);
    const today     = new Date();
    const dayNames  = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
    const todayName = dayNames[today.getDay()];

    // ── 1. Attendance summary ────────────────────────────────────────────────
    const [summary] = await Attendance.aggregate([
      { $match: { student: studentId } },
      { $group: {
          _id:     null,
          present: { $sum: { $cond: [{ $eq: ['$status', 'present'] }, 1, 0] } },
          late:    { $sum: { $cond: [{ $eq: ['$status', 'late']    }, 1, 0] } },
          absent:  { $sum: { $cond: [{ $eq: ['$status', 'failed']  }, 1, 0] } },
          total:   { $sum: 1 },
        }
      },
    ]);

    const stats = summary ?? { present: 0, late: 0, absent: 0, total: 0 };
    stats.percentage = stats.total > 0
      ? Math.round((stats.present / stats.total) * 100)
      : 0;

    // ── 2. Today's timetable ─────────────────────────────────────────────────
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

    // Mark which class is happening now
    const nowMins = today.getHours() * 60 + today.getMinutes();
    const classesWithNow = todayClasses.map(c => {
      const [sh, sm] = c.startTime.split(':').map(Number);
      const [eh, em] = c.endTime.split(':').map(Number);
      return {
        _id:        c._id,
        unitName:   c.unit?.name    ?? '—',
        unitCode:   c.unit?.code    ?? '—',
        lecturer:   c.lecturer?.fullName ?? '—',
        startTime:  c.startTime,
        endTime:    c.endTime,
        room:       c.room,
        isNow:      nowMins >= sh * 60 + sm && nowMins < eh * 60 + em,
        isNext:     false, // set below
      };
    });

    // Mark the first future class as "next"
    const nextIdx = classesWithNow.findIndex(
      c => nowMins < c.startTime.split(':').reduce((h, m, i) => i === 0 ? +h * 60 : +h + +m)
    );
    if (nextIdx !== -1) classesWithNow[nextIdx].isNext = true;

    // ── 3. Recent attendance activity ────────────────────────────────────────
    const recentActivity = await Attendance.find({ student: studentId })
      .populate('unit', 'name code')
      .sort({ markedAt: -1 })
      .limit(5);

    // ── 4. Units enrolled ────────────────────────────────────────────────────
    const enrolledUnits = await Timetable.find({
      assignment: { $in: assignmentIds }, isActive: true,
    })
      .populate('unit',     'name code department')
      .populate('lecturer', 'fullName')
      .select('unit lecturer');

    // Deduplicate by unit id
    const seen  = new Set();
    const units = [];
    for (const t of enrolledUnits) {
      const id = t.unit?._id?.toString();
      if (id && !seen.has(id)) {
        seen.add(id);
        units.push({ unit: t.unit, lecturer: t.lecturer });
      }
    }

    res.json({
      stats,
      todayClasses: classesWithNow,
      recentActivity: recentActivity.map(r => ({
        unitName:  r.unit?.name ?? '—',
        unitCode:  r.unit?.code ?? '—',
        status:    r.status,
        markedAt:  r.markedAt ?? r.createdAt,
      })),
      enrolledUnits: units,
    });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/dashboard/lecturer
// Returns everything the lecturer home page needs in one call
// ─────────────────────────────────────────────────────────────────────────────
export const getLecturerDashboard = async (req, res) => {
  try {
    if (req.user.role !== 'lecturer') {
      return res.status(403).json({ message: 'Lecturer access required.' });
    }

    const lecturerId = getUserId(req.user);
    const today      = new Date();
    const dayNames   = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
    const todayName  = dayNames[today.getDay()];

    // ── 1. Today's schedule ───────────────────────────────────────────────────
    const todayClasses = await Timetable.find({
      lecturer: lecturerId,
      day:      todayName,
      isActive: true,
    })
      .populate('unit', 'name code')
      .sort({ startTime: 1 });

    const nowMins = today.getHours() * 60 + today.getMinutes();

    const scheduleWithStats = await Promise.all(todayClasses.map(async c => {
      const [sh, sm] = c.startTime.split(':').map(Number);
      const [eh, em] = c.endTime.split(':').map(Number);

      // Find assignment for this timetable slot to get student count
      const assignment = await Assignment.findById(c.assignment).select('students');
      const total      = assignment?.students?.length ?? 0;

      // Count attendance for most recent session for this unit today
      const startOfDay = new Date(today); startOfDay.setHours(0,0,0,0);
      const session    = await Session.findOne({
        lecturer: lecturerId, unit: c.unit?._id,
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
        present,
        total,
        isNow:     nowMins >= sh * 60 + sm && nowMins < eh * 60 + em,
      };
    }));

    // ── 2. Overall stats ──────────────────────────────────────────────────────
    const assignments = await Assignment.find({ lecturer: lecturerId });
    const totalStudents = new Set(
      assignments.flatMap(a => a.students.map(s => s.toString()))
    ).size;

    const [overall] = await Attendance.aggregate([
      { $match: { lecturer: lecturerId } },
      { $group: {
          _id:     null,
          present: { $sum: { $cond: [{ $eq: ['$status', 'present'] }, 1, 0] } },
          total:   { $sum: 1 },
        }
      },
    ]);

    const avgAttendance = overall?.total > 0
      ? Math.round((overall.present / overall.total) * 100)
      : 0;

    // ── 3. Per-unit attendance breakdown ──────────────────────────────────────
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
          name:    '$unitDoc.name',
          code:    '$unitDoc.code',
          pct: { $round: [{ $multiply: [{ $divide: ['$present', '$total'] }, 100] }, 0] },
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