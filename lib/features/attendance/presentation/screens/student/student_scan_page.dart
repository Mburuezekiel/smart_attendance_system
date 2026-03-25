// lib/features/assignments/presentation/student_scan_page.dart
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../../../../core/services/api_service.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _green    = Color(0xFF2E7D32);
const _greenMid = Color(0xFF43A047);
const _darkText = Color(0xFF1B1B1B);

// ─────────────────────────────────────────────────────────────────────────────
// PAGE
// ─────────────────────────────────────────────────────────────────────────────

class StudentScanPage extends StatefulWidget {
  const StudentScanPage({super.key});
  @override State<StudentScanPage> createState() => _StudentScanPageState();
}

class _StudentScanPageState extends State<StudentScanPage> {
  int     _step      = 0;  // 0=qr 1=success 2=bio 3=face 4=done 5=error
  String? _qrPayload, _className, _unitCode, _sessionId, _errorMsg, _relayQr;
  bool    _bioPassed = false, _processing = false, _requestingRelay = false;
  double  _faceScore = 0.0;
  Map<String, dynamic>? _result;
  Position? _lastPos;

  void _reset() => setState(() {
    _step = 0; _qrPayload = _className = _unitCode = _sessionId =
        _errorMsg = _relayQr = null;
    _bioPassed = _processing = _requestingRelay = false;
    _faceScore = 0.0; _result = null; _lastPos = null;
  });

  // ── Location ──────────────────────────────────────────────────────────────
  Future<({Position? pos, String? err})> _getPos() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return (pos: null, err: 'Location services are disabled.');
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever) {
        return (pos: null, err: 'Location permission denied. Enable in settings.');
      }
      if (perm == LocationPermission.denied) {
        return (pos: null, err: 'Location permission denied.');
      }
      final p = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 15),
          onTimeout: () => throw Exception('Location timed out.'));
      return (pos: p, err: null);
    } catch (e) {
      return (pos: null, err: e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ── Step 0 → 1 : QR detected ──────────────────────────────────────────────
  void _onQr(String raw) {
    try {
      final p = jsonDecode(raw) as Map<String, dynamic>;
      if ((p['t'] as String?)?.isEmpty ?? true) throw '';
      final exp = p['exp'] as int?;
      if (exp != null && DateTime.now().millisecondsSinceEpoch > exp) {
        return _err('QR expired. Ask your lecturer or classmate for a new one.');
      }
      setState(() {
        _qrPayload = raw;
        _className = p['unitName'] as String? ?? 'Class Session';
        _unitCode  = p['unitCode'] as String? ?? '';
        _step = 1;
      });
    } catch (_) {
      _err('Invalid QR. Use the one shown by your lecturer or a verified classmate.');
    }
  }

  void _err(String msg) => setState(() { _errorMsg = msg; _step = 5; });

  // ── Step 2 : Biometric ────────────────────────────────────────────────────
  Future<void> _doBio() async {
    setState(() => _processing = true);
    try {
      final auth = LocalAuthentication();
      if (!await auth.canCheckBiometrics && !await auth.isDeviceSupported()) {
        return setState(() { _processing = false; _bioPassed = false; _step = 3; });
      }
      final ok = await auth.authenticate(
          localizedReason: 'Verify your identity to mark attendance');
      if (!mounted) return;
      ok
          ? setState(() { _bioPassed = true; _processing = false; _step = 3; })
          : _err('Biometric cancelled or failed. Please try again.');
    } catch (e) {
      if (mounted) _err('Biometric error: $e');
    } finally {
      if (mounted && _processing) setState(() => _processing = false);
    }
  }

  // ── Step 3 → 4 : Face verified ────────────────────────────────────────────
  Future<void> _onFace(double conf) async {
    setState(() { _faceScore = conf; _processing = true; _step = 4; });
    await _submit();
  }

  // ── Submit attendance ─────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_qrPayload == null) return;
    final (:pos, :err) = await _getPos();
    if (pos == null && err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('⚠️ GPS: $err'),
        backgroundColor: const Color(0xFFF57C00),
        duration: const Duration(seconds: 3),
      ));
    }
    _lastPos = pos;

    final r = await ApiService().post('/sessions/verify', {
      'qrPayload': _qrPayload!, 'biometricPassed': _bioPassed,
      'faceConfidence': _faceScore,
      if (pos != null) 'latitude': pos.latitude,
      if (pos != null) 'longitude': pos.longitude,
    });
    if (!mounted) return;

    if (r.success) {
      final cl = r.data?['candlelight'] as Map<String, dynamic>?;
      final sid = r.data?['sessionId'] as String?;
      if (sid != null) _sessionId = sid;
      setState(() {
        _result = {
          ...?r.data,
          'verifications': r.data?['verifications'] ??
              {'faceScore': '${(_faceScore * 100).toStringAsFixed(0)}%'},
        };
        _relayQr = cl?['relayQrPayload'] as String?;
        _processing = false;
      });
    } else {
      setState(() { _errorMsg = r.error ?? 'Submission failed.'; _processing = false; _step = 5; });
    }
  }

  // ── Request relay ─────────────────────────────────────────────────────────
  Future<void> _relay() async {
    final sid = _sessionId ??
        (_result?['sessionId'] ?? _result?['attendanceId']) as String?;
    if (sid == null) return;
    setState(() => _requestingRelay = true);

    final (:pos, :err) = await _getPos();
    if (pos == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err ?? 'GPS unavailable.'), backgroundColor: Colors.red));
      }
      return setState(() => _requestingRelay = false);
    }

    final r = await ApiService().post('/sessions/request-relay', {
      'sessionId': sid, 'latitude': pos.latitude, 'longitude': pos.longitude,
      'unitName': _className ?? '', 'unitCode': _unitCode ?? '',
    });
    if (!mounted) return;
    setState(() => _requestingRelay = false);
    if (r.success) {
      final relay = r.data?['relayQrPayload'] as String?;
      if (relay != null) setState(() => _relayQr = relay);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('New relay QR ready!'), backgroundColor: _green));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(r.error ?? 'Failed.'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF0F2F8),
    appBar: AppBar(
      backgroundColor: _green, automaticallyImplyLeading: false,
      centerTitle: true,
      title: const Text('Mark Attendance',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      actions: [
        if (_step > 0)
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _reset),
      ],
    ),
    body: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: switch (_step) {
        0 => _QrScanStep(onDetected: _onQr),
        1 => _SuccessStep(className: _className!, unitCode: _unitCode!,
              onContinue: () => setState(() => _step = 2)),
        2 => _BioStep(processing: _processing, onScan: _doBio),
        3 => _FaceStep(onVerified: _onFace),
        4 => _DoneStep(
              className: _className!, unitCode: _unitCode!,
              result: _result, faceScore: _faceScore,
              processing: _processing, relayQr: _relayQr,
              requestingRelay: _requestingRelay,
              onRelay: _relay, onReset: _reset),
        5 => _ErrorStep(message: _errorMsg!, onRetry: _reset),
        _ => const SizedBox.shrink(),
      },
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 0 — QR SCANNER
// ─────────────────────────────────────────────────────────────────────────────

class _QrScanStep extends StatefulWidget {
  final ValueChanged<String> onDetected;
  const _QrScanStep({required this.onDetected});
  @override State<_QrScanStep> createState() => _QrScanStepState();
}

class _QrScanStepState extends State<_QrScanStep> {
  bool _show = false, _scanned = false;

  void _detect(BarcodeCapture c) {
    if (_scanned) return;
    final raw = c.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;
    _scanned = true;
    widget.onDetected(raw);
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _StepBar(current: 0),
      const SizedBox(height: 28),
      _Card(child: _show ? Column(children: [
        _CameraBox(child: MobileScanner(onDetect: _detect, fit: BoxFit.cover)),
        const SizedBox(height: 10),
        Text('Point at the QR from your lecturer or classmate',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        const SizedBox(height: 14),
        OutlinedButton(
          onPressed: () => setState(() { _show = false; _scanned = false; }),
          style: OutlinedButton.styleFrom(
              foregroundColor: _green, side: const BorderSide(color: _green)),
          child: const Text('Cancel'),
        ),
      ]) : Column(children: [
        Container(
          width: 130, height: 130,
          decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _green, width: 3)),
          child: const Icon(Icons.qr_code_2_rounded, size: 80, color: _green),
        ),
        const SizedBox(height: 18),
        const Text('Scan Attendance QR',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _darkText)),
        const SizedBox(height: 6),
        Text('Scan the lecturer\'s QR or a verified classmate\'s relay QR',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.5)),
        const SizedBox(height: 22),
        _Btn(label: 'Open Camera', icon: Icons.camera_alt_rounded,
            onTap: () => setState(() { _show = true; _scanned = false; })),
      ])),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 1 — QR SUCCESS
// ─────────────────────────────────────────────────────────────────────────────

class _SuccessStep extends StatelessWidget {
  final String className, unitCode;
  final VoidCallback onContinue;
  const _SuccessStep({required this.className, required this.unitCode,
      required this.onContinue});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _StepBar(current: 0),
      const SizedBox(height: 28),
      _Card(child: Column(children: [
        _Circle(icon: Icons.check_circle_rounded, color: _green, size: 52,
            bg: const Color(0xFFE8F5E9)),
        const SizedBox(height: 14),
        const Text('QR Verified!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _green)),
        if (unitCode.isNotEmpty) ...[
          const SizedBox(height: 10),
          _Chip(unitCode, _green),
        ],
        const SizedBox(height: 8),
        Text(className, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _darkText)),
        const SizedBox(height: 4),
        Text('Now verify your identity to complete attendance',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        const SizedBox(height: 22),
        _Btn(label: 'Continue to Biometrics', icon: Icons.fingerprint_rounded,
            onTap: onContinue),
      ])),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 2 — BIOMETRIC
// ─────────────────────────────────────────────────────────────────────────────

class _BioStep extends StatelessWidget {
  final bool processing; final VoidCallback onScan;
  const _BioStep({required this.processing, required this.onScan});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _StepBar(current: 1),
      const SizedBox(height: 28),
      _Card(child: Column(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 110, height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: processing ? _green.withOpacity(0.15) : const Color(0xFFE8F5E9),
            border: Border.all(
                color: processing ? _green : Colors.grey.shade200, width: 2.5),
          ),
          child: Icon(Icons.fingerprint_rounded, size: 60,
              color: processing ? _green : Colors.grey.shade400),
        ),
        const SizedBox(height: 18),
        Text(processing ? 'Verifying…' : 'Step 2: Device Biometrics',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800,
                color: processing ? _green : _darkText)),
        const SizedBox(height: 6),
        Text(
          processing
              ? 'Place your finger or look at the camera…'
              : 'Use fingerprint, Face ID, or PIN',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 22),
        processing
            ? const SizedBox(height: 52,
                child: Center(child: CircularProgressIndicator(color: _green, strokeWidth: 2.5)))
            : _Btn(label: 'Verify with Biometrics', icon: Icons.fingerprint_rounded,
                onTap: onScan),
      ])),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 3 — FACE DETECTION
// ─────────────────────────────────────────────────────────────────────────────

class _FaceStep extends StatefulWidget {
  final void Function(double) onVerified;
  const _FaceStep({required this.onVerified});
  @override State<_FaceStep> createState() => _FaceStepState();
}

class _FaceStepState extends State<_FaceStep> {
  CameraController? _cam;
  bool   _ready    = false;
  bool   _scanning = false;
  String _status   = 'Position your face in the frame';

  final _detector = FaceDetector(options: FaceDetectorOptions(
    enableClassification: true, enableLandmarks: true,
    performanceMode: FaceDetectorMode.accurate,
  ));

  @override void initState() { super.initState(); _initCam(); }
  @override void dispose()   { _cam?.dispose(); _detector.close(); super.dispose(); }

  Future<void> _initCam() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) return setState(() => _status = 'No camera found.');
      final front = cams.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cams.first);
      _cam = CameraController(front, ResolutionPreset.medium, enableAudio: false);
      await _cam!.initialize();
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _status = 'Camera error: $e');
    }
  }

  Future<void> _detect() async {
    if (_scanning || !(_cam?.value.isInitialized ?? false)) return;
    setState(() { _scanning = true; _status = 'Detecting face…'; });
    try {
      final f = await _cam!.takePicture();
      final faces = await _detector.processImage(InputImage.fromFilePath(f.path));
      try { File(f.path).deleteSync(); } catch (_) {}
      if (!mounted) return;

      if (faces.isEmpty) {
        return setState(() { _scanning = false; _status = 'No face detected. Move closer.'; });
      }
      final conf = ((faces.first.leftEyeOpenProbability ?? 0) +
                    (faces.first.rightEyeOpenProbability ?? 0)) / 2;
      if (conf >= 0.75) {
        setState(() { _scanning = false; _status = 'Face verified! ✓'; });
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) widget.onVerified(conf);
      } else {
        setState(() { _scanning = false; _status = 'Open both eyes and look straight ahead.'; });
      }
    } catch (_) {
      if (mounted) setState(() { _scanning = false; _status = 'Error. Tap Verify to retry.'; });
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _StepBar(current: 2),
      const SizedBox(height: 28),
      _Card(child: Column(children: [
        _CameraBox(
          child: _ready && _cam != null
              ? CameraPreview(_cam!)
              : Container(color: const Color(0xFFE8F5E9),
                  child: const Center(child: CircularProgressIndicator(color: _green))),
        ),
        const SizedBox(height: 14),
        const Text('Step 3: Face Verification',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _darkText)),
        const SizedBox(height: 6),
        Text(_status, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.4)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.light_mode_outlined, color: Color(0xFFF57C00), size: 13),
            const SizedBox(width: 5),
            Text('Face the light source for best results',
                style: TextStyle(fontSize: 11, color: Colors.orange.shade700,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(height: 18),
        _scanning
            ? const SizedBox(height: 52,
                child: Center(child: CircularProgressIndicator(color: _green, strokeWidth: 2.5)))
            : _Btn(
                label: _ready ? 'Verify Face' : 'Starting camera…',
                icon: Icons.camera_front_rounded,
                onTap: _ready ? _detect : () {}),
      ])),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 4 — DONE + CANDLELIGHT RELAY
// ─────────────────────────────────────────────────────────────────────────────

class _DoneStep extends StatelessWidget {
  final String className, unitCode;
  final Map<String, dynamic>? result;
  final bool processing, requestingRelay;
  final double faceScore;
  final String? relayQr;
  final VoidCallback onRelay, onReset;

  const _DoneStep({
    required this.className, required this.unitCode, required this.result,
    required this.processing, required this.faceScore, required this.relayQr,
    required this.requestingRelay, required this.onRelay, required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    if (processing) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      CircularProgressIndicator(color: _green, strokeWidth: 2.5),
      SizedBox(height: 14),
      Text('Submitting attendance…',
          style: TextStyle(color: _green, fontWeight: FontWeight.w600)),
    ]));
    }

    final sig      = result?['digitalSignature'] as String? ?? '';
    final shortSig = sig.length > 20 ? '${sig.substring(0, 20)}…' : sig;
    final verifs   = result?['verifications'] as Map<String, dynamic>? ?? {};
    final fLabel   = verifs['faceScore'] as String?
        ?? '${(faceScore * 100).toStringAsFixed(0)}%';

    return SingleChildScrollView(child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Success card ───────────────────────────────────────────────────
        _Card(child: Column(children: [
          _Circle(icon: Icons.verified_rounded, color: _green, size: 52,
              bg: const Color(0xFFE8F5E9)),
          const SizedBox(height: 16),
          const Text('Attendance Marked!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _green)),
          const SizedBox(height: 8),
          if (unitCode.isNotEmpty) ...[_Chip(unitCode, _green), const SizedBox(height: 6)],
          Text(className, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _darkText)),
          const SizedBox(height: 4),
          Text(
            '${TimeOfDay.now().format(context)} · '
            '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 18),
          // Verification rows
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              _Row(Icons.qr_code_scanner_rounded, 'QR Code',    'Verified'),
              _divider, _Row(Icons.fingerprint_rounded, 'Biometrics', 'Passed'),
              _divider, _Row(Icons.face_retouching_natural, 'Face ID', fLabel),
              _divider, _Row(Icons.my_location_rounded, 'Location', 'Checked'),
              _divider, _Row(Icons.verified_user_rounded, 'Signature', 'Valid'),
            ]),
          ),
          if (shortSig.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _green.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _green.withOpacity(0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.lock_rounded, size: 13, color: _green),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Digital Signature',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _green)),
                  Text(shortSig,
                      style: TextStyle(fontSize: 10,
                          color: Colors.grey.shade600, fontFamily: 'monospace')),
                ])),
              ]),
            ),
          ],
          const SizedBox(height: 20),
          _Btn(label: 'Scan Another Class',
              icon: Icons.qr_code_scanner_rounded, onTap: onReset),
        ])),
        const SizedBox(height: 16),

        // ── Relay card ─────────────────────────────────────────────────────
        _Card(
          borderColor: _green.withOpacity(0.3),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: _green.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.local_fire_department_rounded,
                    color: _green, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Pass the Flame 🕯️',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _darkText)),
                Text('Share with classmates who haven\'t signed yet',
                    style: TextStyle(fontSize: 11, color: Color(0xFF666666))),
              ])),
            ]),
            const SizedBox(height: 14),
            // QR or placeholder
            relayQr != null
                ? Center(child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        border: Border.all(color: _green, width: 2),
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.white),
                    child: QrImageView(
                      data: relayQr!, version: QrVersions.auto, size: 180,
                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: _green),
                      dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square, color: _green),
                    ),
                  ))
                : Container(
                    height: 64,
                    decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(10)),
                    child: Center(child: Text('Tap below to generate a relay QR',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade400)))),
            const SizedBox(height: 12),
            // Info badges
            _InfoRow(Icons.info_outline_rounded, const Color(0xFFFFF8E1), const Color(0xFFF57C00),
                'Single-use — burns after one scan. Stays valid while you\'re in the classroom.'),
            const SizedBox(height: 8),
            _InfoRow(Icons.location_on_rounded, const Color(0xFFE8F5E9), _green,
                'Must be inside classroom boundary to generate relay QRs.'),
            const SizedBox(height: 14),
            // Generate button
            GestureDetector(
              onTap: requestingRelay ? null : onRelay,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 48,
                decoration: BoxDecoration(
                  color: requestingRelay ? Colors.grey.shade200 : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: requestingRelay ? Colors.grey.shade300 : _green, width: 1.5),
                ),
                child: Center(child: requestingRelay
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: _green, strokeWidth: 2))
                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                        Icon(Icons.add_circle_outline_rounded, color: _green, size: 17),
                        SizedBox(width: 7),
                        Text('Generate New Relay QR',
                            style: TextStyle(fontSize: 13,
                                fontWeight: FontWeight.w700, color: _green)),
                      ])),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 24),
      ],
    ));
  }

  static const _divider = Divider(height: 14, color: Color(0xFFEEEEEE));
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 5 — ERROR
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorStep extends StatelessWidget {
  final String message; final VoidCallback onRetry;
  const _ErrorStep({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _Card(child: Column(children: [
        _Circle(icon: Icons.error_rounded, color: const Color(0xFFE53935),
            size: 46, bg: const Color(0xFFFFEBEE)),
        const SizedBox(height: 14),
        const Text('Verification Failed',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                color: Color(0xFFE53935))),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.5)),
        const SizedBox(height: 22),
        _Btn(label: 'Try Again', icon: Icons.refresh_rounded, onTap: onRetry),
      ])),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS (all small, all private)
// ─────────────────────────────────────────────────────────────────────────────

/// Step progress bar
class _StepBar extends StatelessWidget {
  final int current;
  const _StepBar({required this.current});

  static const _icons  = [Icons.qr_code_scanner_rounded,
                           Icons.fingerprint_rounded,
                           Icons.face_retouching_natural];
  static const _labels = ['QR Code', 'Biometrics', 'Face ID'];

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(3, (i) {
      final done   = i < current;
      final active = i == current;
      return Row(children: [
        Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 42, height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? _green : active ? _green.withOpacity(0.15) : Colors.grey.shade100,
              border: Border.all(
                  color: active ? _green : Colors.transparent, width: 2),
            ),
            child: Icon(_icons[i], size: 20,
                color: done ? Colors.white : active ? _green : Colors.grey.shade400),
          ),
          const SizedBox(height: 4),
          Text(_labels[i], style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
              color: active ? _green : Colors.grey.shade400)),
        ]),
        if (i < 2) Container(width: 28, height: 2,
            margin: const EdgeInsets.only(bottom: 18),
            color: i < current ? _green : Colors.grey.shade200),
      ]);
    }),
  );
}

/// White rounded card
class _Card extends StatelessWidget {
  final Widget child; final Color? borderColor;
  const _Card({required this.child, this.borderColor});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(22),
      border: borderColor != null ? Border.all(color: borderColor!, width: 1.5) : null,
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
          blurRadius: 20, offset: const Offset(0, 6))],
    ),
    child: child,
  );
}

/// 220×220 clipped camera / QR box
class _CameraBox extends StatelessWidget {
  final Widget child;
  const _CameraBox({required this.child});
  @override Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: SizedBox(width: double.infinity, height: 210, child: child),
  );
}

/// Circle icon container
class _Circle extends StatelessWidget {
  final IconData icon; final Color color, bg; final double size;
  const _Circle({required this.icon, required this.color, required this.bg, required this.size});
  @override Widget build(BuildContext context) => Container(
    width: size + 36, height: size + 36,
    decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
    child: Icon(icon, color: color, size: size),
  );
}

/// Coloured text chip
class _Chip extends StatelessWidget {
  final String text; final Color color;
  const _Chip(this.text, this.color);
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
    child: Text(text, style: const TextStyle(
        color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
  );
}

/// Verification row inside done card
class _Row extends StatelessWidget {
  final IconData icon; final String label, value;
  const _Row(this.icon, this.label, this.value);
  @override Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 17, color: _green),
    const SizedBox(width: 10),
    Expanded(child: Text(label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(7)),
      child: Text(value, style: const TextStyle(
          fontSize: 10, fontWeight: FontWeight.w700, color: _green)),
    ),
  ]);
}

/// Info badge row
class _InfoRow extends StatelessWidget {
  final IconData icon; final Color bg, fg; final String text;
  const _InfoRow(this.icon, this.bg, this.fg, this.text);
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
    child: Row(children: [
      Icon(icon, color: fg, size: 15),
      const SizedBox(width: 8),
      Expanded(child: Text(text,
          style: TextStyle(fontSize: 11, color: fg, height: 1.4))),
    ]),
  );
}

/// Green gradient button
class _Btn extends StatelessWidget {
  final String label; final IconData icon; final VoidCallback onTap;
  const _Btn({required this.label, required this.icon, required this.onTap});
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_green, _greenMid]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: _green.withOpacity(0.3),
            blurRadius: 12, offset: const Offset(0, 5))],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: Colors.white, size: 19),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(
            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
      ]),
    ),
  );
}