// controllers/sessionController.js
import crypto     from 'crypto';
import Session    from '../models/Session.js';
import Assignment from '../models/Assignment.js';
import Attendance from '../models/Attendance.js';

const SESSION_DURATION_MS = 15 * 60 * 1000; // 15 minutes

// ── Helper: generate HMAC digital signature ──────────────────────────────────
const generateSignature = (studentId, sessionId, timestamp) => {
  const secret = process.env.SIGNATURE_SECRET || 'change_this_in_production';
  return crypto
    .createHmac('sha256', secret)
    .update(`${studentId}:${sessionId}:${timestamp}`)
    .digest('hex');
};

// ── POST /api/sessions  (Lecturer only) ──────────────────────────────────────
export const createSession = async (req, res) => {
  try {
    if (req.user.role !== 'lecturer') {
      return res.status(403).json({ message: 'Lecturer access required.' });
    }

    const { assignmentId, location } = req.body;
    if (!assignmentId) {
      return res.status(400).json({ message: 'assignmentId is required.' });
    }

    // Verify lecturer owns this assignment
    const assignment = await Assignment.findOne({
      _id:      assignmentId,
      lecturer: req.user._id ?? req.user.id,   // handle both token formats
      isActive: true,
    }).populate('unit', 'name code');

    if (!assignment) {
      return res.status(404).json({ message: 'Assignment not found or not yours.' });
    }

    // End any currently active session for this assignment
    await Session.updateMany(
      { assignment: assignmentId, isActive: true },
      { isActive: false }
    );

    const qrToken   = Session.generateToken();
    const expiresAt = new Date(Date.now() + SESSION_DURATION_MS);

    // ── QR payload — JSON string encoded into the QR image ───────────────────
    // IMPORTANT: unitName and unitCode are included so the student app can
    // display the class name immediately after scanning, without an extra API call.
    const qrPayload = JSON.stringify({
      t:        qrToken,
      a:        assignmentId,
      u:        assignment.unit._id.toString(),
      exp:      expiresAt.getTime(),
      unitName: assignment.unit.name,   // ← displayed in student app after scan
      unitCode: assignment.unit.code,   // ← displayed in student app after scan
    });

    const session = await Session.create({
      assignment: assignmentId,
      lecturer:   req.user._id ?? req.user.id,
      unit:       assignment.unit._id,
      qrToken,
      qrPayload,
      expiresAt,
      location:   location || assignment.room || '',
    });

    res.status(201).json({
      _id:        session._id,          // Flutter uses _activeSession?['_id']
      sessionId:  session._id,
      message:    'Session started.',
      qrPayload,                        // ← encode this into the QR widget
      expiresAt,
      unitName:   assignment.unit.name,
      unitCode:   assignment.unit.code,
    });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// ── DELETE /api/sessions/:id  (Lecturer ends session early) ──────────────────
export const endSession = async (req, res) => {
  try {
    if (req.user.role !== 'lecturer') {
      return res.status(403).json({ message: 'Lecturer access required.' });
    }
    const lecturerId = req.user._id ?? req.user.id;
    const session = await Session.findOneAndUpdate(
      { _id: req.params.id, lecturer: lecturerId },
      { isActive: false },
      { new: true }
    );
    if (!session) return res.status(404).json({ message: 'Session not found.' });
    res.json({ message: 'Session ended.' });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// ── GET /api/sessions/:id/stats  (Lecturer — live scan count) ────────────────
export const getSessionStats = async (req, res) => {
  try {
    const session = await Session.findById(req.params.id)
      .populate('assignment', 'students');
    if (!session) return res.status(404).json({ message: 'Session not found.' });

    const lecturerId = req.user._id ?? req.user.id;
    if (req.user.role === 'lecturer' &&
        session.lecturer.toString() !== lecturerId.toString()) {
      return res.status(403).json({ message: 'Access denied.' });
    }

    const scanned  = await Attendance.countDocuments({ session: req.params.id });
    const total    = session.assignment?.students?.length ?? 0;   // renamed → total

    res.json({
      scanned,
      total,                                       // Flutter polls _total
      expected:  total,                            // keep for compatibility
      remaining: Math.max(0, total - scanned),
      isActive:  session.isActive,
      expiresAt: session.expiresAt,
    });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// ── POST /api/sessions/verify  (Student — full verification chain) ────────────
// Body: { qrPayload, biometricPassed, faceConfidence }
export const verifyAndMarkAttendance = async (req, res) => {
  try {
    if (req.user.role !== 'student') {
      return res.status(403).json({ message: 'Student access required.' });
    }

    const { qrPayload, biometricPassed, faceConfidence } = req.body;
    if (!qrPayload) {
      return res.status(400).json({ message: 'qrPayload is required.' });
    }

    // ── 1. Parse and validate QR payload ─────────────────────────────────────
    let parsed;
    try {
      parsed = JSON.parse(qrPayload);
    } catch {
      return res.status(400).json({ message: 'Invalid QR code.' });
    }

    const { t: qrToken, a: assignmentId, exp } = parsed;
    if (!qrToken || !assignmentId) {
      return res.status(400).json({ message: 'Malformed QR code.' });
    }

    // ── 2. Check expiry ───────────────────────────────────────────────────────
    if (Date.now() > exp) {
      return res.status(400).json({
        message: 'QR code has expired. Ask your lecturer to generate a new one.',
      });
    }

    // ── 3. Find active session ────────────────────────────────────────────────
    const session = await Session.findOne({ qrToken, isActive: true });
    if (!session) {
      return res.status(400).json({ message: 'Session not found or already closed.' });
    }
    if (new Date() > session.expiresAt) {
      await Session.findByIdAndUpdate(session._id, { isActive: false });
      return res.status(400).json({ message: 'QR code has expired.' });
    }

    // ── 4. Verify student is enrolled ─────────────────────────────────────────
    const assignment = await Assignment.findById(assignmentId);
    if (!assignment) {
      return res.status(404).json({ message: 'Assignment not found.' });
    }
    const studentId  = (req.user._id ?? req.user.id).toString();
    const isEnrolled = assignment.students.some(s => s.toString() === studentId);
    if (!isEnrolled) {
      return res.status(403).json({ message: 'You are not enrolled in this unit.' });
    }

    // ── 5. Prevent duplicate attendance ──────────────────────────────────────
    const existing = await Attendance.findOne({
      session: session._id,
      student: studentId,
    });
    if (existing) {
      return res.status(400).json({
        message: 'Attendance already marked for this session.',
      });
    }

    // ── 6. Validate biometric checks ──────────────────────────────────────────
    if (!biometricPassed) {
      return res.status(400).json({ message: 'Biometric verification failed.' });
    }
    const faceScore = parseFloat(faceConfidence) || 0;
    if (faceScore < 0.75) {
      return res.status(400).json({
        message: `Face verification failed (confidence: ${(faceScore * 100).toFixed(0)}%). Try better lighting.`,
      });
    }

    // ── 7. Generate digital signature ─────────────────────────────────────────
    const timestamp        = Date.now();
    const digitalSignature = generateSignature(studentId, session._id.toString(), timestamp);

    // ── 8. Write attendance record ────────────────────────────────────────────
    const attendance = await Attendance.create({
      session:           session._id,
      assignment:        assignment._id,
      unit:              session.unit,
      student:           studentId,
      lecturer:          session.lecturer,
      qrVerified:        true,
      biometricVerified: true,
      faceVerified:      true,
      faceConfidence:    faceScore,
      digitalSignature,
      signedAt:          new Date(timestamp),
      status:            'present',
    });

    res.status(201).json({
      message:          'Attendance marked successfully.',
      attendanceId:     attendance._id,
      digitalSignature,
      signedAt:         attendance.signedAt,
      verifications: {
        qr:        true,
        biometric: true,
        face:      true,
        faceScore: `${(faceScore * 100).toFixed(0)}%`,
      },
    });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// ── GET /api/sessions/my-attendance  (Student — attendance history) ───────────
export const getMyAttendance = async (req, res) => {
  try {
    if (req.user.role !== 'student') {
      return res.status(403).json({ message: 'Student access required.' });
    }
    const studentId = req.user._id ?? req.user.id;
    const records = await Attendance.find({ student: studentId })
      .populate('unit',    'name code')
      .populate('session', 'createdAt location')
      .populate('lecturer','fullName')
      .sort({ markedAt: -1 })
      .limit(50);

    res.json({ attendance: records });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};