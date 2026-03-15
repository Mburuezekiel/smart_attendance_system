// controllers/userController.js
import User from '../models/User.js';

// ─────────────────────────────────────────────────────────────────────────────
// Helper: strip sensitive fields before sending
// ─────────────────────────────────────────────────────────────────────────────
const sanitize = (user) => {
  const obj = user.toObject();
  delete obj.password;
  return obj;
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/users/dashboard-stats   (Admin only)
// Returns real counts from the DB for the admin dashboard KPIs.
// ─────────────────────────────────────────────────────────────────────────────
export const getDashboardStats = async (req, res) => {
  try {
    if (req.user.role !== 'admin') {
      return res.status(403).json({ message: 'Admin access required.' });
    }

    const [totalStudents, totalLecturers] = await Promise.all([
      User.countDocuments({ role: 'student' }),
      User.countDocuments({ role: 'lecturer' }),
    ]);

    // ── Delta strings ──────────────────────────────────────────────────────
    // Count students/lecturers created in the last 7 / 30 days
    const sevenDaysAgo  = new Date(Date.now() - 7  * 24 * 60 * 60 * 1000);
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);

    const [newStudents, newLecturers] = await Promise.all([
      User.countDocuments({ role: 'student',  createdAt: { $gte: sevenDaysAgo  } }),
      User.countDocuments({ role: 'lecturer', createdAt: { $gte: thirtyDaysAgo } }),
    ]);

    // ── Dept attendance breakdown (placeholder — swap with real Attendance
    //    model aggregation once you have that collection) ───────────────────
    const deptAttendance = [
      { name: 'Computer Science', pct: 92 },
      { name: 'Mathematics',       pct: 84 },
      { name: 'Engineering',       pct: 78 },
      { name: 'Business Admin',   pct: 71 },
      { name: 'Social Sciences',  pct: 65 },
    ];

    res.json({
      totalStudents,
      totalLecturers,
      overallAttendance: 78,          // replace with real Attendance aggregation
      activeAlerts: 6,                // replace with real Alerts collection count
      studentDelta:    `+${newStudents} this week`,
      lecturerDelta:   `+${newLecturers} this month`,
      attendanceDelta: '↑ 3% vs last week',
      alertDetail:     '2 critical',
      deptAttendance,
    });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/users/lecturer-stats   (Lecturer only)
// Returns the logged-in lecturer's dashboard KPIs.
// ─────────────────────────────────────────────────────────────────────────────
export const getLecturerStats = async (req, res) => {
  try {
    if (req.user.role !== 'lecturer') {
      return res.status(403).json({ message: 'Lecturer access required.' });
    }

    // Total students in the system (visible to this lecturer)
    const totalStudents = await User.countDocuments({ role: 'student' });

    // ── Placeholders — swap these with real queries once you have
    //    a Timetable / Attendance / Session collection ───────────────────────
    const classesToday   = 4;
    const avgAttendance  = 82;
    const pendingReports = 3;

    const todaySchedule = [
      { name: 'Mathematics 201',      group: 'Yr 2 · Sec A', time: '08:00', room: 'Room LH-3', present: 48, total: 52, isNow: true  },
      { name: 'Computer Networks',    group: 'Yr 3 · Sec B', time: '10:00', room: 'Lab C-2',   present: 31, total: 35, isNow: false },
      { name: 'Software Engineering', group: 'Yr 4 · Sec A', time: '14:00', room: 'Room LH-7', present: 40, total: 40, isNow: false },
    ];

    const unitAttendance = [
      { name: 'Mathematics 201',      pct: 87 },
      { name: 'Computer Networks',    pct: 74 },
      { name: 'Software Engineering', pct: 91 },
      { name: 'Database Systems',     pct: 68 },
    ];

    res.json({
      classesToday,
      totalStudents,
      avgAttendance,
      pendingReports,
      todaySchedule,
      unitAttendance,
    });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/users
// Admin  → returns lecturers + students (optionally filter by role query param)
// Lecturer → returns students only
// Student → 403
// ─────────────────────────────────────────────────────────────────────────────
export const getUsers = async (req, res) => {
  try {
    const { role: callerRole } = req.user;

    let filter = {};
    let allowedRoles = [];

    if (callerRole === 'admin') {
      const { role } = req.query;
      if (role && ['lecturer', 'student'].includes(role)) {
        allowedRoles = [role];
      } else {
        allowedRoles = ['lecturer', 'student'];
      }
    } else if (callerRole === 'lecturer') {
      allowedRoles = ['student'];
    } else {
      return res.status(403).json({ message: 'Access denied.' });
    }

    filter.role = { $in: allowedRoles };

    if (req.query.search) {
      const regex = new RegExp(req.query.search, 'i');
      filter.$or = [{ fullName: regex }, { registrationNumber: regex }, { email: regex }];
    }

    const page  = Math.max(1, parseInt(req.query.page)  || 1);
    const limit = Math.min(100, parseInt(req.query.limit) || 20);
    const skip  = (page - 1) * limit;

    const [users, total] = await Promise.all([
      User.find(filter).select('-password').sort({ createdAt: -1 }).skip(skip).limit(limit),
      User.countDocuments(filter),
    ]);

    res.json({
      users,
      pagination: { total, page, limit, pages: Math.ceil(total / limit) },
    });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/users/:id
// Admin → any user; Lecturer → students only; Student → 403
// ─────────────────────────────────────────────────────────────────────────────
export const getUserById = async (req, res) => {
  try {
    const { role: callerRole } = req.user;

    if (callerRole === 'student') {
      return res.status(403).json({ message: 'Access denied.' });
    }

    const user = await User.findById(req.params.id).select('-password');
    if (!user) return res.status(404).json({ message: 'User not found.' });

    if (callerRole === 'lecturer' && user.role !== 'student') {
      return res.status(403).json({ message: 'Access denied.' });
    }

    res.json({ user });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/users/:id   (Admin only)
// ─────────────────────────────────────────────────────────────────────────────
export const updateUser = async (req, res) => {
  try {
    if (req.user.role !== 'admin') {
      return res.status(403).json({ message: 'Admin access required.' });
    }

    const allowed = ['fullName', 'email', 'role', 'registrationNumber'];
    const updates = Object.fromEntries(
      Object.entries(req.body).filter(([k]) => allowed.includes(k))
    );

    if (updates.role && !['student', 'lecturer', 'admin'].includes(updates.role)) {
      return res.status(400).json({ message: 'Invalid role.' });
    }

    const user = await User.findByIdAndUpdate(
      req.params.id,
      { $set: updates },
      { new: true, runValidators: true }
    ).select('-password');

    if (!user) return res.status(404).json({ message: 'User not found.' });

    res.json({ message: 'User updated.', user });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// DELETE /api/users/:id   (Admin only)
// ─────────────────────────────────────────────────────────────────────────────
export const deleteUser = async (req, res) => {
  try {
    if (req.user.role !== 'admin') {
      return res.status(403).json({ message: 'Admin access required.' });
    }

    if (req.params.id === req.user._id.toString()) {
      return res.status(400).json({ message: 'Cannot delete your own account.' });
    }

    const user = await User.findByIdAndDelete(req.params.id);
    if (!user) return res.status(404).json({ message: 'User not found.' });

    res.json({ message: 'User deleted.' });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};