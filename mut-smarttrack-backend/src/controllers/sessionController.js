// controllers/sessionController.js
import crypto     from 'crypto';
import Session    from '../models/Session.js';
import Assignment from '../models/Assignment.js';
import Attendance from '../models/Attendance.js';

const SESSION_DURATION_MS = 15 * 60 * 1000; // 15 minutes

// ── Helper: HMAC digital signature ───────────────────────────────────────────
const generateSignature = (studentId, sessionId, timestamp) => {
  const secret = process.env.SIGNATURE_SECRET || 'change_this_in_production';
  return crypto.createHmac('sha256', secret)
    .update(`${studentId}:${sessionId}:${timestamp}`)
    .digest('hex');
};

// ── Helper: single-use CANDLELIGHT relay token ────────────────────────────────
// Chained to the verified student's attendanceId so the backend can trace
// exactly who passed the chain to whom.
const generateRelayToken = (attendanceId, studentId, sessionId) => {
  const secret = process.env.SIGNATURE_SECRET || 'change_this_in_production';
  return crypto.createHmac('sha256', secret)
    .update(`relay:${attendanceId}:${studentId}:${sessionId}`)
    .digest('hex');
};

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/sessions  (Lecturer only)
// ─────────────────────────────────────────────────────────────────────────────
export const createSession = async (req, res) => {
  try {
    if (req.user.role !== 'lecturer') {
      return res.status(403).json({ message: 'Lecturer access required.' });
    }

    const { assignmentId, location } = req.body;
    if (!assignmentId) {
      return res.status(400).json({ message: 'assignmentId is required.' });
    }

    const lecturerId = req.user._id ?? req.user.id;

    const assignment = await Assignment.findOne({
      _id: assignmentId, lecturer: lecturerId, isActive: true,
    }).populate('unit', 'name code');

    if (!assignment) {
      return res.status(404).json({ message: 'Assignment not found or not yours.' });
    }

    // Close any currently active session for this assignment
    await Session.updateMany(
      { assignment: assignmentId, isActive: true },
      { isActive: false }
    );

    const qrToken   = Session.generateToken();
    const expiresAt = new Date(Date.now() + SESSION_DURATION_MS);

    // relay: false marks this as the original lecturer QR (not a student relay)
    const qrPayload = JSON.stringify({
      t:        qrToken,
      a:        assignmentId,
      u:        assignment.unit._id.toString(),
      exp:      expiresAt.getTime(),
      unitName: assignment.unit.name,
      unitCode: assignment.unit.code,
      relay:    false,
    });

    const session = await Session.create({
      assignment: assignmentId,
      lecturer:   lecturerId,
      unit:       assignment.unit._id,
      qrToken,
      qrPayload,
      expiresAt,
      location:   location || assignment.room || '',
    });

    res.status(201).json({
      _id:        session._id,
      sessionId:  session._id,
      message:    'Session started.',
      qrPayload,
      expiresAt,
      unitName:   assignment.unit.name,
      unitCode:   assignment.unit.code,
    });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// DELETE /api/sessions/:id  (Lecturer — kills the session AND all relay chains)
// ─────────────────────────────────────────────────────────────────────────────
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

    // Burn ALL relay tokens for this session instantly
    // Any student QR shown after this point will fail validation
    await Attendance.updateMany(
      { session: req.params.id },
      { relayToken: null, relayUsed: true }
    );

    res.json({ message: 'Session ended. All relay tokens revoked.' });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/sessions/:id/stats
// ─────────────────────────────────────────────────────────────────────────────
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

    const scanned = await Attendance.countDocuments({ session: req.params.id });
    const total   = session.assignment?.students?.length ?? 0;

    res.json({
      scanned,
      total,
      expected:  total,
      remaining: Math.max(0, total - scanned),
      isActive:  session.isActive,
      expiresAt: session.expiresAt,
    });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/sessions/verify  (Student marks attendance)
//
// ╔══════════════ CANDLELIGHT ALGORITHM ══════════════╗
// ║                                                   ║
// ║  Lecturer generates original QR (relay: false)    ║
// ║       ↓                                           ║
// ║  Student A scans → signs → gets relayQrPayload    ║
// ║       ↓  (relayToken burned on Student B's scan)  ║
// ║  Student B scans A's QR → signs → gets own relay  ║
// ║       ↓                                           ║
// ║  ...chain continues...                            ║
// ║       ↓                                           ║
// ║  Lecturer ends session → ALL relay tokens nuked   ║
// ║  No further QRs work regardless of who holds them ║
// ╚═══════════════════════════════════════════════════╝
//
// Anti-screenshot: relay tokens are single-use and burned immediately.
// Anti-fraud: each relay is tied to a real verified attendance record.
// Anti-loophole: session.isActive is checked on EVERY scan.
// ─────────────────────────────────────────────────────────────────────────────
export const verifyAndMarkAttendance = async (req, res) => {
  try {
    if (req.user.role !== 'student') {
      return res.status(403).json({ message: 'Student access required.' });
    }

    const { qrPayload, biometricPassed, faceConfidence } = req.body;
    if (!qrPayload) {
      return res.status(400).json({ message: 'qrPayload is required.' });
    }

    // ── 1. Parse QR payload ───────────────────────────────────────────────────
    let parsed;
    try { parsed = JSON.parse(qrPayload); }
    catch { return res.status(400).json({ message: 'Invalid QR code.' }); }

    const { t: qrToken, a: assignmentId, exp, relay, relayToken } = parsed;
    if (!qrToken || !assignmentId) {
      return res.status(400).json({ message: 'Malformed QR code.' });
    }

    // ── 2. Expiry check ───────────────────────────────────────────────────────
    if (Date.now() > exp) {
      return res.status(400).json({
        message: 'QR code has expired. Ask your lecturer for a new one.',
      });
    }

    // ── 3. Find active session ────────────────────────────────────────────────
    const session = await Session.findOne({ qrToken, isActive: true });
    if (!session) {
      return res.status(400).json({
        message: 'Session not found or the lecturer has already ended it.',
      });
    }
    if (new Date() > session.expiresAt) {
      await Session.findByIdAndUpdate(session._id, { isActive: false });
      return res.status(400).json({ message: 'QR code has expired.' });
    }

    // ── 4. RELAY CHAIN VALIDATION ─────────────────────────────────────────────
    if (relay === true) {
      if (!relayToken) {
        return res.status(400).json({ message: 'Relay QR is missing its token.' });
      }

      // Find the attendance record that owns this relay token
      const relaySource = await Attendance.findOne({
        session:    session._id,
        relayToken: relayToken,
        relayUsed:  false,     // must not have been used yet
      });

      if (!relaySource) {
        return res.status(400).json({
          message: 'This relay QR has already been used or the session ended. Ask a different classmate.',
        });
      }

      // BURN immediately — one-time use enforced at the DB level
      await Attendance.findByIdAndUpdate(relaySource._id, {
        relayToken: null,
        relayUsed:  true,
      });
    }

    // ── 5. Enrolment check ────────────────────────────────────────────────────
    const assignment = await Assignment.findById(assignmentId);
    if (!assignment) {
      return res.status(404).json({ message: 'Assignment not found.' });
    }
    const studentId  = (req.user._id ?? req.user.id).toString();
    const isEnrolled = assignment.students.some(s => s.toString() === studentId);
    if (!isEnrolled) {
      return res.status(403).json({ message: 'You are not enrolled in this unit.' });
    }

    // ── 6. Duplicate check ────────────────────────────────────────────────────
    const existing = await Attendance.findOne({
      session: session._id, student: studentId,
    });
    if (existing) {
      return res.status(400).json({
        message: 'Attendance already marked for this session.',
      });
    }

    // ── 7. Biometric checks ───────────────────────────────────────────────────
    if (!biometricPassed) {
      return res.status(400).json({ message: 'Biometric verification failed.' });
    }
    const faceScore = parseFloat(faceConfidence) || 0;
    if (faceScore < 0.75) {
      return res.status(400).json({
        message: `Face verification failed (${(faceScore * 100).toFixed(0)}% confidence). Try better lighting.`,
      });
    }

    // ── 8. Digital signature ──────────────────────────────────────────────────
    const timestamp        = Date.now();
    const digitalSignature = generateSignature(
      studentId, session._id.toString(), timestamp
    );

    // ── 9. Write attendance + issue relay token ───────────────────────────────
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
      // Candlelight fields
      relayToken:  'pending',   // placeholder — replaced below with real token
      relayUsed:   false,
      chainDepth:  relay === true ? (parsed.chainDepth ?? 0) + 1 : 1,
    });

    // Generate the final relay token now that we have the real attendanceId
    const finalRelayToken = generateRelayToken(
      attendance._id.toString(), studentId, session._id.toString()
    );
    await Attendance.findByIdAndUpdate(attendance._id, { relayToken: finalRelayToken });

    // ── 10. Build the relay QR payload for this student ───────────────────────
    // The student's app will encode this string into a QR they can show
    // to classmates. It carries the same session qrToken (session still
    // active) plus their unique single-use relayToken.
    const relayQrPayload = JSON.stringify({
      t:          qrToken,
      a:          assignmentId,
      u:          session.unit.toString(),
      exp:        session.expiresAt.getTime(),
      unitName:   parsed.unitName ?? '',
      unitCode:   parsed.unitCode ?? '',
      relay:      true,
      relayToken: finalRelayToken,
      chainDepth: attendance.chainDepth,
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
      candlelight: {
        relayQrPayload,
        chainDepth: attendance.chainDepth,
      },
    });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/sessions/my-attendance  (Student history)
// ─────────────────────────────────────────────────────────────────────────────
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