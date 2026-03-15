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
// GET /api/users
// Admin  → returns lecturers + students (optionally filter by role query param)
// Lecturer → returns students only
// Student → 403
// ─────────────────────────────────────────────────────────────────────────────
export const getUsers = async (req, res) => {
  try {
    const { role: callerRole } = req.user; // set by auth middleware

    let filter = {};
    let allowedRoles = [];

    if (callerRole === 'admin') {
      // Admin can filter by ?role=lecturer|student, or get both
      const { role } = req.query;
      if (role && ['lecturer', 'student'].includes(role)) {
        allowedRoles = [role];
      } else {
        allowedRoles = ['lecturer', 'student'];
      }
    } else if (callerRole === 'lecturer') {
      // Lecturers see only students
      allowedRoles = ['student'];
    } else {
      return res.status(403).json({ message: 'Access denied.' });
    }

    filter.role = { $in: allowedRoles };

    // Optional search by name or reg number
    if (req.query.search) {
      const regex = new RegExp(req.query.search, 'i');
      filter.$or = [{ fullName: regex }, { registrationNumber: regex }, { email: regex }];
    }

    // Pagination
    const page  = Math.max(1, parseInt(req.query.page)  || 1);
    const limit = Math.min(100, parseInt(req.query.limit) || 20);
    const skip  = (page - 1) * limit;

    const [users, total] = await Promise.all([
      User.find(filter).select('-password').sort({ createdAt: -1 }).skip(skip).limit(limit),
      User.countDocuments(filter),
    ]);

    res.json({
      users,
      pagination: {
        total,
        page,
        limit,
        pages: Math.ceil(total / limit),
      },
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

    // Lecturers can only look up students
    if (callerRole === 'lecturer' && user.role !== 'student') {
      return res.status(403).json({ message: 'Access denied.' });
    }

    res.json({ user });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/users/:id   (Admin only — update role, name, etc.)
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

    // Prevent admin from deleting themselves
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