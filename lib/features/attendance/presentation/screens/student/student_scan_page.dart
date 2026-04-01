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

// ── Theme-aware color helpers ─────────────────────────────────────────────────
class _C {
  static Color bg(BuildContext ctx)         => _d(ctx) ? const Color(0xFF0F1923) : const Color(0xFFF0F5F2);
  static Color surface(BuildContext ctx)    => _d(ctx) ? const Color(0xFF16232F) : Colors.white;
  static Color surfaceAlt(BuildContext ctx) => _d(ctx) ? const Color(0xFF1E2D38) : const Color(0xFFF4F8F6);
  static Color border(BuildContext ctx)     => _d(ctx) ? const Color(0xFF243040) : const Color(0xFFDDE8E3);
  static Color textPri(BuildContext ctx)    => _d(ctx) ? const Color(0xFFE8F0EC) : const Color(0xFF1A2E24);
  static Color textSec(BuildContext ctx)    => _d(ctx) ? const Color(0xFF8AA099) : const Color(0xFF5A7A6E);
  static Color textHint(BuildContext ctx)   => _d(ctx) ? const Color(0xFF3A5060) : const Color(0xFF9AB8AE);
  static Color greenFill(BuildContext ctx)  => _d(ctx) ? const Color(0xFF1A3828) : const Color(0xFFE6F7EF);
  static Color greenText(BuildContext ctx)  => _d(ctx) ? const Color(0xFF6EE8A4) : const Color(0xFF1A5C3A);
  static Color errorFill(BuildContext ctx)  => _d(ctx) ? const Color(0xFF2A1A1A) : const Color(0xFFFFF0F0);
  static Color errorText(BuildContext ctx)  => _d(ctx) ? const Color(0xFFE85F5F) : const Color(0xFFB22222);
  static Color warnFill(BuildContext ctx)   => _d(ctx) ? const Color(0xFF1E2D38) : const Color(0xFFFFF8E8);
  static Color warnText(BuildContext ctx)   => _d(ctx) ? const Color(0xFF8A7A5E) : const Color(0xFF7A5A0E);
  static bool _d(BuildContext ctx)          => Theme.of(ctx).brightness == Brightness.dark;
  static const green  = Color(0xFF26A05E);
  static const greenD = Color(0xFF1A5C3A);
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE
// ─────────────────────────────────────────────────────────────────────────────

class StudentScanPage extends StatefulWidget {
  const StudentScanPage({super.key});
  @override State<StudentScanPage> createState() => _StudentScanPageState();
}

class _StudentScanPageState extends State<StudentScanPage>
    with TickerProviderStateMixin {
  int     _step      = 0;
  String? _qrPayload, _className, _unitCode, _sessionId, _errorMsg, _relayQr;
  bool    _bioPassed = false, _processing = false, _requestingRelay = false;
  double  _faceScore = 0.0;
  Map<String, dynamic>? _result;
  Position? _lastPos;

  late final AnimationController _pageCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));
  late final Animation<double> _pageFade  =
      CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOut);
  late final Animation<Offset> _pageSlide =
      Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
          CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    _pageCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _toStep(int s) {
    setState(() => _step = s);
    _pageCtrl
      ..reset()
      ..forward();
  }

  void _reset() {
    setState(() {
      _step = 0;
      _qrPayload = _className = _unitCode = _sessionId =
          _errorMsg = _relayQr = null;
      _bioPassed = _processing = _requestingRelay = false;
      _faceScore = 0.0;
      _result = null;
      _lastPos = null;
    });
    _pageCtrl
      ..reset()
      ..forward();
  }

  // ── Location ──────────────────────────────────────────────────────────────
  Future<({Position? pos, String? err})> _getPos() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return (pos: null, err: 'Location services are disabled.');
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        return (pos: null, err: 'Location permission denied. Enable in settings.');
      }
      if (perm == LocationPermission.denied) {
        return (pos: null, err: 'Location permission denied.');
      }
      final p = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high)
          .timeout(const Duration(seconds: 15),
              onTimeout: () => throw Exception('Location timed out.'));
      return (pos: p, err: null);
    } catch (e) {
      return (pos: null, err: e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ── Step 0 → 1: QR detected ───────────────────────────────────────────────
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
      });
      _toStep(1);
    } catch (_) {
      _err('Invalid QR. Use the one shown by your lecturer or a verified classmate.');
    }
  }

  void _err(String msg) {
    setState(() => _errorMsg = msg);
    _toStep(5);
  }

  // ── Step 2: Biometric ─────────────────────────────────────────────────────
  Future<void> _doBio() async {
    setState(() => _processing = true);
    try {
      final auth = LocalAuthentication();
      if (!await auth.canCheckBiometrics && !await auth.isDeviceSupported()) {
        return setState(() {
          _processing = false;
          _bioPassed  = false;
        });
      }
      final ok = await auth.authenticate(
          localizedReason: 'Verify your identity to mark attendance');
      if (!mounted) return;
      if (ok) {
        setState(() {
          _bioPassed  = true;
          _processing = false;
        });
        _toStep(3);
      } else {
        _err('Biometric cancelled or failed. Please try again.');
      }
    } catch (e) {
      if (mounted) _err('Biometric error: $e');
    } finally {
      if (mounted && _processing) setState(() => _processing = false);
    }
  }

  // ── Step 3 → 4: Face verified ─────────────────────────────────────────────
  Future<void> _onFace(double conf) async {
    setState(() {
      _faceScore  = conf;
      _processing = true;
    });
    _toStep(4);
    await _submit();
  }

  // ── Submit ────────────────────────────────────────────────────────────────
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
      'qrPayload': _qrPayload!,
      'biometricPassed': _bioPassed,
      'faceConfidence': _faceScore,
      if (pos != null) 'latitude': pos.latitude,
      if (pos != null) 'longitude': pos.longitude,
    });
    if (!mounted) return;

    if (r.success) {
      final cl  = r.data?['candlelight'] as Map<String, dynamic>?;
      final sid = r.data?['sessionId'] as String?;
      if (sid != null) _sessionId = sid;
      setState(() {
        _result = {
          ...?r.data,
          'verifications': r.data?['verifications'] ??
              {'faceScore': '${(_faceScore * 100).toStringAsFixed(0)}%'},
        };
        _relayQr    = cl?['relayQrPayload'] as String?;
        _processing = false;
      });
    } else {
      setState(() {
        _errorMsg   = r.error ?? 'Submission failed.';
        _processing = false;
      });
      _toStep(5);
    }
  }

  // ── Relay QR ──────────────────────────────────────────────────────────────
  Future<void> _relay() async {
    final sid = _sessionId ??
        (_result?['sessionId'] ?? _result?['attendanceId']) as String?;
    if (sid == null) return;
    setState(() => _requestingRelay = true);

    final (:pos, :err) = await _getPos();
    if (pos == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(err ?? 'GPS unavailable.'),
            backgroundColor: Colors.red));
      }
      return setState(() => _requestingRelay = false);
    }

    final r = await ApiService().post('/sessions/request-relay', {
      'sessionId': sid,
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'unitName': _className ?? '',
      'unitCode': _unitCode ?? '',
    });
    if (!mounted) return;
    setState(() => _requestingRelay = false);
    if (r.success) {
      final relay = r.data?['relayQrPayload'] as String?;
      if (relay != null) setState(() => _relayQr = relay);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('New relay QR ready!'),
          backgroundColor: _C.green));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(r.error ?? 'Failed.'),
          backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _C.bg(context),
    appBar: AppBar(
      backgroundColor: _C.greenD,
      automaticallyImplyLeading: false,
      elevation: 0,
      centerTitle: true,
      title: const Text('Mark Attendance',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17)),
      leading: _step > 0
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => _toStep(_step > 0 ? _step - 1 : 0))
          : null,
      actions: [
        if (_step > 0)
          IconButton(
              icon: const Icon(Icons.refresh_rounded,
                  color: Colors.white, size: 22),
              onPressed: _reset),
      ],
    ),
    body: Column(children: [
      // Animated top progress bar
      _AnimatedProgressBar(step: _step),
      // Step indicator (hidden on done/error screens)
      if (_step < 4)
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 4),
          child: _StepIndicator(current: _step),
        ),
      // Page content with slide+fade transition
      Expanded(
        child: FadeTransition(
          opacity: _pageFade,
          child: SlideTransition(
            position: _pageSlide,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: _buildStep(context),
            ),
          ),
        ),
      ),
    ]),
  );

  Widget _buildStep(BuildContext ctx) => switch (_step) {
    0 => _QrScanStep(onDetected: _onQr),
    1 => _QrSuccessStep(
          className: _className!,
          unitCode: _unitCode!,
          onContinue: () => _toStep(2)),
    2 => _BioStep(processing: _processing, onScan: _doBio),
    3 => _FaceStep(onVerified: _onFace),
    4 => _DoneStep(
          className: _className!,
          unitCode: _unitCode!,
          result: _result,
          faceScore: _faceScore,
          processing: _processing,
          relayQr: _relayQr,
          requestingRelay: _requestingRelay,
          onRelay: _relay,
          onReset: _reset),
    5 => _ErrorStep(message: _errorMsg!, onRetry: _reset),
    _ => const SizedBox.shrink(),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// ANIMATED PROGRESS BAR
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedProgressBar extends StatelessWidget {
  final int step;
  const _AnimatedProgressBar({required this.step});

  @override
  Widget build(BuildContext context) {
    final pct = (step >= 4 ? 1.0 : step / 3.0).clamp(0.0, 1.0);
    return Container(
      height: 3,
      color: _C.surfaceAlt(context),
      alignment: Alignment.centerLeft,
      child: AnimatedFractionallySizedBox(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        widthFactor: pct,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [_C.greenD, _C.green]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP INDICATOR
// ─────────────────────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});

  static const _icons  = [
    Icons.qr_code_scanner_rounded,
    Icons.fingerprint_rounded,
    Icons.face_retouching_natural_rounded,
  ];
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
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            width: active ? 46 : 40,
            height: active ? 46 : 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done
                  ? _C.greenD
                  : active
                      ? _C.greenFill(context)
                      : _C.surfaceAlt(context),
              border: Border.all(
                color: active
                    ? _C.green
                    : done
                        ? _C.greenD
                        : _C.border(context),
                width: active ? 2 : 1.5,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                          color: _C.green.withOpacity(0.3),
                          blurRadius: 14,
                          offset: const Offset(0, 4))
                    ]
                  : [],
            ),
            child: done
                ? const Icon(Icons.check_rounded,
                    color: Colors.white, size: 20)
                : Icon(_icons[i],
                    size: 20,
                    color: active ? _C.green : _C.textHint(context)),
          ),
          const SizedBox(height: 5),
          Text(_labels[i],
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: active ? _C.green : _C.textHint(context),
              )),
        ]),
        if (i < 2)
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 32,
            height: 2,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: i < current ? _C.green : _C.border(context),
            ),
          ),
      ]);
    }),
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

class _QrScanStepState extends State<_QrScanStep>
    with SingleTickerProviderStateMixin {
  bool _show = false, _scanned = false;

  late final AnimationController _scanCtrl = AnimationController(
    vsync: this, duration: const Duration(seconds: 2))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _scanCtrl.dispose();
    super.dispose();
  }

  void _detect(BarcodeCapture c) {
    if (_scanned) return;
    final raw = c.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;
    _scanned = true;
    widget.onDetected(raw);
  }

  @override
  Widget build(BuildContext context) => _SurfaceCard(
    child: _show ? _buildCamera(context) : _buildPrompt(context),
  );

  Widget _buildPrompt(BuildContext ctx) => Column(children: [
    // Icon hero with glow
    Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        color: _C.greenFill(ctx),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _C.green.withOpacity(0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: _C.green.withOpacity(0.18),
              blurRadius: 28,
              spreadRadius: 2)
        ],
      ),
      child: Icon(Icons.qr_code_2_rounded, size: 58, color: _C.green),
    ),
    const SizedBox(height: 22),
    Text('Scan Attendance QR',
        style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: _C.textPri(ctx))),
    const SizedBox(height: 8),
    Text(
      'Scan the lecturer\'s QR or a verified\nclassmate\'s relay QR to mark attendance',
      textAlign: TextAlign.center,
      style:
          TextStyle(fontSize: 13, color: _C.textSec(ctx), height: 1.55),
    ),
    const SizedBox(height: 26),
    _PrimaryBtn(
      label: 'Open Camera',
      icon: Icons.camera_alt_rounded,
      onTap: () => setState(() {
        _show    = true;
        _scanned = false;
      }),
    ),
    const SizedBox(height: 14),
    _InfoBadge(
      icon: Icons.wifi_rounded,
      text: 'Make sure you are connected to the internet',
    ),
  ]);

  Widget _buildCamera(BuildContext ctx) => Column(children: [
    // Scanner viewfinder
    Stack(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: double.infinity,
          height: 240,
          child: MobileScanner(onDetect: _detect, fit: BoxFit.cover),
        ),
      ),
      // Corner bracket overlay
      Positioned.fill(
          child: CustomPaint(painter: _ScannerOverlayPainter())),
      // Animated laser line
      Positioned(
        left: 16,
        right: 16,
        top: 0,
        bottom: 0,
        child: AnimatedBuilder(
          animation: _scanCtrl,
          builder: (_, __) => Align(
            alignment: Alignment(0, _scanCtrl.value * 2 - 1),
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.transparent,
                  _C.green,
                  Colors.transparent,
                ]),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    ]),
    const SizedBox(height: 14),
    Text('Point at the QR from your lecturer or classmate',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: _C.textSec(ctx))),
    const SizedBox(height: 16),
    _OutlineBtn(
      label: 'Cancel',
      icon: Icons.close_rounded,
      onTap: () => setState(() {
        _show    = false;
        _scanned = false;
      }),
    ),
  ]);
}

/// Custom painter: scanner corner brackets
class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const len = 28.0;
    const r   = 6.0;
    final p   = Paint()
      ..color       = _C.green
      ..strokeWidth = 3
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round;

    void corner(double x, double y, double dx1, double dy1, double dx2, double dy2) {
      canvas.drawLine(Offset(x, y), Offset(x + dx1, y + dy1), p);
      canvas.drawLine(Offset(x, y), Offset(x + dx2, y + dy2), p);
    }

    corner(16 + r, 16,     -r, 0,  0, len,  );   // top-left
    corner(size.width - 16 - r, 16,    r, 0,  0, len);    // top-right (flip)
    corner(16 + r, size.height - 16,   -r, 0, 0, -len);   // bottom-left
    corner(size.width - 16 - r, size.height - 16,  r, 0, 0, -len); // bottom-right
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 1 — QR SUCCESS
// ─────────────────────────────────────────────────────────────────────────────

class _QrSuccessStep extends StatefulWidget {
  final String className, unitCode;
  final VoidCallback onContinue;
  const _QrSuccessStep({
    required this.className,
    required this.unitCode,
    required this.onContinue,
  });
  @override State<_QrSuccessStep> createState() => _QrSuccessStepState();
}

class _QrSuccessStepState extends State<_QrSuccessStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 700))
    ..forward();
  late final Animation<double> _scale =
      CurvedAnimation(parent: _ctl, curve: Curves.elasticOut);
  late final Animation<double> _fade  = CurvedAnimation(
      parent: _ctl,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut));

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SurfaceCard(
    child: Column(children: [
      ScaleTransition(
        scale: _scale,
        child: _PulsingCircle(
          icon: Icons.check_circle_rounded,
          color: _C.green,
          bg: _C.greenFill(context),
          size: 62,
        ),
      ),
      const SizedBox(height: 16),
      FadeTransition(
        opacity: _fade,
        child: Column(children: [
          Text('QR Verified!',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _C.greenText(context))),
          const SizedBox(height: 10),
          if (widget.unitCode.isNotEmpty) ...[
            _UnitChip(widget.unitCode),
            const SizedBox(height: 12),
          ],
          // Session info
          _InfoCard(children: [
            _SessionInfoRow(icon: Icons.book_rounded,     text: widget.className),
            _SessionInfoRow(icon: Icons.schedule_rounded, text: '8:00 AM – 10:00 AM'),
            _SessionInfoRow(icon: Icons.location_on_rounded, text: 'Lecture Theatre B'),
          ]),
          Text('Identity verification required to complete attendance',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, color: _C.textSec(context), height: 1.5)),
          const SizedBox(height: 22),
          _PrimaryBtn(
            label: 'Continue to Biometrics',
            icon: Icons.fingerprint_rounded,
            onTap: widget.onContinue,
          ),
        ]),
      ),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 2 — BIOMETRIC
// ─────────────────────────────────────────────────────────────────────────────

class _BioStep extends StatefulWidget {
  final bool processing;
  final VoidCallback onScan;
  const _BioStep({required this.processing, required this.onScan});
  @override State<_BioStep> createState() => _BioStepState();
}

class _BioStepState extends State<_BioStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this, duration: const Duration(seconds: 2))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SurfaceCard(
    child: Column(children: [
      Text(widget.processing ? 'Verifying…' : 'Device Biometrics',
          style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: _C.textPri(context))),
      const SizedBox(height: 5),
      Text(
        widget.processing
            ? 'Touch the sensor or look at the camera'
            : 'Use fingerprint, Face ID, or PIN',
        style: TextStyle(fontSize: 13, color: _C.textSec(context)),
      ),
      const SizedBox(height: 28),
      // Pulsing biometric button
      AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) => Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _C.green.withOpacity(0.12 + _pulse.value * 0.18),
                blurRadius: 18 + _pulse.value * 22,
                spreadRadius: _pulse.value * 5,
              )
            ],
          ),
          child: child,
        ),
        child: GestureDetector(
          onTap: widget.processing ? null : widget.onScan,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _C.greenFill(context),
              border: Border.all(
                color: widget.processing
                    ? _C.green
                    : _C.green.withOpacity(0.5),
                width: 2,
              ),
            ),
            child: widget.processing
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: CircularProgressIndicator(
                        color: _C.green, strokeWidth: 2.5))
                : Icon(Icons.fingerprint_rounded,
                    size: 60, color: _C.green),
          ),
        ),
      ),
      const SizedBox(height: 22),
      // Auth method tiles
      Row(children: [
        _AuthMethodTile(icon: Icons.fingerprint_rounded,             label: 'Fingerprint'),
        const SizedBox(width: 10),
        _AuthMethodTile(icon: Icons.face_retouching_natural_rounded, label: 'Face ID'),
        const SizedBox(width: 10),
        _AuthMethodTile(icon: Icons.lock_rounded,                    label: 'PIN'),
      ]),
      const SizedBox(height: 24),
      if (!widget.processing)
        _PrimaryBtn(
          label: 'Verify Identity',
          icon: Icons.verified_user_rounded,
          onTap: widget.onScan,
        ),
    ]),
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

class _FaceStepState extends State<_FaceStep>
    with SingleTickerProviderStateMixin {
  CameraController? _cam;
  bool   _ready    = false;
  bool   _scanning = false;
  String _status   = 'Position your face in the frame';

  late final AnimationController _floatCtrl = AnimationController(
    vsync: this, duration: const Duration(seconds: 3))
    ..repeat(reverse: true);
  late final Animation<double> _float =
      Tween(begin: -5.0, end: 5.0).animate(
          CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

  final _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  @override
  void initState() {
    super.initState();
    _initCam();
  }

  @override
  void dispose() {
    _cam?.dispose();
    _detector.close();
    _floatCtrl.dispose();
    super.dispose();
  }

  Future<void> _initCam() async {
    try {
      final cams  = await availableCameras();
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
    setState(() {
      _scanning = true;
      _status   = 'Detecting face…';
    });
    try {
      final f     = await _cam!.takePicture();
      final faces = await _detector.processImage(
          InputImage.fromFilePath(f.path));
      try { File(f.path).deleteSync(); } catch (_) {}
      if (!mounted) return;

      if (faces.isEmpty) {
        return setState(() {
          _scanning = false;
          _status   = 'No face detected. Move closer.';
        });
      }
      final conf = ((faces.first.leftEyeOpenProbability ?? 0) +
                    (faces.first.rightEyeOpenProbability ?? 0)) / 2;
      if (conf >= 0.75) {
        setState(() {
          _scanning = false;
          _status   = 'Face verified! ✓';
        });
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) widget.onVerified(conf);
      } else {
        setState(() {
          _scanning = false;
          _status   = 'Open both eyes and look straight ahead.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _scanning = false;
          _status   = 'Error. Tap Verify to retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => _SurfaceCard(
    child: Column(children: [
      Text('Face Verification',
          style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: _C.textPri(context))),
      const SizedBox(height: 4),
      Text('Look straight at the camera',
          style: TextStyle(fontSize: 13, color: _C.textSec(context))),
      const SizedBox(height: 16),
      // Camera with face oval overlay
      Stack(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: double.infinity,
            height: 240,
            child: _ready && _cam != null
                ? CameraPreview(_cam!)
                : Container(
                    color: _C.surfaceAlt(context),
                    child: const Center(
                        child: CircularProgressIndicator(color: _C.green))),
          ),
        ),
        Positioned.fill(
            child: CustomPaint(painter: _ScannerOverlayPainter())),
        // Floating animated oval guide
        Positioned.fill(
          child: Center(
            child: AnimatedBuilder(
              animation: _float,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, _float.value),
                child: child,
              ),
              child: Container(
                width: 112,
                height: 142,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(60),
                  border: Border.all(
                      color: _C.green.withOpacity(0.75), width: 2),
                ),
              ),
            ),
          ),
        ),
        // "Align face here" pill
        Positioned(
          bottom: 10,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: _C.greenD.withOpacity(0.78),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Align face here',
                  style: TextStyle(fontSize: 11, color: Colors.white)),
            ),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      // Animated status text
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Text(
          _status,
          key: ValueKey(_status),
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 13,
              color: _C.textSec(context),
              height: 1.4),
        ),
      ),
      const SizedBox(height: 10),
      _InfoBadge(
        icon: Icons.light_mode_outlined,
        text: 'Face the light source for best results',
        color: const Color(0xFFF57C00),
        bgColor: _C.warnFill(context),
      ),
      const SizedBox(height: 18),
      _scanning
          ? const SizedBox(
              height: 52,
              child: Center(
                  child: CircularProgressIndicator(
                      color: _C.green, strokeWidth: 2.5)))
          : _PrimaryBtn(
              label: _ready ? 'Verify Face' : 'Starting camera…',
              icon: Icons.camera_front_rounded,
              onTap: _ready ? _detect : () {}),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 4 — DONE + CANDLELIGHT RELAY
// ─────────────────────────────────────────────────────────────────────────────

class _DoneStep extends StatefulWidget {
  final String className, unitCode;
  final Map<String, dynamic>? result;
  final bool processing, requestingRelay;
  final double faceScore;
  final String? relayQr;
  final VoidCallback onRelay, onReset;

  const _DoneStep({
    required this.className,
    required this.unitCode,
    required this.result,
    required this.processing,
    required this.faceScore,
    required this.relayQr,
    required this.requestingRelay,
    required this.onRelay,
    required this.onReset,
  });

  @override State<_DoneStep> createState() => _DoneStepState();
}

class _DoneStepState extends State<_DoneStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800))
    ..forward();
  late final Animation<double> _scale =
      CurvedAnimation(parent: _ctl, curve: Curves.elasticOut);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.processing) {
      return SizedBox(
        height: 300,
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(color: _C.green, strokeWidth: 2.5),
            const SizedBox(height: 16),
            Text('Submitting attendance…',
                style: TextStyle(
                    color: _C.greenText(context),
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      );
    }

    final sig      = widget.result?['digitalSignature'] as String? ?? '';
    final shortSig = sig.length > 24 ? '${sig.substring(0, 24)}…' : sig;
    final verifs   = widget.result?['verifications'] as Map<String, dynamic>? ?? {};
    final fLabel   = verifs['faceScore'] as String?
        ?? '${(widget.faceScore * 100).toStringAsFixed(0)}%';
    final now      = DateTime.now();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // ── Success card ─────────────────────────────────────────────────────
      _SurfaceCard(child: Column(children: [
        ScaleTransition(
          scale: _scale,
          child: _PulsingCircle(
            icon: Icons.verified_rounded,
            color: _C.green,
            bg: _C.greenFill(context),
            size: 60,
          ),
        ),
        const SizedBox(height: 16),
        Text('Attendance Marked!',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: _C.greenText(context))),
        const SizedBox(height: 6),
        Text(
          '${TimeOfDay.now().format(context)} · '
          '${now.day}/${now.month}/${now.year}',
          style: TextStyle(fontSize: 12, color: _C.textSec(context)),
        ),
        const SizedBox(height: 12),
        if (widget.unitCode.isNotEmpty) ...[
          _UnitChip(widget.unitCode),
          const SizedBox(height: 8),
        ],
        Text(widget.className,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _C.textPri(context))),
        const SizedBox(height: 18),
        // Verification breakdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: _C.surfaceAlt(context),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: [
            _VerifyRow(icon: Icons.qr_code_scanner_rounded,         label: 'QR Code',    value: 'Verified'),
            _VerifyRow(icon: Icons.fingerprint_rounded,              label: 'Biometrics', value: 'Passed'),
            _VerifyRow(icon: Icons.face_retouching_natural_rounded,  label: 'Face ID',    value: fLabel),
            _VerifyRow(icon: Icons.my_location_rounded,              label: 'Location',   value: 'Checked'),
            _VerifyRow(icon: Icons.verified_user_rounded,            label: 'Signature',  value: 'Valid', last: true),
          ]),
        ),
        if (shortSig.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _C.greenFill(context),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: _C.green.withOpacity(0.25)),
            ),
            child: Row(children: [
              Icon(Icons.lock_rounded, size: 14, color: _C.greenText(context)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Digital Signature',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _C.greenText(context))),
                  Text(shortSig,
                      style: TextStyle(
                          fontSize: 10,
                          color: _C.textSec(context),
                          fontFamily: 'monospace')),
                ]),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 20),
        _PrimaryBtn(
            label: 'Scan Another Class',
            icon: Icons.qr_code_scanner_rounded,
            onTap: widget.onReset),
      ])),
      const SizedBox(height: 16),

      // ── Relay / Candlelight card ──────────────────────────────────────────
      _SurfaceCard(
        borderColor: _C.green.withOpacity(0.3),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: _C.greenFill(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.local_fire_department_rounded,
                  color: _C.green, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Pass the Flame 🕯️',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _C.textPri(context))),
                Text('Share with classmates who haven\'t signed yet',
                    style: TextStyle(
                        fontSize: 11, color: _C.textSec(context))),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          // QR display or placeholder
          widget.relayQr != null
              ? Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: _C.green, width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: QrImageView(
                      data: widget.relayQr!,
                      version: QrVersions.auto,
                      size: 180,
                      eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square, color: _C.greenD),
                      dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: _C.greenD),
                    ),
                  ),
                )
              : Container(
                  height: 72,
                  decoration: BoxDecoration(
                    color: _C.surfaceAlt(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      'Tap below to generate a relay QR',
                      style: TextStyle(
                          fontSize: 12, color: _C.textHint(context)),
                    ),
                  ),
                ),
          const SizedBox(height: 14),
          _InfoBadge(
            icon: Icons.info_outline_rounded,
            text:
                'Single-use — burns after one scan. Valid while you\'re in class.',
            color: const Color(0xFFF57C00),
            bgColor: _C.warnFill(context),
          ),
          const SizedBox(height: 8),
          _InfoBadge(
            icon: Icons.location_on_rounded,
            text: 'Must be inside classroom boundary to generate relay QRs.',
          ),
          const SizedBox(height: 16),
          // Generate / loading button
          GestureDetector(
            onTap: widget.requestingRelay ? null : widget.onRelay,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 50,
              decoration: BoxDecoration(
                color: widget.requestingRelay
                    ? _C.surfaceAlt(context)
                    : _C.greenFill(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: widget.requestingRelay
                      ? _C.border(context)
                      : _C.green,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: widget.requestingRelay
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: _C.green, strokeWidth: 2))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline_rounded,
                              color: _C.green, size: 18),
                          const SizedBox(width: 8),
                          Text('Generate New Relay QR',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _C.greenText(context))),
                        ],
                      ),
              ),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 28),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 5 — ERROR
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorStep extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorStep({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => _SurfaceCard(
    child: Column(children: [
      _PulsingCircle(
        icon: Icons.error_rounded,
        color: _C.errorText(context),
        bg: _C.errorFill(context),
        size: 52,
        pulsing: false,
      ),
      const SizedBox(height: 14),
      Text('Verification Failed',
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _C.errorText(context))),
      const SizedBox(height: 10),
      Text(message,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 13, color: _C.textSec(context), height: 1.5)),
      const SizedBox(height: 14),
      // Reason list
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _C.surfaceAlt(context),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Common reasons:',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _C.textPri(context))),
          const SizedBox(height: 8),
          for (final reason in [
            'QR code expired (valid for ~5 minutes)',
            'You are outside the classroom boundary',
            'Biometric authentication cancelled',
            'Network issue — check your connection',
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _C.errorText(context))),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(reason,
                      style: TextStyle(
                          fontSize: 11, color: _C.textSec(context))),
                ),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 22),
      _PrimaryBtn(
          label: 'Try Again',
          icon: Icons.refresh_rounded,
          onTap: onRetry),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

/// Surface card — white in light mode, dark in dark mode
class _SurfaceCard extends StatelessWidget {
  final Widget child;
  final Color? borderColor;
  const _SurfaceCard({required this.child, this.borderColor});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: _C.surface(context),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: borderColor ?? _C.border(context),
        width: borderColor != null ? 1.5 : 1.0,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(
              Theme.of(context).brightness == Brightness.dark ? 0.22 : 0.06),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: child,
  );
}

/// Pulsing circle icon — used for success and error states
class _PulsingCircle extends StatefulWidget {
  final IconData icon;
  final Color color, bg;
  final double size;
  final bool pulsing;
  const _PulsingCircle({
    required this.icon,
    required this.color,
    required this.bg,
    required this.size,
    this.pulsing = true,
  });
  @override State<_PulsingCircle> createState() => _PulsingCircleState();
}

class _PulsingCircleState extends State<_PulsingCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this, duration: const Duration(seconds: 2))
    ..repeat();
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      if (widget.pulsing)
        AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Container(
            width: widget.size + 64,
            height: widget.size + 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withOpacity((1 - _c.value) * 0.14),
            ),
          ),
        ),
      Container(
        width: widget.size + 36,
        height: widget.size + 36,
        decoration: BoxDecoration(shape: BoxShape.circle, color: widget.bg),
        child: Icon(widget.icon, color: widget.color, size: widget.size),
      ),
    ],
  );
}

/// Green unit code chip
class _UnitChip extends StatelessWidget {
  final String text;
  const _UnitChip(this.text);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
    decoration:
        BoxDecoration(color: _C.green, borderRadius: BorderRadius.circular(10)),
    child: Text(text,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4)),
  );
}

/// Info card container (step 1 session info)
class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(vertical: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _C.surfaceAlt(context),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(children: children),
  );
}

class _SessionInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SessionInfoRow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Icon(icon, size: 15, color: _C.green),
      const SizedBox(width: 10),
      Expanded(
        child: Text(text,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _C.textPri(context))),
      ),
    ]),
  );
}

/// Biometric auth method tile
class _AuthMethodTile extends StatelessWidget {
  final IconData icon;
  final String label;
  const _AuthMethodTile({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: _C.surfaceAlt(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border(context)),
      ),
      child: Column(children: [
        Icon(icon, color: _C.green, size: 22),
        const SizedBox(height: 5),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: _C.textSec(context),
                fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

/// Verification row in done card
class _VerifyRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final bool last;
  const _VerifyRow({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
  });
  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(children: [
        Icon(icon, size: 17, color: _C.green),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _C.textPri(context))),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _C.greenFill(context),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(value,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _C.greenText(context))),
        ),
      ]),
    ),
    if (!last) Divider(height: 1, color: _C.border(context)),
  ]);
}

/// Info / warning badge
class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color, bgColor;
  const _InfoBadge({
    required this.icon,
    required this.text,
    this.color,
    this.bgColor,
  });
  @override
  Widget build(BuildContext context) {
    final c  = color  ?? _C.green;
    final bg = bgColor ?? _C.greenFill(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(icon, color: c, size: 14),
        const SizedBox(width: 8),
        Expanded(
            child:
                Text(text, style: TextStyle(fontSize: 11, color: c, height: 1.4))),
      ]),
    );
  }
}

/// Primary gradient CTA button
class _PrimaryBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _PrimaryBtn({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A5C3A), Color(0xFF26A05E)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _C.green.withOpacity(0.32),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: Colors.white, size: 19),
        const SizedBox(width: 9),
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700)),
      ]),
    ),
  );
}

/// Outline secondary button
class _OutlineBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _OutlineBtn({required this.label, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 16),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      foregroundColor: _C.green,
      side: const BorderSide(color: _C.green),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    ),
  );
}