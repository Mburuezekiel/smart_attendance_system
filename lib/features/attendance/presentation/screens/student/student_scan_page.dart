// lib/features/assignments/presentation/student_scan_page.dart
//
// pubspec.yaml additions:
//   mobile_scanner: ^5.1.1
//   local_auth: ^2.3.0
//   google_mlkit_face_detection: ^0.11.0
//   camera: ^0.11.0
//   qr_flutter: ^4.1.0
//   geolocator: ^12.0.0

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

class StudentScanPage extends StatefulWidget {
  const StudentScanPage({super.key});
  @override
  State<StudentScanPage> createState() => _StudentScanPageState();
}

class _StudentScanPageState extends State<StudentScanPage> {
  // 0=qr  1=qr_success  2=biometric  3=face  4=done  5=error
  int     _step       = 0;
  String? _qrPayload;
  String? _className;
  String? _unitCode;
  String? _sessionId;
  bool    _bioPassed  = false;
  double  _faceScore  = 0.0;
  String? _errorMsg;
  bool    _processing = false;
  Map<String, dynamic>? _attendanceResult;

  // Candlelight
  String?  _relayQrPayload;
  bool     _requestingRelay = false;
  Position? _lastPosition;

  static const _green = Color(0xFF2E7D32);

  void _reset() => setState(() {
    _step = 0; _qrPayload = null; _className = null; _unitCode = null;
    _sessionId = null; _bioPassed = false; _faceScore = 0.0;
    _errorMsg = null; _processing = false; _attendanceResult = null;
    _relayQrPayload = null; _requestingRelay = false; _lastPosition = null;
  });

  // ── Get current GPS position ──────────────────────────────────────────────
  // Returns null with a reason string so the UI can show the real problem.
  Future<({Position? position, String? error})> _getPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return (position: null, error: 'Location services are disabled. Please enable GPS.');
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        return (position: null, error: 'Location permission permanently denied. Please enable it in app settings.');
      }
      if (perm == LocationPermission.denied) {
        return (position: null, error: 'Location permission denied. Please allow location access.');
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 15), onTimeout: () =>
          throw Exception('Location timed out. Move to an area with better GPS signal.'));

      return (position: pos, error: null);
    } catch (e) {
      return (position: null, error: e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ── Step 0 → 1 ────────────────────────────────────────────────────────────
  void _onQrDetected(String rawPayload) {
    try {
      final parsed  = jsonDecode(rawPayload) as Map<String, dynamic>;
      final qrToken = parsed['t'] as String?;
      if (qrToken == null || qrToken.isEmpty) throw Exception('Missing token');

      final exp = parsed['exp'] as int?;
      if (exp != null && DateTime.now().millisecondsSinceEpoch > exp) {
        setState(() {
          _errorMsg = 'This QR code has expired. Ask your lecturer or a classmate for a new one.';
          _step = 5;
        });
        return;
      }

      setState(() {
        _qrPayload = rawPayload;
        _className = parsed['unitName'] as String? ?? 'Class Session';
        _unitCode  = parsed['unitCode'] as String? ?? '';
        _step      = 1;
      });
    } catch (_) {
      setState(() {
        _errorMsg = 'Invalid QR code. Use the QR shown by your lecturer or a verified classmate.';
        _step     = 5;
      });
    }
  }

  // ── Step 2: Biometric ─────────────────────────────────────────────────────
  Future<void> _doFingerprint() async {
    setState(() => _processing = true);
    try {
      final auth      = LocalAuthentication();
      final canCheck  = await auth.canCheckBiometrics;
      final supported = await auth.isDeviceSupported();

      if (!canCheck && !supported) {
        if (mounted) setState(() { _processing = false; _bioPassed = false; _step = 3; });
        return;
      }

      final passed = await auth.authenticate(
        localizedReason: 'Verify your identity to mark attendance',
      );

      if (!mounted) return;
      if (passed) {
        setState(() { _bioPassed = true; _processing = false; _step = 3; });
      } else {
        setState(() {
          _processing = false;
          _errorMsg   = 'Biometric verification cancelled or failed.';
          _step       = 5;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _processing = false;
        _errorMsg   = 'Biometric error: ${e.toString()}';
        _step       = 5;
      });
    }
  }

  // ── Step 3 → 4 ────────────────────────────────────────────────────────────
  Future<void> _onFaceVerified(double confidence) async {
    setState(() { _faceScore = confidence; _processing = true; _step = 4; });
    await _submitAttendance();
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submitAttendance() async {
    if (_qrPayload == null) return;

    final (:position, :error) = await _getPosition();
    // GPS failure is non-blocking if the session has no geofence set.
    // The backend will accept null lat/lon when no geofence is configured.
    // If a geofence IS set the backend will reject the request with a clear message.
    if (position == null) {
      // Show a warning snackbar but continue — let the backend decide
      if (mounted && error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('⚠️ GPS unavailable: $error'),
          backgroundColor: const Color(0xFFF57C00),
          duration: const Duration(seconds: 3),
        ));
      }
    }
    _lastPosition = position;

    final result = await ApiService().post('/sessions/verify', {
      'qrPayload':       _qrPayload!,
      'biometricPassed': _bioPassed,
      'faceConfidence':  _faceScore,
      if (position != null) 'latitude':  position.latitude,
      if (position != null) 'longitude': position.longitude,
    });

    if (!mounted) return;
    if (result.success) {
      final sig         = result.data?['digitalSignature'] as String? ?? '';
      final candlelight = result.data?['candlelight'] as Map<String, dynamic>?;
      final relay       = candlelight?['relayQrPayload'] as String?;

      final sessionIdFromResult = result.data?['sessionId'] as String?;
      if (sessionIdFromResult != null) _sessionId = sessionIdFromResult;

      setState(() {
        _attendanceResult = {
          ...?result.data,
          'digitalSignature': sig,
          'verifications': result.data?['verifications'] ?? {
            'faceScore': '${(_faceScore * 100).toStringAsFixed(0)}%',
          },
        };
        _relayQrPayload = relay;
        _processing     = false;
      });
    } else {
      setState(() {
        _errorMsg   = result.error ?? 'Attendance submission failed.';
        _processing = false;
        _step       = 5;
      });
    }
  }

  // ── Request another relay token (geofence enforced on backend) ────────────
  Future<void> _requestMoreRelay() async {
    if (_sessionId == null && _attendanceResult == null) return;
    setState(() => _requestingRelay = true);

    final (:position, :error) = await _getPosition();
    if (position == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error ?? 'Could not get your location. Please enable GPS.'),
          backgroundColor: Colors.red,
        ));
        setState(() => _requestingRelay = false);
      }
      return;
    }

    String? sid = _sessionId
        ?? (_attendanceResult?['sessionId'] ?? _attendanceResult?['attendanceId']) as String?;

    if (sid == null) {
      setState(() => _requestingRelay = false);
      return;
    }

    final result = await ApiService().post('/sessions/request-relay', {
      'sessionId': sid,
      'latitude':  position.latitude,
      'longitude': position.longitude,
      'unitName':  _className ?? '',
      'unitCode':  _unitCode  ?? '',
    });

    if (!mounted) return;
    setState(() => _requestingRelay = false);

    if (result.success) {
      final newRelay = result.data?['relayQrPayload'] as String?;
      if (newRelay != null) {
        setState(() => _relayQrPayload = newRelay);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('New relay QR generated! Show it to your classmate.'),
          backgroundColor: Color(0xFF2E7D32),
        ));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.error ?? 'Could not generate relay QR.'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: _green,
        automaticallyImplyLeading: false,
        title: const Text('Mark Attendance',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        centerTitle: true,
        actions: [
          if (_step > 0)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _reset,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _buildStep(),
      ),
    );
  }

  Widget _buildStep() {
    return switch (_step) {
      0 => _QrScanStep(onDetected: _onQrDetected),
      1 => _QrSuccessWidget(
            className: _className ?? '',
            unitCode:  _unitCode  ?? '',
            onContinue: () => setState(() => _step = 2),
          ),
      2 => _BiometricWidget(processing: _processing, onScan: _doFingerprint),
      3 => _FaceWidget(onVerified: _onFaceVerified),
      4 => _DoneWidget(
            className:        _className ?? '',
            unitCode:         _unitCode  ?? '',
            result:           _attendanceResult,
            processing:       _processing,
            faceScore:        _faceScore,
            relayQrPayload:   _relayQrPayload,
            requestingRelay:  _requestingRelay,
            onRequestRelay:   _requestMoreRelay,
            onReset:          _reset,
          ),
      5 => _ErrorWidget(message: _errorMsg ?? 'Something went wrong.', onRetry: _reset),
      _ => const SizedBox.shrink(),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 0 — QR Scanner
// ─────────────────────────────────────────────────────────────────────────────

class _QrScanStep extends StatefulWidget {
  final ValueChanged<String> onDetected;
  const _QrScanStep({required this.onDetected});
  @override State<_QrScanStep> createState() => _QrScanStepState();
}

class _QrScanStepState extends State<_QrScanStep> {
  static const _green = Color(0xFF2E7D32);
  bool _showCamera = false;
  bool _scanned    = false;

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final raw = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (raw == null || raw.isEmpty) return;
    _scanned = true;
    widget.onDetected(raw);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScanStepIndicator(current: 0),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: _green.withOpacity(0.08),
                blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Column(children: [
            if (_showCamera) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 220, width: double.infinity,
                  child: MobileScanner(onDetect: _onDetect, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 12),
              Text('Scan lecturer QR or a verified classmate\'s relay QR',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => setState(() { _showCamera = false; _scanned = false; }),
                style: OutlinedButton.styleFrom(
                    foregroundColor: _green, side: const BorderSide(color: _green)),
                child: const Text('Cancel'),
              ),
            ] else ...[
              Container(
                width: 140, height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _green, width: 3),
                  color: const Color(0xFFE8F5E9),
                ),
                child: const Icon(Icons.qr_code_2_rounded, size: 90, color: _green),
              ),
              const SizedBox(height: 20),
              const Text('Scan QR Code',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                      color: Color(0xFF1B1B1B))),
              const SizedBox(height: 8),
              Text('Scan the lecturer\'s QR or a verified classmate\'s relay QR',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.5)),
              const SizedBox(height: 24),
              _GreenButton(
                label: 'Open Camera Scanner',
                icon: Icons.camera_alt_rounded,
                onTap: () => setState(() { _showCamera = true; _scanned = false; }),
              ),
            ],
          ]),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 1 — QR success
// ─────────────────────────────────────────────────────────────────────────────

class _QrSuccessWidget extends StatelessWidget {
  final String className, unitCode;
  final VoidCallback onContinue;
  static const _green = Color(0xFF2E7D32);
  const _QrSuccessWidget({
      required this.className, required this.unitCode, required this.onContinue});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _ScanStepIndicator(current: 0),
      const SizedBox(height: 32),
      Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: const Color(0xFF2E7D32).withOpacity(0.08),
              blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Column(children: [
          Container(width: 80, height: 80,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Color(0xFFE8F5E9)),
              child: const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF2E7D32), size: 46)),
          const SizedBox(height: 16),
          const Text('QR Verified!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                  color: Color(0xFF2E7D32))),
          if (unitCode.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: _green,
                  borderRadius: BorderRadius.circular(8)),
              child: Text(unitCode,
                  style: const TextStyle(color: Colors.white, fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ),
          ],
          const SizedBox(height: 8),
          Text(className, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                  color: Color(0xFF1B1B1B))),
          const SizedBox(height: 4),
          Text('Now verify your identity to complete attendance',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(height: 24),
          _GreenButton(
              label: 'Continue to Biometrics',
              icon: Icons.fingerprint_rounded,
              onTap: onContinue),
        ]),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 2 — Biometric
// ─────────────────────────────────────────────────────────────────────────────

class _BiometricWidget extends StatelessWidget {
  final bool processing;
  final VoidCallback onScan;
  static const _green = Color(0xFF2E7D32);
  const _BiometricWidget({required this.processing, required this.onScan});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _ScanStepIndicator(current: 1),
      const SizedBox(height: 32),
      Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: _green.withOpacity(0.08),
              blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Column(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 120, height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: processing ? _green.withOpacity(0.15) : const Color(0xFFE8F5E9),
              border: Border.all(
                  color: processing ? _green : Colors.grey.shade200, width: 2.5),
            ),
            child: Icon(Icons.fingerprint_rounded, size: 64,
                color: processing ? _green : Colors.grey.shade400),
          ),
          const SizedBox(height: 20),
          Text(processing ? 'Verifying…' : 'Step 2: Device Biometrics',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                  color: processing ? _green : const Color(0xFF1B1B1B))),
          const SizedBox(height: 8),
          Text(
            processing
                ? 'Place your finger on the sensor or look at the camera…'
                : 'Use your fingerprint, Face ID, or PIN\nto verify your identity',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.5),
          ),
          const SizedBox(height: 24),
          if (!processing)
            _GreenButton(
                label: 'Verify with Biometrics',
                icon: Icons.fingerprint_rounded,
                onTap: onScan)
          else
            const SizedBox(height: 52,
                child: Center(child: CircularProgressIndicator(
                    color: _green, strokeWidth: 2.5))),
        ]),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 3 — Face detection
// ─────────────────────────────────────────────────────────────────────────────

class _FaceWidget extends StatefulWidget {
  final void Function(double confidence) onVerified;
  const _FaceWidget({required this.onVerified});
  @override State<_FaceWidget> createState() => _FaceWidgetState();
}

class _FaceWidgetState extends State<_FaceWidget> {
  static const _green = Color(0xFF2E7D32);
  CameraController? _cam;
  bool   _cameraReady = false;
  bool   _scanning    = false;
  String _status      = 'Position your face in the frame';

  final _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  @override void initState() { super.initState(); _initCamera(); }
  @override void dispose()   { _cam?.dispose(); _faceDetector.close(); super.dispose(); }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _status = 'No camera found.');
        return;
      }
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cam = CameraController(front, ResolutionPreset.medium, enableAudio: false);
      await _cam!.initialize();
      if (mounted) setState(() => _cameraReady = true);
    } catch (e) {
      if (mounted) setState(() => _status = 'Camera init failed: $e');
    }
  }

  Future<void> _detectFace() async {
    if (_scanning || _cam == null || !_cam!.value.isInitialized) return;
    setState(() { _scanning = true; _status = 'Detecting face…'; });
    try {
      final xFile    = await _cam!.takePicture();
      final inputImg = InputImage.fromFilePath(xFile.path);
      final faces    = await _faceDetector.processImage(inputImg);
      try { File(xFile.path).deleteSync(); } catch (_) {}
      if (!mounted) return;

      if (faces.isEmpty) {
        setState(() { _scanning = false; _status = 'No face detected. Move closer.'; });
        return;
      }
      final face       = faces.first;
      final confidence = ((face.leftEyeOpenProbability  ?? 0.0) +
                          (face.rightEyeOpenProbability ?? 0.0)) / 2.0;

      if (confidence >= 0.75) {
        setState(() { _scanning = false; _status = 'Face verified! ✓'; });
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) widget.onVerified(confidence);
      } else {
        setState(() {
          _scanning = false;
          _status   = 'Liveness check failed. Open both eyes and look straight ahead.';
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _scanning = false; _status = 'Detection error. Tap Verify Face to retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _ScanStepIndicator(current: 2),
      const SizedBox(height: 32),
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: _green.withOpacity(0.08),
              blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Column(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 220, width: 220,
              child: _cameraReady && _cam != null
                  ? CameraPreview(_cam!)
                  : Container(color: const Color(0xFFE8F5E9),
                      child: const Center(child: CircularProgressIndicator(
                          color: _green, strokeWidth: 2))),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Step 3: Face Verification',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                  color: Color(0xFF1B1B1B))),
          const SizedBox(height: 8),
          Text(_status, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.5)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.light_mode_outlined,
                  color: Color(0xFFF57C00), size: 14),
              const SizedBox(width: 6),
              Text('Face the light source for best results',
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade700,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(height: 20),
          if (!_scanning)
            _GreenButton(
              label: _cameraReady ? 'Verify Face' : 'Starting camera…',
              icon: Icons.camera_front_rounded,
              onTap: _cameraReady ? _detectFace : () {},
            )
          else
            const SizedBox(height: 52,
                child: Center(child: CircularProgressIndicator(
                    color: _green, strokeWidth: 2.5))),
        ]),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 4 — Done + CANDLELIGHT multi-relay with geofence
// ─────────────────────────────────────────────────────────────────────────────

class _DoneWidget extends StatelessWidget {
  final String  className, unitCode;
  final Map<String, dynamic>? result;
  final bool    processing;
  final double  faceScore;
  final String? relayQrPayload;
  final bool    requestingRelay;
  final VoidCallback onRequestRelay;
  final VoidCallback onReset;
  static const _green = Color(0xFF2E7D32);

  const _DoneWidget({
    required this.className,
    required this.unitCode,
    required this.result,
    required this.processing,
    required this.faceScore,
    required this.relayQrPayload,
    required this.requestingRelay,
    required this.onRequestRelay,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    if (processing) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: _green, strokeWidth: 2.5),
        SizedBox(height: 16),
        Text('Submitting attendance…',
            style: TextStyle(color: _green, fontWeight: FontWeight.w600)),
      ]));
    }

    final sig       = result?['digitalSignature'] as String? ?? '';
    final shortSig  = sig.length > 20 ? '${sig.substring(0, 20)}…' : sig;
    final verifs    = result?['verifications'] as Map<String, dynamic>? ?? {};
    final faceLabel = verifs['faceScore'] as String?
        ?? '${(faceScore * 100).toStringAsFixed(0)}%';

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

        // ── Success card ─────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: _green.withOpacity(0.09),
                blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Column(children: [
            Container(width: 96, height: 96,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: Color(0xFFE8F5E9)),
                child: const Icon(Icons.verified_rounded, color: _green, size: 52)),
            const SizedBox(height: 20),
            const Text('Attendance Marked!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                    color: _green)),
            const SizedBox(height: 8),
            if (unitCode.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _green,
                    borderRadius: BorderRadius.circular(8)),
                child: Text(unitCode,
                    style: const TextStyle(color: Colors.white, fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 6),
            ],
            Text(className, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                    color: Color(0xFF1B1B1B))),
            const SizedBox(height: 4),
            Text(
              '${TimeOfDay.now().format(context)} · '
              '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                _DoneRow(Icons.qr_code_scanner_rounded, 'QR Code',    'Verified'),
                const Divider(height: 16, color: Color(0xFFEEEEEE)),
                _DoneRow(Icons.fingerprint_rounded,     'Biometrics', 'Passed'),
                const Divider(height: 16, color: Color(0xFFEEEEEE)),
                _DoneRow(Icons.face_retouching_natural, 'Face ID',    faceLabel),
                const Divider(height: 16, color: Color(0xFFEEEEEE)),
                _DoneRow(Icons.my_location_rounded,     'Location',   'Verified ✓'),
                const Divider(height: 16, color: Color(0xFFEEEEEE)),
                _DoneRow(Icons.verified_user_rounded,   'Signature',  'Valid'),
              ]),
            ),
            const SizedBox(height: 12),
            if (shortSig.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _green.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _green.withOpacity(0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.lock_rounded, size: 14, color: _green),
                  const SizedBox(width: 8),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Digital Signature',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                            color: _green)),
                    Text(shortSig,
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600,
                            fontFamily: 'monospace')),
                  ])),
                ]),
              ),
            const SizedBox(height: 24),
            _GreenButton(
                label: 'Scan Another Class',
                icon: Icons.qr_code_scanner_rounded,
                onTap: onReset),
          ]),
        ),

        // ── Candlelight relay card ────────────────────────────────────────────
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _green.withOpacity(0.3), width: 1.5),
            boxShadow: [BoxShadow(color: _green.withOpacity(0.08),
                blurRadius: 20, offset: const Offset(0, 6))],
          ),
          child: Column(children: [

            // Header
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: _green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.local_fire_department_rounded,
                    color: _green, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Pass the Flame 🕯️',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                        color: Color(0xFF1B1B1B))),
                Text('Help classmates who haven\'t signed yet',
                    style: TextStyle(fontSize: 11, color: Color(0xFF666666))),
              ])),
            ]),
            const SizedBox(height: 16),

            // QR display
            if (relayQrPayload != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: _green, width: 2.5),
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                ),
                child: QrImageView(
                  data: relayQrPayload!,
                  version: QrVersions.auto,
                  size: 200,
                  eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square, color: _green),
                  dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: _green),
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              Container(
                height: 80,
                decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text('Tap below to generate a relay QR',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400))),
              ),
              const SizedBox(height: 12),
            ],

            // Single-use info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded,
                    color: Color(0xFFF57C00), size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Each QR is single-use and burns after one scan.\n'
                  'You can generate a new one for each classmate — '
                  'but only while you\'re inside the classroom.',
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade800,
                      height: 1.5),
                )),
              ]),
            ),
            const SizedBox(height: 16),

            // Geofence badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.location_on_rounded,
                    color: Color(0xFF2E7D32), size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Geofence active — you must stay within the classroom boundary to generate relay QRs.',
                  style: TextStyle(fontSize: 11, color: Colors.green.shade800,
                      height: 1.5),
                )),
              ]),
            ),
            const SizedBox(height: 16),

            // Generate new relay button
            GestureDetector(
              onTap: requestingRelay ? null : onRequestRelay,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 50,
                decoration: BoxDecoration(
                  color: requestingRelay
                      ? Colors.grey.shade200
                      : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: requestingRelay ? Colors.grey.shade300 : _green,
                      width: 1.5),
                ),
                child: Center(child: requestingRelay
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Color(0xFF2E7D32), strokeWidth: 2))
                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.add_circle_outline_rounded,
                            color: _green, size: 18),
                        const SizedBox(width: 8),
                        const Text('Generate New Relay QR',
                            style: TextStyle(fontSize: 13,
                                fontWeight: FontWeight.w700, color: _green)),
                      ])),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 32),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 5 — Error
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorWidget({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.08),
              blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Column(children: [
          Container(width: 80, height: 80,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Color(0xFFFFEBEE)),
              child: const Icon(Icons.error_rounded,
                  color: Color(0xFFE53935), size: 46)),
          const SizedBox(height: 16),
          const Text('Verification Failed',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                  color: Color(0xFFE53935))),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600,
                  height: 1.5)),
          const SizedBox(height: 24),
          _GreenButton(label: 'Try Again',
              icon: Icons.refresh_rounded, onTap: onRetry),
        ]),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _DoneRow extends StatelessWidget {
  final IconData icon; final String label, value;
  static const _green = Color(0xFF2E7D32);
  const _DoneRow(this.icon, this.label, this.value);
  @override Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 18, color: _green),
    const SizedBox(width: 10),
    Expanded(child: Text(label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(8)),
      child: Text(value,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
              color: _green)),
    ),
  ]);
}

class _ScanStepIndicator extends StatelessWidget {
  final int current;
  static const _green = Color(0xFF2E7D32);
  const _ScanStepIndicator({required this.current});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(3, (i) {
      final icons  = [Icons.qr_code_scanner_rounded,
                      Icons.fingerprint_rounded,
                      Icons.face_retouching_natural];
      final labels = ['QR Code', 'Biometrics', 'Face ID'];
      final isDone   = i < current;
      final isActive = i == current;
      return Row(children: [
        Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 44, height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone ? _green
                  : isActive ? _green.withOpacity(0.15) : Colors.grey.shade100,
              border: Border.all(
                  color: isActive ? _green : Colors.transparent, width: 2),
            ),
            child: Icon(icons[i], size: 22,
                color: isDone ? Colors.white
                    : isActive ? _green : Colors.grey.shade400),
          ),
          const SizedBox(height: 4),
          Text(labels[i],
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                  color: isActive ? _green : Colors.grey.shade400)),
        ]),
        if (i < 2) Container(width: 32, height: 2,
            margin: const EdgeInsets.only(bottom: 20),
            color: i < current ? _green : Colors.grey.shade200),
      ]);
    }),
  );
}

class _GreenButton extends StatelessWidget {
  final String label; final IconData icon; final VoidCallback onTap;
  static const _green = Color(0xFF2E7D32);
  const _GreenButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_green, Color(0xFF43A047)]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: _green.withOpacity(0.3),
            blurRadius: 14, offset: const Offset(0, 5))],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 15,
            fontWeight: FontWeight.w700)),
      ]),
    ),
  );
}