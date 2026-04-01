// controllers/timetableImportController.js
//
// POST /api/timetable/import
//
// Accepts a multipart upload (field "file", PDF or DOCX) plus optional query
// filters:  unitCodes  (comma-separated)  |  year  |  course
//
// Flow:
//   1. Extract raw text from the uploaded file (pdf-parse / mammoth)
//   2. Send text + filters to Claude claude-sonnet-4-20250514 → structured JSON slots
//   3. Validate each slot against the lecturer's assignments
//   4. Return a "preview" array the client can confirm before committing
//
// POST /api/timetable/import/confirm
//   Body: { slots: [...] }  (the confirmed preview)
//   Bulk-inserts into Timetable, skips duplicates gracefully.

import fs            from 'fs';
import path          from 'path';
import Anthropic     from '@anthropic-ai/sdk';
import pdfParse      from 'pdf-parse/lib/pdf-parse.js';
import mammoth       from 'mammoth';
import multer        from 'multer';

import Timetable     from '../models/Timetable.js';
import Assignment    from '../models/Assignment.js';
import Unit          from '../models/Unit.js';

// ─── Multer (memory storage — no disk write needed) ────────────────────────

const upload = multer({
  storage: multer.memoryStorage(),
  limits:  { fileSize: 10 * 1024 * 1024 },          // 10 MB cap
  fileFilter: (_req, file, cb) => {
    const ok = [
      'application/pdf',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    ].includes(file.mimetype);
    cb(ok ? null : new Error('Only PDF and Word documents are supported.'), ok);
  },
});

export const importUploadMiddleware = upload.single('file');

// ─── Helpers ──────────────────────────────────────────────────────────────────

const VALID_DAYS = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'];

/** Extract plain text from PDF or DOCX buffer */
async function extractText(buffer, mimetype) {
  if (mimetype === 'application/pdf') {
    const result = await pdfParse(buffer);
    return result.text;
  }
  // DOCX / DOC
  const result = await mammoth.extractRawText({ buffer });
  return result.value;
}

/** Ask Claude to parse the raw timetable text into structured JSON */
async function parseWithClaude(rawText, filters = {}) {
  const client = new Anthropic();           // reads ANTHROPIC_API_KEY from env

  const filterHints = [
    filters.unitCodes ? `Focus only on unit codes: ${filters.unitCodes}` : '',
    filters.year      ? `Filter for year/level: ${filters.year}`          : '',
    filters.course    ? `Filter for course/programme: ${filters.course}`  : '',
  ].filter(Boolean).join('\n');

  const systemPrompt = `You are an expert academic timetable parser.
Extract class schedule entries from the raw text and return ONLY a JSON array.
Each element must have exactly these keys:
  unitCode   – string  (e.g. "CS301")
  unitName   – string  (full name if available, else same as unitCode)
  day        – string  (one of: Monday Tuesday Wednesday Thursday Friday Saturday)
  startTime  – string  (24-h "HH:MM", e.g. "08:00")
  endTime    – string  (24-h "HH:MM", e.g. "10:00")
  room       – string  (venue/room, empty string if absent)
  notes      – string  (any extra info, empty string if absent)

Rules:
- If a time range spans multiple weeks or is unclear, skip it.
- Normalise all times to 24-hour HH:MM format.
- Output ONLY the JSON array — no markdown, no explanation.
${filterHints ? '\nAdditional instructions:\n' + filterHints : ''}`;

  const msg = await client.messages.create({
    model:      'claude-sonnet-4-20250514',
    max_tokens: 4096,
    system:     systemPrompt,
    messages:   [{ role: 'user', content: rawText.slice(0, 60_000) }],
  });

  const text = msg.content.find(b => b.type === 'text')?.text ?? '[]';
  // Strip accidental markdown fences
  const clean = text.replace(/```json|```/gi, '').trim();
  return JSON.parse(clean);
}

/** Normalise "8:00" → "08:00" */
const padTime = (t = '') => {
  const [h, m] = t.split(':');
  return `${String(h).padLeft ? String(h).padLeft(2,'0') : h.padStart(2,'0')}:${(m ?? '00').padStart(2,'0')}`;
};

const getUserId = u => u._id ?? u.id;

// ─── STEP 1: Upload + preview ─────────────────────────────────────────────────

/**
 * POST /api/timetable/import
 * multipart: field "file"
 * query: unitCodes, year, course   (all optional)
 */
export const importTimetablePreview = async (req, res) => {
  try {
    if (req.user.role !== 'lecturer') {
      return res.status(403).json({ message: 'Lecturer access required.' });
    }
    if (!req.file) {
      return res.status(400).json({ message: 'No file uploaded.' });
    }

    const lecturerId = getUserId(req.user);

    // 1. Text extraction
    let rawText;
    try {
      rawText = await extractText(req.file.buffer, req.file.mimetype);
    } catch {
      return res.status(422).json({ message: 'Could not extract text from file.' });
    }

    if (!rawText?.trim()) {
      return res.status(422).json({ message: 'File appears to be empty or image-only.' });
    }

    // 2. Claude parse
    let parsed;
    try {
      parsed = await parseWithClaude(rawText, {
        unitCodes: req.query.unitCodes,
        year:      req.query.year,
        course:    req.query.course,
      });
    } catch (e) {
      return res.status(502).json({ message: 'AI parsing failed.', detail: e.message });
    }

    if (!Array.isArray(parsed) || parsed.length === 0) {
      return res.status(200).json({ preview: [], message: 'No matching entries found.' });
    }

    // 3. Fetch lecturer's assignments (to match unit codes)
    const assignments = await Assignment.find({ lecturer: lecturerId, isActive: true })
      .populate('unit', 'name code')
      .lean();

    const asgnByCode = {};
    for (const a of assignments) {
      const code = a.unit?.code?.toUpperCase();
      if (code) asgnByCode[code] = a;
    }

    // 4. Build preview with match status
    const preview = parsed.map((slot, idx) => {
      const code  = (slot.unitCode ?? '').toUpperCase();
      const asgn  = asgnByCode[code];
      const day   = slot.day ? slot.day.charAt(0).toUpperCase() + slot.day.slice(1).toLowerCase() : '';
      const valid = VALID_DAYS.includes(day);

      return {
        _previewId:   idx,
        unitCode:     code,
        unitName:     slot.unitName ?? code,
        day:          valid ? day : slot.day,
        startTime:    padTime(slot.startTime),
        endTime:      padTime(slot.endTime),
        room:         slot.room  ?? '',
        notes:        slot.notes ?? '',
        // enrichment
        assignmentId: asgn?._id  ?? null,
        unitId:       asgn?.unit?._id ?? null,
        matched:      !!asgn,          // false = no assignment found for this code
        dayValid:     valid,
        warning:      !asgn
          ? `No assignment found for unit code "${code}"`
          : (!valid ? `Unrecognised day "${slot.day}"` : null),
      };
    });

    return res.json({
      preview,
      totalParsed:  parsed.length,
      totalMatched: preview.filter(p => p.matched && p.dayValid).length,
    });

  } catch (err) {
    console.error('[importTimetablePreview]', err);
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};

// ─── STEP 2: Confirm & bulk-insert ───────────────────────────────────────────

/**
 * POST /api/timetable/import/confirm
 * body: { slots: [{ assignmentId, unitId, day, startTime, endTime, room, notes }] }
 */
export const confirmTimetableImport = async (req, res) => {
  try {
    if (req.user.role !== 'lecturer') {
      return res.status(403).json({ message: 'Lecturer access required.' });
    }

    const lecturerId = getUserId(req.user);
    const { slots }  = req.body;

    if (!Array.isArray(slots) || slots.length === 0) {
      return res.status(400).json({ message: 'No slots provided.' });
    }

    const results = { created: 0, skipped: 0, errors: [] };

    for (const slot of slots) {
      const { assignmentId, unitId, day, startTime, endTime, room, notes } = slot;

      if (!assignmentId || !unitId || !day || !startTime || !endTime) {
        results.errors.push({ slot, reason: 'Missing required fields.' });
        results.skipped++;
        continue;
      }

      if (!VALID_DAYS.includes(day)) {
        results.errors.push({ slot, reason: `Invalid day: ${day}` });
        results.skipped++;
        continue;
      }

      try {
        await Timetable.create({
          assignment: assignmentId,
          unit:       unitId,
          lecturer:   lecturerId,
          day, startTime, endTime,
          room:  room  ?? '',
          notes: notes ?? '',
        });
        results.created++;
      } catch (e) {
        if (e.code === 11000) {
          results.skipped++;          // duplicate — already exists
        } else {
          results.errors.push({ slot, reason: e.message });
          results.skipped++;
        }
      }
    }

    res.status(201).json({
      message: `Import complete. ${results.created} created, ${results.skipped} skipped.`,
      ...results,
    });

  } catch (err) {
    console.error('[confirmTimetableImport]', err);
    res.status(500).json({ message: 'Server error', error: err.message });
  }
};