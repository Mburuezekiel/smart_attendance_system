// controllers/sessionController.js
import crypto     from 'crypto';
import Session    from '../models/Session.js';
import Assignment from '../models/Assignment.js';
import Attendance from '../models/Attendance.js';
import Timetable  from '../models/Timetable.js';

const SESSION_DURATION_MS = 15 * 60 * 1000; // 15 minutes
const DEFAULT_RADIUS_M    = 50;              // 50 metre default geofence

// ── Threshold: % of enrolled students that must have signed before
//    absent-marking is triggered when the session ends ────────────────────────
const ABSENT_TRIGGER_THRESHOLD = 0.5; // 50 %

// ── Haversine distance (metres) ───────────────────────────────────────────────
const distanceMeters = (lat1, lon1, lat2, lon2) => {
  const R  = 6371000;
  const φ1 = lat1 * Math.PI / 180;
  const φ2 = lat2 * Math.PI / 180;
  const Δφ = (lat2 - lat1) * Math.PI / 180;
  const Δλ = (lon2 - lon1) * Math.PI / 180;
  const a  = Math.sin(Δφ/2) ** 2 +
             Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ/2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
};

// ── Check whether a coordinate is inside a session's geofence ─────────────────
const isInsideGeofence = (session, latitude, longitude) => {
  const { geofence } = session;
  if (!geofence?.latitude || !geofence?.longitude) return true;
  const dist = distanceMeters(
    latitude, longitude,
    geofence.latitude, geofence.longitude
  );
  return dist <= (geofence.radiusMeters ?? DEFAULT_RADIUS_M);
};

// ── HMAC helpers ──────────────────────────────────────────────────────────────
const secret = () => process.env.SIGNATURE_SECRET || 'change_this_in_production';

const generateSignature = (studentId, sessionId, timestamp) =>
  crypto.createHmac('sha256', secret())
    .update(`${studentId}:${sessionId}:${timestamp}`)
    .digest('hex');

const generateRelayToken = (attendanceId, studentId, sessionId, nonce) =>
  crypto.createHmac('sha256', secret())
    .update(`relay:${attendanceId}:${studentId}:${sessionId}:${nonce}`)
    .digest('hex');

// ─────────────────────────────────────────────────────────────────────────────
// HELPER: "HH:mm" string → total minutes since midnight
// ─────────────────────────────────────────────────────────────────────────────
const toMins = (t = '00:00') => {
  const [h, m] = t.split(':').map(Number);
  return h * 60 + m;
};

// ─────────────────────────────────────────────────────────────────────────────
// HELPER: Given a session, find its timetable slot for today.
//         Returns the Timetable doc or null.
// ─────────────────────────────────────────────────────────────────────────────
const getTodaySlot = async (session) => {
  const days = ['Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];
  const today = days[new Date().getDay()];

  return Timetable.findOne({
    assignment: session.assignment,
    unit:       session.unit,
    day:        today,
    isActive:   true,
  });
};

// ─────────────────────────────────────────────────────────────────────────────
// HELPER: Re-evaluate all present records in a session and mark any that were
//         signed after the timetable end-time as 'late'.
// ─────────────────────────────────────────────────────────────────────────────
const reEvaluateLate = async (session, slot) => {
  if (!slot) return; // no timetable entry → can't determine lateness

  // endTime is stored as "HH:mm". Build a Date for today at that time.
  const [endH, endM] = slot.endTime.split(':').map(Number);
  const classEnd = new Date();
  classEnd.setHours(endH, endM, 0, 0);

  // Any 'present' record whose markedAt is after class end → 'late'
  await Attendance.updateMany(
    {
      session: session._id,
      status:  'present',
      markedAt: { $gt: classEnd },
    },
    { $set: { status: 'late' } }
  );
};

// ─────────────────────────────────────────────────────────────────────────────
// HELPER: Auto-mark absent students when a session ends (or expires).
//         Only fires if ≥ ABSENT_TRIGGER_THRESHOLD of enrolled students signed.
// ─────────────────────────────────────────────────────────────────────────────
const autoMarkAbsent = async (session) => {
  const assignment = await Assignment.findById(session.assignment).select('students');
  if (!assignment) return;

  const enrolled      = assignment.students.map(s => s.toString());
  const totalEnrolled = enrolled.length;
  if (totalEnrolled === 0) return;

  // Students who already have an attendance record (present / late / failed)
  const signed = await Attendance.find({ session: session._id }).select('student');
  const signedIds = new Set(signed.map(a => a.student.toString()));

  const signedCount = signedIds.size;
  const threshold   = Math.ceil(totalEnrolled * ABSENT_TRIGGER_THRESHOLD);

  // Only auto-mark if enough students participated
  if (signedCount < threshold) return;

  // Students with no record at all → absent
  const absentStudents = enrolled.filter(id => !signedIds.has(id));
  if (absentStudents.length === 0) return;

  const now = new Date();
  const absentDocs = absentStudents.map(studentId => ({
    session:           session._id,
    assignment:        session.assignment,
    unit:              session.unit,
    student:           studentId,
    lecturer:          session.lecturer,
    status:            'failed',   // 'failed' = absent in your schema
    markedAt:          now,
    autoMarked:        true,       // flag so you can distinguish auto vs manual
    qrVerified:        false,
    biometricVerified: false,
    faceVerified:      false,
  }));

  // insertMany with ordered:false so one dup-key error doesn't kill the batch
  await Attendance.insertMany(absentDocs, { ordered: false }).catch(() => {});
};

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/sessions  (Lecturer only)
// ─────────────────────────────────────────────────────────────────────────────
export const createSession = async (req, res) => {
  try {
    if (req.user.role !== 'lecturer') {
      return res.status(403).json({ message: 'Lecturer access required.' });
    }

    const { assignmentId, location, geofence } = req.body;
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

    // ── Close any previously open sessions for this assignment ───────────────
    const oldSessions = await Session.find({
      assignment: assignmentId, isActive: true,
    });
    for (const old of oldSessions) {
      await Session.findByIdAndUpdate(old._id, { isActive: false });
      const slot = await getTodaySlot(old);
      await reEvaluateLate(old, slot);
      await autoMarkAbsent(old);
      await Attendance.updateMany(
        { session: old._id },
        { $set: { 'relayTokens.$[].used': true } }
      );
    }

    const qrToken   = Session.generateToken();
    const expiresAt = new Date(Date.now() + SESSION_DURATION_MS);

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
      geofence: geofence
        ? {
            latitude:     geofence.latitude,
            longitude:    geofence.longitude,
            radiusMeters: geofence.radiusMeters ?? DEFAULT_RADIUS_M,
          }
        : { latitude: null, longitude: null, radiusMeters: DEFAULT_RADIUS_M },
    });

    res.status(201).json({
      _id:        session._id,
      sessionId:  session._id,
      message:    'Session started.',
      qrPayload,
      expiresAt,
      unitName:   assignment.unit.name,
      unitCode:   assignment.unit.code,
      geofence:   session.geofence,
    });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// DELETE /api/sessions/:id  (Lecturer ends session manually)
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

    // Revoke all relay tokens
    await Attendance.updateMany(
      { session: req.params.id },
      { $set: { 'relayTokens.$[].used': true } }
    );

    // Re-evaluate late records then auto-mark absentees
    const slot = await getTodaySlot(session);
    await reEvaluateLate(session, slot);
    await autoMarkAbsent(session);

    const absentCount = await Attendance.countDocuments({
      session: session._id, status: 'failed', autoMarked: true,
    });

    res.json({
      message:      'Session ended. All relay tokens revoked.',
      absentMarked: absentCount,
    });
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
// ─────────────────────────────────────────────────────────────────────────────
export const verifyAndMarkAttendance = async (req, res) => {
  try {
    if (req.user.role !== 'student') {
      return res.status(403).json({ message: 'Student access required.' });
    }

    const { qrPayload, biometricPassed, faceConfidence, latitude, longitude } = req.body;
    if (!qrPayload) {
      return res.status(400).json({ message: 'qrPayload is required.' });
    }

    // ── 1. Parse QR ───────────────────────────────────────────────────────────
    let parsed;
    try { parsed = JSON.parse(qrPayload); }
    catch { return res.status(400).json({ message: 'Invalid QR code.' }); }

    const { t: qrToken, a: assignmentId, exp, relay, relayToken } = parsed;
    if (!qrToken || !assignmentId) {
      return res.status(400).json({ message: 'Malformed QR code.' });
    }

    // ── 2. Expiry ─────────────────────────────────────────────────────────────
    if (Date.now() > exp) {
      return res.status(400).json({
        message: 'QR code has expired. Ask your lecturer or a classmate for a new one.',
      });
    }

    // ── 3. Active session ─────────────────────────────────────────────────────
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

    // ── 4. Geofence ───────────────────────────────────────────────────────────
    const hasGeofence = session.geofence?.latitude != null &&
                        session.geofence?.longitude != null;
    if (hasGeofence) {
      if (latitude == null || longitude == null) {
        return res.status(400).json({
          message: 'Location is required for this session. Please enable GPS.',
        });
      }
      if (!isInsideGeofence(session, latitude, longitude)) {
        return res.status(403).json({
          message: 'You must be inside the classroom to mark attendance.',
        });
      }
    }

    // ── 5. Relay chain validation ─────────────────────────────────────────────
    if (relay === true) {
      if (!relayToken) {
        return res.status(400).json({ message: 'Relay QR is missing its token.' });
      }
      const relaySource = await Attendance.findOne({
        session:              session._id,
        'relayTokens.token':  relayToken,
        'relayTokens.used':   false,
      });
      if (!relaySource) {
        return res.status(400).json({
          message: 'This relay QR has already been used or the session ended. Ask a different classmate.',
        });
      }
      await Attendance.updateOne(
        { _id: relaySource._id, 'relayTokens.token': relayToken },
        { $set: { 'relayTokens.$.used': true } }
      );
    }

    // ── 6. Enrolment check ────────────────────────────────────────────────────
    const assignment = await Assignment.findById(assignmentId);
    if (!assignment) {
      return res.status(404).json({ message: 'Assignment not found.' });
    }
    const studentId  = (req.user._id ?? req.user.id).toString();
    const isEnrolled = assignment.students.some(s => s.toString() === studentId);
    if (!isEnrolled) {
      return res.status(403).json({ message: 'You are not enrolled in this unit.' });
    }

    // ── 7. Duplicate check ────────────────────────────────────────────────────
    const existing = await Attendance.findOne({
      session: session._id, student: studentId,
    });
    if (existing) {
      return res.status(400).json({
        message: 'Attendance already marked for this session.',
      });
    }

    // ── 8. Biometric + face ───────────────────────────────────────────────────
    if (!biometricPassed) {
      return res.status(400).json({ message: 'Biometric verification failed.' });
    }
    const faceScore = parseFloat(faceConfidence) || 0;
    if (faceScore < 0.75) {
      return res.status(400).json({
        message: `Face verification failed (${(faceScore * 100).toFixed(0)}%). Try better lighting.`,
      });
    }

    // ── 9. Late detection ─────────────────────────────────────────────────────
    // Compare current wall-clock time against the timetable end-time for today.
    // If attendance is signed AFTER the class end-time → mark as 'late'.
    const slot = await getTodaySlot(session);
    let status = 'present';

    if (slot?.endTime) {
      const [endH, endM] = slot.endTime.split(':').map(Number);
      const classEnd = new Date();
      classEnd.setHours(endH, endM, 0, 0);
      if (new Date() > classEnd) {
        status = 'late';
      }
    }

    // ── 10. Digital signature ─────────────────────────────────────────────────
    const timestamp        = Date.now();
    const digitalSignature = generateSignature(
      studentId, session._id.toString(), timestamp
    );

    // ── 11. Write attendance record ───────────────────────────────────────────
    const nonce           = crypto.randomBytes(8).toString('hex');
    const firstRelayToken = generateRelayToken(
      `pre_${studentId}`, studentId, session._id.toString(), nonce
    );

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
      status,                          // 'present' or 'late'
      location:          { latitude, longitude },
      chainDepth:        relay === true ? (parsed.chainDepth ?? 0) + 1 : 1,
      relayTokens: [{ token: firstRelayToken, used: false, issuedAt: new Date() }],
    });

    // Regenerate relay token with real attendanceId
    const finalRelayToken = generateRelayToken(
      attendance._id.toString(), studentId, session._id.toString(), nonce
    );
    await Attendance.updateOne(
      { _id: attendance._id, 'relayTokens.token': firstRelayToken },
      { $set: { 'relayTokens.$.token': finalRelayToken } }
    );

    // ── 12. Build first relay QR payload ──────────────────────────────────────
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
      status,                          // tells the app if they were marked late
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
        chainDepth:     attendance.chainDepth,
        canRequestMore: true,
      },
    });
  } catch (err) {
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/sessions/request-relay
// ─────────────────────────────────────────────────────────────────────────────
export const requestRelayToken = async (req, res) => {
  try {
    if (req.user.role !== 'student') {
      return res.status(403).json({ message: 'Student access required.' });
    }

    const { sessionId, latitude, longitude } = req.body;
    if (!sessionId || latitude == null || longitude == null) {
      return res.status(400).json({
        message: 'sessionId, latitude and longitude are required.',
      });
    }

    const studentId = (req.user._id ?? req.user.id).toString();

    const session = await Session.findOne({ _id: sessionId, isActive: true });
    if (!session) {
      return res.status(400).json({ message: 'Session is no longer active.' });
    }

    const hasGeofence = session.geofence?.latitude != null &&
                        session.geofence?.longitude != null;
    if (hasGeofence && !isInsideGeofence(session, latitude, longitude)) {
      return res.status(403).json({
        message: 'You must be inside the classroom to generate a relay QR.',
      });
    }

    const attendance = await Attendance.findOne({
      session: sessionId, student: studentId,
    });
    if (!attendance) {
      return res.status(403).json({
        message: 'You have not signed attendance for this session yet.',
      });
    }

    const nonce    = crypto.randomBytes(8).toString('hex');
    const newToken = generateRelayToken(
      attendance._id.toString(), studentId, sessionId, nonce
    );

    await Attendance.updateOne(
      { _id: attendance._id },
      { $push: { relayTokens: { token: newToken, used: false, issuedAt: new Date() } } }
    );

    const session2 = await Session.findById(sessionId);
    const relayQrPayload = JSON.stringify({
      t:          session2.qrToken,
      a:          attendance.assignment.toString(),
      u:          attendance.unit.toString(),
      exp:        session2.expiresAt.getTime(),
      unitName:   req.body.unitName ?? '',
      unitCode:   req.body.unitCode ?? '',
      relay:      true,
      relayToken: newToken,
      chainDepth: attendance.chainDepth,
    });

    res.status(201).json({ message: 'New relay token issued.', relayQrPayload });
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