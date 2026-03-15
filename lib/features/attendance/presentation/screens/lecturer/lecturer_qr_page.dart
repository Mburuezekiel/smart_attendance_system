// lib/features/assignments/presentation/lecturer_qr_page.dart
//
// Drop-in replacement for the existing _GenerateQrPage inside lecturer_home_page.dart
// Import this file and use LecturerQrPage() instead of _GenerateQrPage()

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';           // add qr_flutter: ^4.1.0 to pubspec.yaml
import '../../../../../../../core/services/api_service.dart';

class LecturerQrPage extends StatefulWidget {
  const LecturerQrPage({super.key});
  @override
  State<LecturerQrPage> createState() => _LecturerQrPageState();
}

class _LecturerQrPageState extends State<LecturerQrPage> {
  static const _indigo = Color(0xFF283593);

  List<Map<String, dynamic>> _assignments = [];
  bool _loadingAssignments = true;
  String? _selectedAssignmentId;
  Map<String, dynamic>? _activeSession;

  // Live session state
  int  _scanned   = 0;
  int  _expected  = 0;
  bool _isActive  = false;
  Timer? _pollTimer;
  Timer? _countdownTimer;
  int  _secondsLeft = 900; // 15 min

  @override
  void initState() { super.initState(); _loadAssignments(); }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAssignments() async {
    setState(() => _loadingAssignments = true);
    final result = await ApiService().get('/assignments');
    if (!mounted) return;
    setState(() {
      _assignments = List<Map<String,dynamic>>.from(result.data?['assignments'] ?? []);
      _loadingAssignments = false;
    });
  }

  Future<void> _startSession() async {
    if (_selectedAssignmentId == null) return;
    final result = await ApiService().post('/sessions', {
      'assignmentId': _selectedAssignmentId,
    });
    if (!mounted) return;
    if (result.success) {
      setState(() {
        _activeSession = result.data;
        _isActive      = true;
        _scanned       = 0;
        _secondsLeft   = 900;
      });
      _startPolling();
      _startCountdown();
    } else {
      _showSnack(result.error ?? 'Failed to start session', isError: true);
    }
  }

  Future<void> _endSession() async {
    final sessionId = _activeSession?['sessionId'] as String?;
    if (sessionId == null) return;
    await ApiService().delete('/sessions/$sessionId');
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    if (mounted) {
      setState(() {
        _activeSession = null;
        _isActive = false;
        _selectedAssignmentId = null;
      });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchStats());
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          _countdownTimer?.cancel();
          _pollTimer?.cancel();
          _activeSession = null;
          _isActive = false;
        }
      });
    });
  }

  Future<void> _fetchStats() async {
    final sessionId = _activeSession?['sessionId'] as String?;
    if (sessionId == null) return;
    final result = await ApiService().get('/sessions/$sessionId/stats');
    if (!mounted) return;
    if (result.success) {
      setState(() {
        _scanned  = result.data?['scanned']  ?? 0;
        _expected = result.data?['expected'] ?? 0;
        _isActive = result.data?['isActive'] ?? false;
      });
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : _indigo,
    ));
  }

  String get _countdownText {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft  % 60).toString().padLeft(2, '0');
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: _indigo, automaticallyImplyLeading: false,
        title: const Text('Generate QR Code',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
      body: _loadingAssignments
          ? const Center(child: CircularProgressIndicator(color: _indigo))
          : Padding(
              padding: const EdgeInsets.all(24),
              child: _isActive ? _buildActiveSession() : _buildSetup(),
            ),
    );
  }

  // ── Setup ──────────────────────────────────────────────────────────────────
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
            Text('Select one of your assigned units to generate\na secure QR code for students to scan',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.5)),
            const SizedBox(height: 20),

            if (_assignments.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.info_outline, color: Color(0xFFF57C00), size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text('No units assigned yet.\nContact admin to get assigned.',
                      style: const TextStyle(fontSize: 12, color: Color(0xFFF57C00)))),
                ]),
              )
            else
              DropdownButtonFormField<String>(
                value: _selectedAssignmentId,
                hint: const Text('Select your unit…', style: TextStyle(fontSize: 13)),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _indigo, width: 2)),
                  filled: true, fillColor: const Color(0xFFF7F7F7),
                ),
                items: _assignments.map((a) {
                  final unit = a['unit'] as Map<String,dynamic>? ?? {};
                  return DropdownMenuItem(
                    value: a['_id'] as String?,
                    child: Text('${unit['code']} — ${unit['name']}',
                        style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedAssignmentId = v),
              ),

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFFE8EAF6), borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.timer_outlined, color: _indigo, size: 14),
                SizedBox(width: 6),
                Text('QR code expires in 15 minutes',
                    style: TextStyle(fontSize: 11, color: _indigo, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.security_rounded, color: Color(0xFF2E7D32), size: 14),
                SizedBox(width: 6),
                Text('Secured by biometric + face verification',
                    style: TextStyle(fontSize: 11, color: Color(0xFF2E7D32), fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _selectedAssignmentId == null ? null : _startSession,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200), height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: _selectedAssignmentId == null
                      ? [Colors.grey.shade300, Colors.grey.shade400]
                      : [_indigo, const Color(0xFF3949AB)]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _selectedAssignmentId == null ? [] :
                  [BoxShadow(color: _indigo.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 5))],
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                  Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Generate QR Code',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  // ── Active session ─────────────────────────────────────────────────────────
  Widget _buildActiveSession() {
    final qrPayload = _activeSession?['qrPayload'] as String? ?? '';
    final unitName  = _activeSession?['unitName']  as String? ?? '';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                        fontSize: 10, fontWeight: FontWeight.w800,
                        color: Color(0xFF2E7D32), letterSpacing: 1)),
                  ]),
                ),
                Text('$_scanned scanned',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _indigo)),
              ]),
              const SizedBox(height: 16),

              // Real QR code from qr_flutter
              Container(
                padding: const EdgeInsets.all(8),
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

              Text(unitName, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1B1B1B))),
              const SizedBox(height: 4),

              // Countdown
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.timer_outlined, size: 14,
                    color: _secondsLeft < 120 ? Colors.red : const Color(0xFFF57C00)),
                const SizedBox(width: 4),
                Text('Expires in $_countdownText',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: _secondsLeft < 120 ? Colors.red : const Color(0xFFF57C00))),
              ]),
              const SizedBox(height: 20),

              // Live stats
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(14)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _QrStat('$_scanned',                       'Scanned',   const Color(0xFF2E7D32)),
                  Container(width: 1, height: 36, color: Colors.grey.shade200),
                  _QrStat('$_expected',                      'Expected',  _indigo),
                  Container(width: 1, height: 36, color: Colors.grey.shade200),
                  _QrStat('${(_expected - _scanned).clamp(0, 9999)}', 'Remaining', const Color(0xFFE53935)),
                ]),
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
        ],
      ),
    );
  }
}

class _QrStat extends StatelessWidget {
  final String value, label; final Color color;
  const _QrStat(this.value, this.label, this.color);
  @override Widget build(BuildContext context) => Column(children: [
    Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
    Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
  ]);
}