// controllers/attendanceController.js
import Attendance from '../models/Attendance.js';
import Session    from '../models/Session.js';
import Assignment from '../models/Assignment.js';

const getUserId = (user) => user._id ?? user.id;

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/attendance/my-history  (Student)
// Returns paginated attendance records + per-unit stats
// ─────────────────────────────────────────────────────────────────────────────
export const getMyHistory = async (req, res) => {
  try {
    if (req.user.role !== 'student') {
      return res.status(403).json({ message: 'Student access required.' });
    }

    const studentId = getUserId(req.user);
    const { unit, status, page = 1, limit = 50 } = req.query;

    const filter = { student: studentId };
    if (unit   && unit   !== 'All') filter.unit   = unit;
    if (status && status !== 'All') filter.status = status.toLowerCase();

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
    const unitStats = await Attendance.aggregate([
      { $match: { student: studentId } },
      { $group: {
          _id:     '$unit',
          present: { $sum: { $cond: [{ $eq: ['$status', 'present'] }, 1, 0] } },
          late:    { $sum: { $cond: [{ $eq: ['$status', 'late']    }, 1, 0] } },
          absent:  { $sum: { $cond: [{ $eq: ['$status', 'failed']  }, 1, 0] } },
          total:   { $sum: 1 },
        }
      },
      { $lookup: { from: 'units', localField: '_id', foreignField: '_id', as: 'unitDoc' } },
      { $unwind: { path: '$unitDoc', preserveNullAndEmptyArrays: true } },
      { $project: {
          unitId:  '$_id',
          name:    '$unitDoc.name',
          code:    '$unitDoc.code',
          present: 1, late: 1, absent: 1, total: 1,
          percentage: {
            $round: [{ $multiply: [{ $divide: ['$present', '$total'] }, 100] }, 0]
          },
        }
      },
      { $sort: { name: 1 } },
    ]);

    // ── Overall summary ───────────────────────────────────────────────────────
    const overall = await Attendance.aggregate([
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

    const summary = overall[0] ?? { present: 0, late: 0, absent: 0, total: 0 };
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
// Returns per-unit attendance stats for all units the lecturer teaches
// ─────────────────────────────────────────────────────────────────────────────
export const getLecturerReports = async (req, res) => {
  try {
    if (req.user.role !== 'lecturer') {
      return res.status(403).json({ message: 'Lecturer access required.' });
    }

    const lecturerId = getUserId(req.user);

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
            $round: [{ $multiply: [{ $divide: ['$present', '$total'] }, 100] }, 0]
          },
        }
      },
      { $sort: { name: 1 } },
    ]);

    // ── Recent sessions with scan counts ──────────────────────────────────────
    const recentSessions = await Session.find({ lecturer: lecturerId })
      .populate('unit', 'name code')
      .sort({ createdAt: -1 })
      .limit(20);

    const sessionStats = await Promise.all(recentSessions.map(async (s) => {
      const scanned  = await Attendance.countDocuments({ session: s._id });
      const expected = await Assignment.findById(s.assignment)
        .select('students').then(a => a?.students?.length ?? 0);
      return {
        sessionId:  s._id,
        unitName:   s.unit?.name ?? '—',
        unitCode:   s.unit?.code ?? '—',
        date:       s.createdAt,
        scanned,
        expected,
        rate: expected > 0 ? Math.round((scanned / expected) * 100) : 0,
        isActive: s.isActive,
      };
    }));

    // ── Overall ───────────────────────────────────────────────────────────────
    const overall = await Attendance.aggregate([
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

    const summary = overall[0] ?? { present: 0, late: 0, absent: 0, total: 0 };
    summary.percentage = summary.total > 0
      ? Math.round((summary.present / summary.total) * 100)
      : 0;

    res.json({ unitStats, sessionStats, summary });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/attendance/export  (Student or Lecturer)
// Returns CSV or JSON data for download
// Query: ?format=csv|json&role=student|lecturer&unit=<id>
// ─────────────────────────────────────────────────────────────────────────────
export const exportAttendance = async (req, res) => {
  try {
    const { format = 'csv', unit } = req.query;
    const userId = getUserId(req.user);
    const { role } = req.user;

    const filter = role === 'student'
      ? { student: userId }
      : { lecturer: userId };

    if (unit && unit !== 'All') filter.unit = unit;

    const records = await Attendance.find(filter)
      .populate('unit',    'name code')
      .populate('student', 'fullName registrationNumber')
      .populate('session', 'createdAt location')
      .sort({ markedAt: -1 });

    if (format === 'csv') {
      // Build CSV
      const headers = role === 'student'
        ? ['Unit', 'Code', 'Date', 'Time', 'Status', 'QR', 'Biometric', 'Face', 'Location']
        : ['Student', 'Reg No', 'Unit', 'Code', 'Date', 'Time', 'Status', 'QR', 'Biometric', 'Face'];

      const rows = records.map(r => {
        const date  = new Date(r.markedAt ?? r.createdAt);
        const dateS = date.toLocaleDateString('en-GB');
        const timeS = date.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' });

        if (role === 'student') {
          return [
            r.unit?.name ?? '—',
            r.unit?.code ?? '—',
            dateS, timeS,
            r.status,
            r.qrVerified        ? 'Yes' : 'No',
            r.biometricVerified ? 'Yes' : 'No',
            r.faceVerified      ? 'Yes' : 'No',
            r.session?.location ?? '—',
          ];
        } else {
          return [
            r.student?.fullName            ?? '—',
            r.student?.registrationNumber  ?? '—',
            r.unit?.name ?? '—',
            r.unit?.code ?? '—',
            dateS, timeS,
            r.status,
            r.qrVerified        ? 'Yes' : 'No',
            r.biometricVerified ? 'Yes' : 'No',
            r.faceVerified      ? 'Yes' : 'No',
          ];
        }
      });

      const csv = [headers, ...rows]
        .map(row => row.map(cell => `"${String(cell).replace(/"/g, '""')}"`).join(','))
        .join('\n');

      res.setHeader('Content-Type', 'text/csv');
      res.setHeader('Content-Disposition', `attachment; filename="attendance_${Date.now()}.csv"`);
      return res.send(csv);
    }

    // JSON fallback
    res.json({ records, count: records.length });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};