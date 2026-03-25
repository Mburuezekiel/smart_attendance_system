// controllers/attendanceController.js
import mongoose  from 'mongoose';
import Attendance from '../models/Attendance.js';
import Session    from '../models/Session.js';
import Assignment from '../models/Assignment.js';

const getUserId = (user) => user._id ?? user.id;

// ── Cast to ObjectId safely ───────────────────────────────────────────────────
const toObjectId = (id) => {
  try { return new mongoose.Types.ObjectId(id.toString()); }
  catch { return null; }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/attendance/my-history  (Student)
// ─────────────────────────────────────────────────────────────────────────────
export const getMyHistory = async (req, res) => {
  try {
    if (req.user.role !== 'student') {
      return res.status(403).json({ message: 'Student access required.' });
    }

    const rawId    = getUserId(req.user);
    const studentId = toObjectId(rawId);
    if (!studentId) return res.status(400).json({ message: 'Invalid user ID.' });

    const { unit, status, page = 1, limit = 50 } = req.query;

    // Build filter — only match on known statuses that actually exist in DB
    const filter = { student: studentId };
    if (unit   && unit   !== 'All') filter.unit   = toObjectId(unit);
    if (status && status !== 'All') {
      // Map UI label to DB value
      const dbStatus = status.toLowerCase();
      if (['present', 'late', 'failed'].includes(dbStatus)) {
        filter.status = dbStatus;
      }
    }

    const skip = (parseInt(page) - 1) * parseInt(limit);

    const [records, total] = await Promise.all([
      Attendance.find(filter)
        .populate('unit',    'name code department')
        .populate('session', 'createdAt location expiresAt')
        .populate('lecturer','fullName')
        .sort({ markedAt: -1 })
        .skip(skip)
        .limit(parseInt(limit)),
      Attendance.countDocuments(filter),
    ]);

    // ── Per-unit aggregation ──────────────────────────────────────────────────
    // NOTE: 'absent' means no record exists — so we only count present/late/failed
    // from actual records. The UI should show absent = enrolled - (present + late).
    const unitStats = await Attendance.aggregate([
      { $match: { student: studentId } },
      { $group: {
          _id:     '$unit',
          present: { $sum: { $cond: [{ $eq: ['$status', 'present'] }, 1, 0] } },
          late:    { $sum: { $cond: [{ $eq: ['$status', 'late']    }, 1, 0] } },
          failed:  { $sum: { $cond: [{ $eq: ['$status', 'failed']  }, 1, 0] } },
          total:   { $sum: 1 },
        }
      },
      { $lookup: {
          from: 'units', localField: '_id', foreignField: '_id', as: 'unitDoc'
        }
      },
      { $unwind: { path: '$unitDoc', preserveNullAndEmptyArrays: true } },
      { $project: {
          unitId:  '$_id',
          name:    '$unitDoc.name',
          code:    '$unitDoc.code',
          present: 1, late: 1, failed: 1, total: 1,
          // absent = sessions held - records (approximate)
          absent: { $max: [0, { $subtract: ['$total', { $add: ['$present', '$late'] }] }] },
          percentage: {
            $cond: [
              { $eq: ['$total', 0] }, 0,
              { $round: [{ $multiply: [{ $divide: ['$present', '$total'] }, 100] }, 0] }
            ]
          },
        }
      },
      { $sort: { name: 1 } },
    ]);

    // ── Overall summary ───────────────────────────────────────────────────────
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

    const summary = overallArr[0] ?? { present: 0, late: 0, failed: 0, total: 0 };
    // absent in summary = records that are not present
    summary.absent = summary.total - summary.present - summary.late;
    summary.percentage = summary.total > 0
      ? Math.round((summary.present / summary.total) * 100)
      : 0;

    res.json({
      records,
      unitStats,
      summary,
      pagination: { page: parseInt(page), limit: parseInt(limit), total },
    });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/attendance/lecturer-reports  (Lecturer)
// ─────────────────────────────────────────────────────────────────────────────
export const getLecturerReports = async (req, res) => {
  try {
    if (req.user.role !== 'lecturer') {
      return res.status(403).json({ message: 'Lecturer access required.' });
    }

    const rawId      = getUserId(req.user);
    const lecturerId = toObjectId(rawId);
    if (!lecturerId) return res.status(400).json({ message: 'Invalid user ID.' });

    // ── Per-unit stats ────────────────────────────────────────────────────────
    const unitStats = await Attendance.aggregate([
      { $match: { lecturer: lecturerId } },
      { $group: {
          _id:     '$unit',
          present: { $sum: { $cond: [{ $eq: ['$status', 'present'] }, 1, 0] } },
          late:    { $sum: { $cond: [{ $eq: ['$status', 'late']    }, 1, 0] } },
          absent:  { $sum: { $cond: [{ $eq: ['$status', 'failed']  }, 1, 0] } },
          total:   { $sum: 1 },
          uniqueStudents: { $addToSet: '$student' },
        }
      },
      { $lookup: { from: 'units', localField: '_id', foreignField: '_id', as: 'unitDoc' } },
      { $unwind: { path: '$unitDoc', preserveNullAndEmptyArrays: true } },
      { $project: {
          unitId:   '$_id',
          name:     '$unitDoc.name',
          code:     '$unitDoc.code',
          present:  1, late: 1, absent: 1, total: 1,
          students: { $size: '$uniqueStudents' },
          percentage: {
            $cond: [
              { $eq: ['$total', 0] }, 0,
              { $round: [{ $multiply: [{ $divide: ['$present', '$total'] }, 100] }, 0] }
            ]
          },
        }
      },
      { $sort: { name: 1 } },
    ]);

    // ── Recent sessions ───────────────────────────────────────────────────────
    const recentSessions = await Session.find({ lecturer: lecturerId })
      .populate('unit', 'name code')
      .sort({ createdAt: -1 })
      .limit(20);

    const sessionStats = await Promise.all(recentSessions.map(async (s) => {
      const scanned  = await Attendance.countDocuments({ session: s._id });
      const asgn     = await Assignment.findById(s.assignment).select('students');
      const expected = asgn?.students?.length ?? 0;
      return {
        sessionId:  s._id,
        unitName:   s.unit?.name ?? '—',
        unitCode:   s.unit?.code ?? '—',
        date:       s.createdAt,
        scanned,
        expected,
        rate:       expected > 0 ? Math.round((scanned / expected) * 100) : 0,
        isActive:   s.isActive,
      };
    }));

    // ── Overall ───────────────────────────────────────────────────────────────
    const overallArr = await Attendance.aggregate([
      { $match: { lecturer: lecturerId } },
      { $group: {
          _id:     null,
          present: { $sum: { $cond: [{ $eq: ['$status', 'present'] }, 1, 0] } },
          late:    { $sum: { $cond: [{ $eq: ['$status', 'late']    }, 1, 0] } },
          absent:  { $sum: { $cond: [{ $eq: ['$status', 'failed']  }, 1, 0] } },
          total:   { $sum: 1 },
        }
      },
    ]);

    const summary = overallArr[0] ?? { present: 0, late: 0, absent: 0, total: 0 };
    summary.percentage = summary.total > 0
      ? Math.round((summary.present / summary.total) * 100)
      : 0;

    res.json({ unitStats, sessionStats, summary });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/attendance/export
// ─────────────────────────────────────────────────────────────────────────────
export const exportAttendance = async (req, res) => {
  try {
    const { format = 'csv', unit } = req.query;
    const rawId  = getUserId(req.user);
    const userId = toObjectId(rawId);
    const { role } = req.user;

    const filter = role === 'student'
      ? { student: userId }
      : { lecturer: userId };
    if (unit && unit !== 'All') filter.unit = toObjectId(unit);

    const records = await Attendance.find(filter)
      .populate('unit',    'name code')
      .populate('student', 'fullName registrationNumber')
      .populate('session', 'createdAt location')
      .sort({ markedAt: -1 });

    if (format === 'csv') {
      const headers = role === 'student'
        ? ['Unit', 'Code', 'Date', 'Time', 'Status', 'QR', 'Biometric', 'Face', 'Location']
        : ['Student', 'Reg No', 'Unit', 'Code', 'Date', 'Time', 'Status', 'QR', 'Biometric', 'Face'];

      const rows = records.map(r => {
        const dt    = new Date(r.markedAt ?? r.createdAt);
        const dateS = dt.toLocaleDateString('en-GB');
        const timeS = dt.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' });
        return role === 'student'
          ? [r.unit?.name ?? '—', r.unit?.code ?? '—', dateS, timeS, r.status,
             r.qrVerified ? 'Yes' : 'No', r.biometricVerified ? 'Yes' : 'No',
             r.faceVerified ? 'Yes' : 'No', r.session?.location ?? '—']
          : [r.student?.fullName ?? '—', r.student?.registrationNumber ?? '—',
             r.unit?.name ?? '—', r.unit?.code ?? '—', dateS, timeS, r.status,
             r.qrVerified ? 'Yes' : 'No', r.biometricVerified ? 'Yes' : 'No',
             r.faceVerified ? 'Yes' : 'No'];
      });

      const csv = [headers, ...rows]
        .map(row => row.map(c => `"${String(c).replace(/"/g, '""')}"`).join(','))
        .join('\n');

      res.setHeader('Content-Type', 'text/csv');
      res.setHeader('Content-Disposition',
          `attachment; filename="attendance_${Date.now()}.csv"`);
      return res.send(csv);
    }

    res.json({ records, count: records.length });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};