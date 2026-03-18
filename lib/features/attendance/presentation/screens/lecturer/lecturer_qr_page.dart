// lib/features/assignments/presentation/lecturer_qr_page.dart
//
// Imported by lecturer_home_page.dart as tab index 1 (QR Code tab)
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
  static const _indigo = Color(0xFF283593);

  List<Map<String, dynamic>> _assignments   = [];
  Map<String, dynamic>?      _selAssignment;
  Map<String, dynamic>?      _activeSession;

  bool    _loadingAssignments = true;
  bool    _creatingSession    = false;
  String? _error;

  // Live stats
  int    _scanned      = 0;
  int    _total        = 0;
  int    _secondsLeft  = 900;
  Timer? _pollTimer;
  Timer? _countdownTimer;

  @override void initState() { super.initState(); _loadAssignments(); }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ── Load this lecturer's assignments ───────────────────────────────────────
  Future<void> _loadAssignments() async {
    setState(() { _loadingAssignments = true; _error = null; });
    final r = await ApiService().get('/assignments');
    if (!mounted) return;
    // Show whatever comes back — even if unit/code fields are missing,
    // display what is available rather than blocking the whole screen
    if (r.success) {
      setState(() {
        _assignments        = List<Map<String, dynamic>>.from(r.data?['assignments'] ?? []);
        _loadingAssignments = false;
      });
    } else {
      setState(() { _error = r.error; _loadingAssignments = false; });
    }
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
    // Backend returns session._id as '_id'
    final sessionId = _activeSession?['_id'] as String?;
    if (sessionId == null) return;
    final r = await ApiService().get('/sessions/$sessionId/stats');
    if (!mounted) return;
    if (r.success) {
      setState(() {
        _scanned = r.data?['scanned']  ?? _scanned;
        _total   = r.data?['total']    ?? _total;
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
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          _endSession(fromServer: true);
        }
      });
    });
  }

  // ── End session ────────────────────────────────────────────────────────────
  Future<void> _endSession({ bool fromServer = false }) async {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    if (!fromServer) {
      // Backend stores session id as '_id'
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

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: _indigo, automaticallyImplyLeading: false,
        title: const Text('Generate QR Code',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        actions: [
          if (_activeSession != null)
            TextButton.icon(
              onPressed: _endSession,
              icon: const Icon(Icons.stop_circle_rounded, color: Colors.white70, size: 18),
              label: const Text('End', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
            ),
          // Refresh button always visible so lecturer can force-reload assignments
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadAssignments,
          ),
        ],
      ),
      body: _loadingAssignments
          ? const Center(child: CircularProgressIndicator(color: _indigo))
          : Padding(
              padding: const EdgeInsets.all(24),
              child: _activeSession != null ? _buildActiveSession() : _buildSetup(),
            ),
    );
  }

  // ── Setup screen ───────────────────────────────────────────────────────────
  Widget _buildSetup() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: _indigo.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.qr_code_rounded, color: _indigo, size: 32),
            const SizedBox(height: 12),
            const Text('Start Attendance Session',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1B1B1B))),
            const SizedBox(height: 4),
            Text('Select one of your assigned units',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.5)),
            const SizedBox(height: 20),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(8)),
                child: Text(_error!, style: const TextStyle(color: Color(0xFFE53935), fontSize: 12)),
              ),
              const SizedBox(height: 14),
            ],

            if (_assignments.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12)),
                child: const Row(children: [
                  Icon(Icons.info_outline_rounded, color: Color(0xFF283593), size: 18),
                  SizedBox(width: 10),
                  Expanded(child: Text(
                    'No units assigned yet.\nAsk your admin to create an assignment for you.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF555555)),
                  )),
                ]),
              )
            else ...[
              // Assignment picker — shows whatever fields exist, gracefully falls back
              ...List.generate(_assignments.length, (i) {
                final a    = _assignments[i];
                // unit may be populated (Map) or null if DB field missing
                final unit = a['unit'] as Map<String, dynamic>?;
                final code = unit?['code'] as String? ?? '—';
                final name = unit?['name'] as String? ?? 'Assignment ${i + 1}';
                final studentCount = (a['students'] as List? ?? []).length;
                final sel  = _selAssignment?['_id'] == a['_id'];

                return GestureDetector(
                  onTap: () => setState(() => _selAssignment = a),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: sel ? _indigo.withOpacity(0.06) : const Color(0xFFF7F7F7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: sel ? _indigo : Colors.transparent, width: 1.5),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: _indigo, borderRadius: BorderRadius.circular(6)),
                        child: Text(code,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis),
                        Text('$studentCount student${studentCount != 1 ? 's' : ''} enrolled',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      ])),
                      if (sel) const Icon(Icons.check_circle_rounded, color: _indigo, size: 20),
                    ]),
                  ),
                );
              }),
              const SizedBox(height: 8),

              // Security badges
              Wrap(spacing: 8, runSpacing: 8, children: [
                _Badge(Icons.timer_outlined, 'Expires in 15 min', const Color(0xFFE8EAF6), _indigo),
                _Badge(Icons.security_rounded, 'Biometric + Face secured', const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
              ]),
              const SizedBox(height: 20),

              // Generate button
              GestureDetector(
                onTap: (_selAssignment == null || _creatingSession) ? null : _generateQr,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200), height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: _selAssignment == null
                        ? [Colors.grey.shade300, Colors.grey.shade400]
                        : [_indigo, const Color(0xFF3949AB)]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: _selAssignment == null ? [] :
                        [BoxShadow(color: _indigo.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 5))],
                  ),
                  child: _creatingSession
                      ? const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                          Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text('Generate QR Code',
                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                        ]),
                ),
              ),
            ],
          ]),
        ),
      ],
    );
  }

  // ── Active session screen ──────────────────────────────────────────────────
  Widget _buildActiveSession() {
    final qrPayload = _activeSession?['qrPayload'] as String? ?? '';
    final unitName  = _activeSession?['unitName']  as String? ?? '';
    final unitCode  = _activeSession?['unitCode']  as String? ?? '';

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: _indigo.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Column(children: [
            // Live badge + counter
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: const [
                  Icon(Icons.circle, color: Color(0xFF2E7D32), size: 8),
                  SizedBox(width: 6),
                  Text('LIVE SESSION', style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF2E7D32), letterSpacing: 1)),
                ]),
              ),
              Text('$_scanned / $_total scanned',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _indigo)),
            ]),
            const SizedBox(height: 20),

            // QR code
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: _indigo, width: 3),
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
              ),
              child: qrPayload.isNotEmpty
                  ? QrImageView(
                      data: qrPayload,
                      version: QrVersions.auto,
                      size: 200,
                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: _indigo),
                      dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square, color: _indigo),
                    )
                  : const SizedBox(width: 200, height: 200,
                      child: Center(child: CircularProgressIndicator(color: _indigo))),
            ),
            const SizedBox(height: 12),

            // Unit info
            if (unitCode.isNotEmpty) Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: _indigo, borderRadius: BorderRadius.circular(8)),
              child: Text(unitCode,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 6),
            if (unitName.isNotEmpty) Text(unitName, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1B1B1B))),
            const SizedBox(height: 6),

            // Countdown
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.timer_outlined, size: 14,
                  color: _secondsLeft < 120 ? const Color(0xFFE53935) : const Color(0xFFF57C00)),
              const SizedBox(width: 4),
              Text('Expires in $_countdownText',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: _secondsLeft < 120 ? const Color(0xFFE53935) : const Color(0xFFF57C00))),
            ]),
            const SizedBox(height: 20),

            // Stats
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(14)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _QrStat('$_scanned',                              'Scanned',   const Color(0xFF2E7D32)),
                Container(width: 1, height: 36, color: Colors.grey.shade200),
                _QrStat('$_total',                               'Expected',  _indigo),
                Container(width: 1, height: 36, color: Colors.grey.shade200),
                _QrStat('${(_total - _scanned).clamp(0, 99999)}','Remaining', const Color(0xFFE53935)),
              ]),
            ),
            const SizedBox(height: 12),

            // Progress
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _total > 0 ? _scanned / _total : 0,
                minHeight: 8,
                backgroundColor: Colors.grey.shade100,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2E7D32)),
              ),
            ),
            const SizedBox(height: 20),

            // End session
            GestureDetector(
              onTap: _endSession,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE53935).withOpacity(0.4)),
                ),
                child: const Center(child: Text('End Session',
                    style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.w700, fontSize: 14))),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _QrStat extends StatelessWidget {
  final String value, label; final Color color;
  const _QrStat(this.value, this.label, this.color);
  @override Widget build(BuildContext context) => Column(children: [
    Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
    Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
  ]);
}

class _Badge extends StatelessWidget {
  final IconData icon; final String label; final Color bg, fg;
  const _Badge(this.icon, this.label, this.bg, this.fg);
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: fg, size: 13),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
    ]),
  );
}