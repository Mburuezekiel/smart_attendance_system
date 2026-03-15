// controllers/unitController.js
import Unit from '../models/Unit.js';

// ── GET /api/units  ──────────────────────────────────────────────────────────
export const getUnits = async (req, res) => {
  try {
    const filter = {};
    if (req.query.department) filter.department = new RegExp(req.query.department, 'i');
    if (req.query.year)       filter.year = parseInt(req.query.year);
    if (req.query.isActive !== undefined) filter.isActive = req.query.isActive === 'true';

    const units = await Unit.find(filter).sort({ code: 1 });
    res.json({ units });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// ── POST /api/units  (Admin only) ────────────────────────────────────────────
export const createUnit = async (req, res) => {
  try {
    if (req.user.role !== 'admin') return res.status(403).json({ message: 'Admin access required.' });

    const { name, code, department, description, year, semester } = req.body;
    if (!name || !code || !department || !year || !semester) {
      return res.status(400).json({ message: 'name, code, department, year and semester are required.' });
    }

    const unit = await Unit.create({ name, code, department, description, year, semester });
    res.status(201).json({ message: 'Unit created.', unit });
  } catch (err) {
    if (err.code === 11000) return res.status(400).json({ message: 'Unit code already exists.' });
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// ── PATCH /api/units/:id  (Admin only) ───────────────────────────────────────
export const updateUnit = async (req, res) => {
  try {
    if (req.user.role !== 'admin') return res.status(403).json({ message: 'Admin access required.' });

    const allowed = ['name', 'code', 'department', 'description', 'year', 'semester', 'isActive'];
    const updates = Object.fromEntries(Object.entries(req.body).filter(([k]) => allowed.includes(k)));

    const unit = await Unit.findByIdAndUpdate(req.params.id, { $set: updates }, { new: true, runValidators: true });
    if (!unit) return res.status(404).json({ message: 'Unit not found.' });

    res.json({ message: 'Unit updated.', unit });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// ── DELETE /api/units/:id  (Admin only) ──────────────────────────────────────
export const deleteUnit = async (req, res) => {
  try {
    if (req.user.role !== 'admin') return res.status(403).json({ message: 'Admin access required.' });

    const unit = await Unit.findByIdAndDelete(req.params.id);
    if (!unit) return res.status(404).json({ message: 'Unit not found.' });

    res.json({ message: 'Unit deleted.' });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};