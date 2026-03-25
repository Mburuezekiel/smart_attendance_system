// lib/features/assignments/presentation/lecturer_qr_page.dart
//
// pubspec.yaml: qr_flutter: ^4.1.0

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../../core/services/api_service.dart';

class LecturerQrPage extends StatefulWidget {
  const LecturerQrPage({super.key});
  @override
  State<LecturerQrPage> createState() => _LecturerQrPageState();
}

class _LecturerQrPageState extends State<LecturerQrPage> {
  static const _indigo    = Color(0xFF283593);
  static const _indigoMid = Color(0xFF3949AB);

  List<Map<String, dynamic>> _assignments     = [];
  List<Map<String, dynamic>> _todayAssignments = [];
  Map<String, dynamic>?      _selAssignment;
  Map<String, dynamic>?      _activeSession;

  bool    _loadingAssignments = true;
  bool    _creatingSession    = false;
  String? _error;

  // Live stats
  int    _scanned     = 0;
  int    _total       = 0;
  int    _secondsLeft = 900;
  Timer? _pollTimer;
  Timer? _countdownTimer;

  // Today's day name — used to filter timetable
  static final _dayNames = [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday',
    'Thursday', 'Friday', 'Saturday'
  ];
  String get _todayName => _dayNames[DateTime.now().weekday % 7];

  @override
  void initState() { super.initState(); _loadAll(); }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ── Load assignments + today's timetable ───────────────────────────────────
  Future<void> _loadAll() async {
    setState(() { _loadingAssignments = true; _error = null; });

    final rA = await ApiService().get('/assignments');
    final rT = await ApiService().get('/timetable');

    if (!mounted) return;

    if (!rA.success) {
      setState(() { _error = rA.error; _loadingAssignments = false; });
      return;
    }

    final allAssignments = List<Map<String, dynamic>>.from(
        rA.data?['assignments'] ?? []);
    final allTimetable   = List<Map<String, dynamic>>.from(
        rT.data?['timetable']   ?? []);

    // ── Filter to only assignments that have a timetable slot TODAY ──────────
    // This prevents signing attendance for tomorrow's or yesterday's classes.
    final todaySlotAssignmentIds = allTimetable
        .where((t) => (t['day'] as String? ?? '') == _todayName)
        .map((t) {
          final assignment = t['assignment'];
          if (assignment is Map) return assignment['_id'] as String?;
          return assignment as String?;
        })
        .whereType<String>()
        .toSet();

    final todayAssignments = allAssignments
        .where((a) => todaySlotAssignmentIds.contains(a['_id'] as String?))
        .toList();

    setState(() {
      _assignments      = allAssignments;
      _todayAssignments = todayAssignments;
      _loadingAssignments = false;
    });
  }

  // ── Generate QR / start session ────────────────────────────────────────────
  Future<void> _generateQr() async {
    if (_selAssignment == null) return;
    setState(() { _creatingSession = true; _error = null; });

    final r = await ApiService().createSession(
      assignmentId:    _selAssignment!['_id'] as String,
      durationMinutes: 15,
    );
    if (!mounted) return;
    if (r.success) {
      setState(() {
        _activeSession   = r.data;
        _creatingSession = false;
        _total           = (_selAssignment!['students'] as List? ?? []).length;
        _scanned         = 0;
        _secondsLeft     = 900;
      });
      _startPolling();
      _startCountdown();
    } else {
      setState(() { _error = r.error; _creatingSession = false; });
    }
  }

  // ── Polling ────────────────────────────────────────────────────────────────
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pollStats());
  }

  Future<void> _pollStats() async {
    final sessionId = _activeSession?['_id'] as String?;
    if (sessionId == null) return;
    final r = await ApiService().get('/sessions/$sessionId/stats');
    if (!mounted) return;
    if (r.success) {
      setState(() {
        _scanned = r.data?['scanned'] ?? _scanned;
        _total   = r.data?['total']   ?? _total;
        if (r.data?['isActive'] == false) _endSession(fromServer: true);
      });
    }
  }

  // ── Countdown ──────────────────────────────────────────────────────────────
  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) { _secondsLeft--; }
        else { _endSession(fromServer: true); }
      });
    });
  }

  // ── End session ────────────────────────────────────────────────────────────
  Future<void> _endSession({ bool fromServer = false }) async {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    if (!fromServer) {
      final sessionId = _activeSession?['_id'] as String?;
      if (sessionId != null) await ApiService().delete('/sessions/$sessionId');
    }
    if (mounted) {
      setState(() {
        _activeSession = null;
        _selAssignment = null;
        _scanned       = 0;
        _total         = 0;
        _secondsLeft   = 900;
      });
    }
  }

  String get _countdownText {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft  % 60).toString().padLeft(2, '0');
    return '${m}m ${s}s';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        backgroundColor: _indigo,
        automaticallyImplyLeading: false,
        elevation: 0,
        title: const Text('Attendance Session',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800,
                fontSize: 18)),
        actions: [
          if (_activeSession != null)
            TextButton.icon(
              onPressed: _endSession,
              icon: const Icon(Icons.stop_circle_rounded,
                  color: Colors.white70, size: 18),
              label: const Text('End',
                  style: TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.w700)),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadAll,
          ),
        ],
      ),
      body: _loadingAssignments
          ? const Center(child: CircularProgressIndicator(color: _indigo))
          : _activeSession != null
              ? _buildActiveSession()
              : _buildSetup(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SETUP SCREEN
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSetup() {
    final hasToday = _todayAssignments.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

        // ── Day header ───────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [_indigo, _indigoMid],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(
                color: _indigo.withOpacity(0.3),
                blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.qr_code_2_rounded,
                  color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Start Attendance Session',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                      color: Colors.white)),
              const SizedBox(height: 4),
              Text('Today is $_todayName',
                  style: TextStyle(fontSize: 12,
                      color: Colors.white.withOpacity(0.8))),
            ])),
          ]),
        ),
        const SizedBox(height: 24),

        // ── Error ────────────────────────────────────────────────────────────
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE53935).withOpacity(0.3))),
            child: Row(children: [
              const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFE53935), size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(_error!,
                  style: const TextStyle(
                      color: Color(0xFFE53935), fontSize: 12))),
            ]),
          ),
          const SizedBox(height: 16),
        ],

        // ── Today's units ────────────────────────────────────────────────────
        Row(children: [
          const Icon(Icons.today_rounded, size: 16, color: _indigo),
          const SizedBox(width: 6),
          Text("Today's Classes",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: _indigo.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Text('${_todayAssignments.length} unit${_todayAssignments.length != 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w700, color: _indigo)),
          ),
        ]),
        const SizedBox(height: 12),

        if (!hasToday) ...[
          // No units today
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200)),
            child: Column(children: [
              Icon(Icons.event_busy_rounded, size: 48,
                  color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text('No classes scheduled for $_todayName',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500)),
              const SizedBox(height: 6),
              Text(
                'Attendance sessions can only be started\nfor units scheduled for today.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400,
                    height: 1.5),
              ),
              const SizedBox(height: 16),
              // Show other days if any assignments exist
              if (_assignments.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: _indigo.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 14, color: _indigo),
                    const SizedBox(width: 6),
                    Text('You have ${_assignments.length} unit${_assignments.length != 1 ? 's' : ''} on other days',
                        style: const TextStyle(fontSize: 12,
                            color: _indigo, fontWeight: FontWeight.w600)),
                  ]),
                ),
            ]),
          ),
        ] else ...[
          // Unit cards for today
          ..._todayAssignments.map((a) => _buildUnitCard(a)),
          const SizedBox(height: 16),

          // Security badges
          Row(children: [
            Expanded(child: _InfoBadge(
              icon: Icons.timer_outlined,
              label: 'Expires in 15 min',
              bg: const Color(0xFFE8EAF6),
              fg: _indigo,
            )),
            const SizedBox(width: 10),
            Expanded(child: _InfoBadge(
              icon: Icons.verified_user_rounded,
              label: 'Biometric secured',
              bg: const Color(0xFFE8F5E9),
              fg: const Color(0xFF2E7D32),
            )),
          ]),
          const SizedBox(height: 24),

          // Generate button
          AnimatedOpacity(
            opacity: _selAssignment != null ? 1.0 : 0.5,
            duration: const Duration(milliseconds: 200),
            child: GestureDetector(
              onTap: (_selAssignment == null || _creatingSession)
                  ? null
                  : _generateQr,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _selAssignment == null
                        ? [Colors.grey.shade300, Colors.grey.shade400]
                        : [_indigo, _indigoMid],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _selAssignment == null
                      ? []
                      : [BoxShadow(
                            color: _indigo.withOpacity(0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6))],
                ),
                child: _creatingSession
                    ? const Center(child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.qr_code_2_rounded,
                              color: Colors.white, size: 22),
                          const SizedBox(width: 10),
                          Text(
                            _selAssignment == null
                                ? 'Select a unit above'
                                : 'Generate QR Code',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildUnitCard(Map<String, dynamic> a) {
    final unit     = a['unit'] as Map<String, dynamic>? ?? {};
    final code     = unit['code'] as String? ?? '—';
    final name     = unit['name'] as String? ?? 'Unknown Unit';
    final students = (a['students'] as List? ?? []).length;
    final isSelected = _selAssignment?['_id'] == a['_id'];

    // Pick a colour from the unit code
    const palette = [
      Color(0xFF283593), Color(0xFF2E7D32), Color(0xFF6A1B9A),
      Color(0xFFF57C00), Color(0xFFE53935), Color(0xFF00695C),
    ];
    final cardColor = palette[code.hashCode.abs() % palette.length];

    return GestureDetector(
      onTap: () => setState(() => _selAssignment = a),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: isSelected ? cardColor : Colors.grey.shade200,
              width: isSelected ? 2 : 1.5),
          boxShadow: [BoxShadow(
              color: isSelected
                  ? cardColor.withOpacity(0.15)
                  : Colors.black.withOpacity(0.04),
              blurRadius: isSelected ? 16 : 8,
              offset: const Offset(0, 4))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            // Colour dot / code badge
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                  color: cardColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14)),
              child: Center(child: Text(
                code.split(' ').length > 1
                    ? code.split(' ').last
                    : code,
                style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w900, color: cardColor),
              )),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ── FIX: explicit dark color so text is always visible ──────
              Text(
                name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B1B1B),  // always dark
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: cardColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(code,
                      style: TextStyle(fontSize: 10,
                          fontWeight: FontWeight.w800, color: cardColor)),
                ),
                const SizedBox(width: 8),
                Icon(Icons.people_outline_rounded,
                    size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text('$students student${students != 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 11,
                        color: Colors.grey.shade600)),
              ]),
            ])),
            // Selection indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28, height: 28,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? cardColor : Colors.grey.shade100,
                  border: Border.all(
                      color: isSelected
                          ? cardColor
                          : Colors.grey.shade300,
                      width: 1.5)),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 16)
                  : null,
            ),
          ]),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTIVE SESSION SCREEN
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildActiveSession() {
    final qrPayload = _activeSession?['qrPayload'] as String? ?? '';
    final unitName  = _activeSession?['unitName']  as String? ?? '';
    final unitCode  = _activeSession?['unitCode']  as String? ?? '';

    final progress  = _total > 0 ? _scanned / _total : 0.0;
    final isUrgent  = _secondsLeft < 120;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

        // ── Top status bar ───────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: isUrgent
                    ? [const Color(0xFFE53935), const Color(0xFFEF5350)]
                    : [_indigo, _indigoMid],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            // Live pulse
            Container(
              width: 10, height: 10,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Color(0xFF69F0AE)),
            ),
            const SizedBox(width: 8),
            const Text('LIVE SESSION',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: 1)),
            const Spacer(),
            Icon(Icons.timer_outlined, size: 14,
                color: Colors.white.withOpacity(0.9)),
            const SizedBox(width: 4),
            Text(_countdownText,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                    color: isUrgent
                        ? Colors.white
                        : Colors.white.withOpacity(0.9))),
          ]),
        ),
        const SizedBox(height: 20),

        // ── QR card ──────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(
                color: _indigo.withOpacity(0.1),
                blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Column(children: [
            // Unit info
            if (unitCode.isNotEmpty || unitName.isNotEmpty) ...[
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                      color: _indigo,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(unitCode,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800)),
                ),
              ]),
              const SizedBox(height: 8),
              Text(
                unitName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B1B1B),  // explicit dark color
                ),
              ),
              const SizedBox(height: 20),
            ],

            // QR code with border
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: _indigo.withOpacity(0.3), width: 2),
                borderRadius: BorderRadius.circular(20),
                color: Colors.white,
                boxShadow: [BoxShadow(
                    color: _indigo.withOpacity(0.08),
                    blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: qrPayload.isNotEmpty
                  ? QrImageView(
                      data: qrPayload,
                      version: QrVersions.auto,
                      size: 220,
                      eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square, color: _indigo),
                      dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: _indigo),
                    )
                  : const SizedBox(
                      width: 220, height: 220,
                      child: Center(child: CircularProgressIndicator(
                          color: _indigo))),
            ),
            const SizedBox(height: 8),
            Text('Students scan this with the EduTrack app',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Stats card ───────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: Column(children: [
            // Numbers row
            Row(children: [
              _StatCol('$_scanned',
                  'Scanned', const Color(0xFF2E7D32)),
              _divider(),
              _StatCol('$_total',
                  'Expected', _indigo),
              _divider(),
              _StatCol('${(_total - _scanned).clamp(0, 99999)}',
                  'Remaining', const Color(0xFFE53935)),
            ]),
            const SizedBox(height: 16),
            // Progress bar
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('${(progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800,
                        color: _scanned == _total && _total > 0
                            ? const Color(0xFF2E7D32)
                            : _indigo)),
                const SizedBox(width: 6),
                Text('attendance rate',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: Colors.grey.shade100,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _scanned == _total && _total > 0
                        ? const Color(0xFF2E7D32)
                        : _indigo,
                  ),
                ),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 16),

        // ── End session button ───────────────────────────────────────────────
        GestureDetector(
          onTap: _endSession,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFFE53935).withOpacity(0.5),
                  width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.stop_circle_outlined,
                    color: Color(0xFFE53935), size: 20),
                const SizedBox(width: 8),
                const Text('End Session',
                    style: TextStyle(
                        color: Color(0xFFE53935),
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatCol extends StatelessWidget {
  final String value, label; final Color color;
  const _StatCol(this.value, this.label, this.color);
  @override Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Text(value, style: TextStyle(
          fontSize: 26, fontWeight: FontWeight.w900, color: color)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(
          fontSize: 11, color: Colors.grey.shade500)),
    ]),
  );
}

Widget _divider() => Container(
    width: 1, height: 44,
    color: Colors.grey.shade200,
    margin: const EdgeInsets.symmetric(horizontal: 8));

class _InfoBadge extends StatelessWidget {
  final IconData icon; final String label;
  final Color bg, fg;
  const _InfoBadge({required this.icon, required this.label,
      required this.bg, required this.fg});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(12)),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: fg, size: 14),
      const SizedBox(width: 6),
      Flexible(child: Text(label,
          style: TextStyle(fontSize: 11,
              color: fg, fontWeight: FontWeight.w600))),
    ]),
  );
}