// lib/features/auth/presentation/signup_page.dart
//
// Full API-integrated signup flow.
// Calls:
//   POST /api/auth/signup          (Step 0 → Step 1)
//   POST /api/biometric/fingerprint (Step 1, if not skipped)
//   POST /api/biometric/faceid      (Step 2, if not skipped)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_ios/local_auth_ios.dart';

import '../../../../../core/services/api_service.dart'; 

enum BiometricStatus { idle, scanning, success, failed, unavailable, skipped }
enum FaceIdStatus    { idle, scanning, success, failed, skipped }

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});
  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage>
    with SingleTickerProviderStateMixin {

  // ── Animations ─────────────────────────────────────────────────────────────
  late AnimationController _controller;
  late Animation<double>  _fadeAnim;
  late Animation<Offset>  _slideAnim;
  late Animation<double>  _headerScaleAnim;

  // ── Steps: 0=form, 1=biometric, 2=faceId, 3=success ──────────────────────
  int _step = 0;

  // ── Form ───────────────────────────────────────────────────────────────────
  bool _obscurePassword = true;
  bool _isLoading       = false;
  String? _errorMessage;

  final _formKey        = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _regController  = TextEditingController();
  final _emailController= TextEditingController();
  final _passController = TextEditingController();

  // ── Biometrics ─────────────────────────────────────────────────────────────
  final _localAuth = LocalAuthentication();
  BiometricStatus _biometricStatus = BiometricStatus.idle;
  FaceIdStatus    _faceIdStatus    = FaceIdStatus.idle;

  // ── API ────────────────────────────────────────────────────────────────────
  final _api = ApiService();

  static const _green = Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _headerScaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    _regController.dispose();
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() {
      _step = step;
      _errorMessage = null;
    });
    _controller..reset()..forward();
  }

  // ── STEP 0 — Signup API call ──────────────────────────────────────────────
  Future<void> _handleFormSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() { _isLoading = true; _errorMessage = null; });

    final result = await _api.signup(
      fullName:            _nameController.text.trim(),
      registrationNumber:  _regController.text.trim(),
      email:               _emailController.text.trim(),
      password:            _passController.text,
    );

    if (!mounted) return;

    if (result.success) {
      setState(() => _isLoading = false);
      _goToStep(1);
    } else {
      setState(() {
        _isLoading    = false;
        _errorMessage = result.error;
      });
    }
  }

  // ── STEP 1 — Fingerprint: local auth → then notify backend ───────────────
  Future<void> _registerBiometric() async {
    setState(() {
      _biometricStatus = BiometricStatus.scanning;
      _errorMessage    = null;
    });

    try {
      final canAuth  = await _localAuth.canCheckBiometrics;
      final available = await _localAuth.getAvailableBiometrics();

      if (!canAuth || available.isEmpty) {
        setState(() => _biometricStatus = BiometricStatus.unavailable);
        return;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason:
            'Place your finger on the sensor to register for attendance',
        authMessages: [
          const AndroidAuthMessages(
            signInTitle:  'Fingerprint Required',
            cancelButton: 'Cancel',
          ),
          const IOSAuthMessages(cancelButton: 'Cancel'),
        ],
      );

      if (!authenticated) {
        setState(() => _biometricStatus = BiometricStatus.failed);
        return;
      }

      // ── Notify backend ────────────────────────────────────────────────────
      final apiResult = await _api.registerFingerprint();

      if (!mounted) return;

      if (apiResult.success) {
        setState(() => _biometricStatus = BiometricStatus.success);
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) _goToStep(2);
      } else {
        setState(() {
          _biometricStatus = BiometricStatus.failed;
          _errorMessage    = apiResult.error;
        });
      }
    } on PlatformException {
      if (mounted) setState(() => _biometricStatus = BiometricStatus.failed);
    }
  }

  // ── STEP 2 — Face ID: capture → notify backend ───────────────────────────
  Future<void> _registerFaceId() async {
    setState(() {
      _faceIdStatus = FaceIdStatus.scanning;
      _errorMessage = null;
    });

    // TODO: Replace the delay below with real camera capture:
    //   final imageBytes = await _captureFrame();   // CameraController
    //   final b64 = base64Encode(imageBytes);
    //   final apiResult = await _api.registerFaceId(base64Image: b64);
    await Future.delayed(const Duration(milliseconds: 2200));

    final apiResult = await _api.registerFaceId();

    if (!mounted) return;

    if (apiResult.success) {
      setState(() => _faceIdStatus = FaceIdStatus.success);
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) _goToStep(3);
    } else {
      setState(() {
        _faceIdStatus = FaceIdStatus.failed;
        _errorMessage = apiResult.error;
      });
    }
  }

  // ── STEP 3 — Navigate to home ─────────────────────────────────────────────
  Future<void> _finishRegistration() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) context.go('/home');
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size    = MediaQuery.of(context).size;
    final isSmall = size.width < 360;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(children: [
          ScaleTransition(
            scale: _headerScaleAnim,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: _Header(size: size, isSmall: isSmall, step: _step),
            ),
          ),
          const SizedBox(height: 24),
          FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isSmall ? 16 : 24),
                child: Column(children: [
                  // ── Global error banner ───────────────────────────────────
                  if (_errorMessage != null) ...[
                    _ErrorBanner(message: _errorMessage!,
                        onDismiss: () => setState(() => _errorMessage = null)),
                    const SizedBox(height: 12),
                  ],
                  _buildStep(isSmall),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildStep(bool isSmall) {
    switch (_step) {
      case 0:
        return _FormStep(
          formKey: _formKey,
          nameController:  _nameController,
          regController:   _regController,
          emailController: _emailController,
          passController:  _passController,
          obscurePassword: _obscurePassword,
          isLoading: _isLoading,
          onToggleObscure: () =>
              setState(() => _obscurePassword = !_obscurePassword),
          onSubmit:   _handleFormSubmit,
          onLoginTap: () => context.go('/login'),
        );
      case 1:
        return _BiometricStep(
          status:     _biometricStatus,
          onRegister: _registerBiometric,
          onSkip: () {
            setState(() => _biometricStatus = BiometricStatus.skipped);
            _goToStep(2);
          },
        );
      case 2:
        return _FaceIdStep(
          status:     _faceIdStatus,
          onRegister: _registerFaceId,
          onSkip: () {
            setState(() => _faceIdStatus = FaceIdStatus.skipped);
            _goToStep(3);
          },
        );
      case 3:
        return _SuccessStep(
          biometricDone: _biometricStatus == BiometricStatus.success,
          faceIdDone:    _faceIdStatus    == FaceIdStatus.success,
          isLoading:     _isLoading,
          onFinish:      _finishRegistration,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ERROR BANNER
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE53935).withOpacity(0.4)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded,
            color: Color(0xFFE53935), size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message,
              style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFB71C1C),
                  fontWeight: FontWeight.w500)),
        ),
        GestureDetector(
          onTap: onDismiss,
          child: const Icon(Icons.close_rounded,
              color: Color(0xFFE53935), size: 18),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP INDICATOR
// ─────────────────────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int current;
  static const _green = Color(0xFF2E7D32);
  const _StepIndicator({required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: i <= current ? _green : Colors.grey.shade200,
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 0 — FORM
// ─────────────────────────────────────────────────────────────────────────────

class _FormStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController, regController,
      emailController, passController;
  final bool obscurePassword, isLoading;
  final VoidCallback onToggleObscure, onSubmit, onLoginTap;

  static const _green = Color(0xFF2E7D32);

  const _FormStep({
    required this.formKey,
    required this.nameController,
    required this.regController,
    required this.emailController,
    required this.passController,
    required this.obscurePassword,
    required this.isLoading,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.onLoginTap,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const _StepIndicator(current: 0),
        const SizedBox(height: 16),
        const Text("Create Account",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                color: Color(0xFF1B1B1B), letterSpacing: 0.3)),
        const SizedBox(height: 4),
        Text("Step 1 of 3 · Fill in your details",
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: _green.withOpacity(0.08),
                blurRadius: 24, offset: const Offset(0, 8))],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            _AnimatedField(delay: 80,  controller: nameController,
                label: "Full Name", hint: "e.g. Ezekiel Njuguna",
                icon: Icons.person_outline_rounded,
                validator: (v) => v == null || v.isEmpty ? "Required" : null),
            const SizedBox(height: 16),
            _AnimatedField(delay: 150, controller: regController,
                label: "Registration Number", hint: "e.g. SC232/0654/2022",
                icon: Icons.badge_outlined,
                validator: (v) => v == null || v.isEmpty ? "Required" : null),
            const SizedBox(height: 16),
            _AnimatedField(delay: 220, controller: emailController,
                label: "Email Address", hint: "e.g. student@mku.ac.ke",
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    v != null && v.contains('@') ? null : "Invalid email"),
            const SizedBox(height: 16),
            _AnimatedField(delay: 290, controller: passController,
                label: "Password", hint: "Create a strong password",
                icon: Icons.lock_outline_rounded,
                obscure: obscurePassword,
                validator: (v) =>
                    v != null && v.length >= 6 ? null : "Min. 6 characters",
                suffixIcon: IconButton(
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Icon(
                      obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      key: ValueKey(obscurePassword),
                      color: Colors.grey.shade500, size: 20,
                    ),
                  ),
                  onPressed: onToggleObscure,
                )),
          ]),
        ),
        const SizedBox(height: 24),
        _AnimatedButton(isLoading: isLoading, onPressed: onSubmit,
            label: "Continue"),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text("Already have an account? ",
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
          GestureDetector(
            onTap: onLoginTap,
            child: const Text("Sign In",
                style: TextStyle(color: _green,
                    fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ]),
        const SizedBox(height: 36),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 1 — BIOMETRIC
// ─────────────────────────────────────────────────────────────────────────────

class _BiometricStep extends StatefulWidget {
  final BiometricStatus status;
  final VoidCallback onRegister, onSkip;
  const _BiometricStep(
      {required this.status, required this.onRegister, required this.onSkip});
  @override
  State<_BiometricStep> createState() => _BiometricStepState();
}

class _BiometricStepState extends State<_BiometricStep>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 850),
        lowerBound: 0.93, upperBound: 1.0)
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  static const _green        = Color(0xFF2E7D32);
  static const _greenSurface = Color(0xFFE8F5E9);

  @override
  Widget build(BuildContext context) {
    final s          = widget.status;
    final isScanning = s == BiometricStatus.scanning;
    final isSuccess  = s == BiometricStatus.success;
    final isFailed   = s == BiometricStatus.failed ||
                       s == BiometricStatus.unavailable;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _StepIndicator(current: 1),
      const SizedBox(height: 16),
      const Text("Register Fingerprint",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
              color: Color(0xFF1B1B1B))),
      const SizedBox(height: 4),
      Text("Step 2 of 3 · Phone's built-in biometric sensor",
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: _green.withOpacity(0.08),
              blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Column(children: [
          ScaleTransition(
            scale: isScanning ? _pulse : const AlwaysStoppedAnimation(1.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSuccess ? _greenSurface
                    : isFailed ? const Color(0xFFFFEBEE)
                    : isScanning ? _green.withOpacity(0.1)
                    : _greenSurface,
                border: Border.all(width: 2.5,
                  color: isSuccess ? _green
                      : isFailed ? const Color(0xFFE53935)
                      : isScanning ? _green
                      : Colors.grey.shade200,
                ),
              ),
              child: Icon(
                isSuccess ? Icons.check_circle_rounded
                    : isFailed ? Icons.error_outline_rounded
                    : Icons.fingerprint_rounded,
                size: 58,
                color: isSuccess ? _green
                    : isFailed ? const Color(0xFFE53935)
                    : isScanning ? _green
                    : Colors.grey.shade400,
              ),
            ),
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              key: ValueKey(s),
              isSuccess ? "Fingerprint Registered!"
                  : isFailed
                      ? (s == BiometricStatus.unavailable
                          ? "Biometrics Not Available"
                          : "Scan Failed — Try Again")
                  : isScanning ? "Scanning…"
                  : "Register Your Fingerprint",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                  color: isSuccess ? _green
                      : isFailed ? const Color(0xFFE53935)
                      : const Color(0xFF1B1B1B)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSuccess
                ? "Fingerprint saved. Synced with server ✓"
                : isScanning
                    ? "Place your finger firmly on the sensor…"
                    : isFailed
                        ? "Ensure biometrics are enrolled in Settings."
                        : "Uses your phone's built-in fingerprint sensor.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13,
                color: Colors.grey.shade500, height: 1.5),
          ),
          if (!isSuccess) ...[
            const SizedBox(height: 28),
            _PrimaryBtn(
              label:   isScanning ? "Scanning…"
                  : isFailed ? "Try Again"
                  : "Scan Fingerprint",
              icon:    Icons.fingerprint_rounded,
              onTap:   isScanning ? null : widget.onRegister,
              loading: isScanning,
            ),
            const SizedBox(height: 12),
            _SkipBtn(onTap: widget.onSkip),
          ],
        ]),
      ),
      const SizedBox(height: 36),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 2 — FACE ID
// ─────────────────────────────────────────────────────────────────────────────

class _FaceIdStep extends StatefulWidget {
  final FaceIdStatus status;
  final VoidCallback onRegister, onSkip;
  const _FaceIdStep(
      {required this.status, required this.onRegister, required this.onSkip});
  @override
  State<_FaceIdStep> createState() => _FaceIdStepState();
}

class _FaceIdStepState extends State<_FaceIdStep>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanLine;

  @override
  void initState() {
    super.initState();
    _scanLine = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _scanLine.dispose(); super.dispose(); }

  static const _green        = Color(0xFF2E7D32);
  static const _greenSurface = Color(0xFFE8F5E9);

  @override
  Widget build(BuildContext context) {
    final s          = widget.status;
    final isScanning = s == FaceIdStatus.scanning;
    final isSuccess  = s == FaceIdStatus.success;
    final isFailed   = s == FaceIdStatus.failed;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _StepIndicator(current: 2),
      const SizedBox(height: 16),
      const Text("Register Face ID",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
              color: Color(0xFF1B1B1B))),
      const SizedBox(height: 4),
      Text("Step 3 of 3 · Front camera facial capture",
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: _green.withOpacity(0.08),
              blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Column(children: [
          SizedBox(
            width: 120, height: 120,
            child: Stack(alignment: Alignment.center, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                width: 120, height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  color: isSuccess ? _greenSurface
                      : isFailed ? const Color(0xFFFFEBEE)
                      : isScanning ? _green.withOpacity(0.08)
                      : _greenSurface,
                  border: Border.all(width: 2.5,
                    color: isSuccess ? _green
                        : isFailed ? const Color(0xFFE53935)
                        : isScanning ? _green
                        : Colors.grey.shade200,
                  ),
                ),
                child: Icon(
                  isSuccess ? Icons.check_circle_rounded
                      : isFailed ? Icons.error_outline_rounded
                      : Icons.face_retouching_natural,
                  size: 58,
                  color: isSuccess ? _green
                      : isFailed ? const Color(0xFFE53935)
                      : isScanning ? _green
                      : Colors.grey.shade400,
                ),
              ),
              if (isScanning)
                AnimatedBuilder(
                  animation: _scanLine,
                  builder: (_, __) => Positioned(
                    top: 12 + (_scanLine.value * 76),
                    left: 12, right: 12,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Colors.transparent,
                          _green.withOpacity(0.85),
                          Colors.transparent,
                        ]),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              key: ValueKey(s),
              isSuccess ? "Face ID Registered!"
                  : isFailed ? "Capture Failed — Try Again"
                  : isScanning ? "Capturing…"
                  : "Register Your Face ID",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                  color: isSuccess ? _green
                      : isFailed ? const Color(0xFFE53935)
                      : const Color(0xFF1B1B1B)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSuccess
                ? "Face ID saved. Synced with server ✓"
                : isScanning
                    ? "Hold still, look straight at the camera…"
                    : isFailed
                        ? "Ensure good lighting and try again."
                        : "Your front camera captures your face\nfor secure, contactless attendance.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13,
                color: Colors.grey.shade500, height: 1.5),
          ),
          if (!isScanning && !isSuccess) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.light_mode_outlined,
                    color: Color(0xFFF57C00), size: 14),
                const SizedBox(width: 6),
                Text("Good lighting improves recognition accuracy",
                    style: TextStyle(fontSize: 11,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
          if (!isSuccess) ...[
            const SizedBox(height: 24),
            _PrimaryBtn(
              label:   isScanning ? "Capturing…"
                  : isFailed ? "Try Again"
                  : "Open Camera & Capture",
              icon:    Icons.camera_alt_rounded,
              onTap:   isScanning ? null : widget.onRegister,
              loading: isScanning,
            ),
            const SizedBox(height: 12),
            _SkipBtn(onTap: widget.onSkip),
          ],
        ]),
      ),
      const SizedBox(height: 36),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 3 — SUCCESS
// ─────────────────────────────────────────────────────────────────────────────

class _SuccessStep extends StatelessWidget {
  final bool biometricDone, faceIdDone, isLoading;
  final VoidCallback onFinish;
  static const _green        = Color(0xFF2E7D32);
  static const _greenSurface = Color(0xFFE8F5E9);

  const _SuccessStep({
    required this.biometricDone,
    required this.faceIdDone,
    required this.isLoading,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: _green.withOpacity(0.09),
              blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Column(children: [
          Container(
            width: 96, height: 96,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: _greenSurface),
            child: const Icon(Icons.verified_rounded, color: _green, size: 52),
          ),
          const SizedBox(height: 20),
          const Text("You're All Set!",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                  color: Color(0xFF1B1B1B))),
          const SizedBox(height: 8),
          Text("Account created successfully for\nMurang'a University of Technology.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade500, height: 1.5)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              _SummaryRow(icon: Icons.person_rounded,
                  label: "Account", value: "Registered", done: true),
              const Divider(height: 20, color: Color(0xFFEEEEEE)),
              _SummaryRow(icon: Icons.fingerprint_rounded,
                  label: "Fingerprint",
                  value: biometricDone ? "Registered" : "Skipped",
                  done: biometricDone),
              const Divider(height: 20, color: Color(0xFFEEEEEE)),
              _SummaryRow(icon: Icons.face_retouching_natural,
                  label: "Face ID",
                  value: faceIdDone ? "Registered" : "Skipped",
                  done: faceIdDone),
            ]),
          ),
          if (!biometricDone || !faceIdDone) ...[
            const SizedBox(height: 14),
            Text("Skipped methods can be added in Settings anytime.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400,
                    fontStyle: FontStyle.italic)),
          ],
        ]),
      ),
      const SizedBox(height: 24),
      _AnimatedButton(isLoading: isLoading, onPressed: onFinish,
          label: "Go to Dashboard"),
      const SizedBox(height: 36),
    ]);
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final bool done;
  static const _green = Color(0xFF2E7D32);

  const _SummaryRow({required this.icon, required this.label,
      required this.value, required this.done});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
            color: done ? const Color(0xFFE8F5E9) : const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16,
            color: done ? _green : Colors.grey.shade400),
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
              color: Color(0xFF1B1B1B)))),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: done ? const Color(0xFFE8F5E9) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(10)),
        child: Text(value,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: done ? _green : Colors.grey.shade400)),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final Size size;
  final bool isSmall;
  final int step;
  static const _green    = Color(0xFF2E7D32);
  static const _greenMid = Color(0xFF388E3C);

  const _Header({required this.size, required this.isSmall, required this.step});

  String get _subtitle => const [
    "Create Your Account",
    "Register Fingerprint",
    "Register Face ID",
    "Registration Complete",
  ][step.clamp(0, 3)];

  IconData get _icon => const [
    Icons.school_rounded,
    Icons.fingerprint_rounded,
    Icons.face_retouching_natural,
    Icons.verified_rounded,
  ][step.clamp(0, 3)];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: isSmall ? 190 : 230,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            colors: [_green, _greenMid, Color(0xFF43A047)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(48),
            bottomRight: Radius.circular(48)),
      ),
      child: Stack(children: [
        Positioned(top: -30, right: -30,
            child: Container(width: 120, height: 120,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06)))),
        Positioned(bottom: 20, left: -20,
            child: Container(width: 80, height: 80,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05)))),
        Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 16, offset: const Offset(0, 6))]),
              child: CircleAvatar(
                radius: isSmall ? 32 : 40,
                backgroundColor: const Color(0xFFE8F5E9),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Icon(_icon, key: ValueKey(step),
                      size: isSmall ? 32 : 40, color: _green),
                ),
              ),
            ),
            SizedBox(height: isSmall ? 10 : 14),
            Text("Murang'a University",
                style: TextStyle(fontSize: isSmall ? 19 : 23,
                    fontWeight: FontWeight.w800, color: Colors.white,
                    letterSpacing: 0.4)),
            const SizedBox(height: 4),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: Text(_subtitle, key: ValueKey(step),
                  style: TextStyle(fontSize: isSmall ? 12 : 13,
                      color: Colors.white.withOpacity(0.85))),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS  (unchanged from original)
// ─────────────────────────────────────────────────────────────────────────────

class _PrimaryBtn extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool loading;
  const _PrimaryBtn({required this.label, required this.icon,
      required this.onTap, this.loading = false});
  @override
  State<_PrimaryBtn> createState() => _PrimaryBtnState();
}

class _PrimaryBtnState extends State<_PrimaryBtn> {
  bool _pressed = false;
  static const _green = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [_green, Color(0xFF43A047)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(
                color: _green.withOpacity(_pressed ? 0.2 : 0.3),
                blurRadius: _pressed ? 8 : 14,
                offset: const Offset(0, 5))],
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: widget.loading
                  ? const SizedBox(key: ValueKey('l'), width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Row(key: const ValueKey('t'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(widget.icon, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(widget.label, style: const TextStyle(
                            color: Colors.white, fontSize: 15,
                            fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                      ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkipBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _SkipBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200, width: 1.5)),
        child: Center(
          child: Text("Skip for now",
              style: TextStyle(color: Colors.grey.shade500,
                  fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

class _AnimatedField extends StatefulWidget {
  final int delay;
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final TextInputType keyboardType;
  final bool obscure;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const _AnimatedField({
    required this.delay,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.obscure = false,
    this.suffixIcon,
    this.validator,
  });

  @override
  State<_AnimatedField> createState() => _AnimatedFieldState();
}

class _AnimatedFieldState extends State<_AnimatedField>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  bool _focused = false;
  static const _green = Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 500));
    _fade  = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: widget.delay),
        () { if (mounted) _c.forward(); });
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: Focus(
          onFocusChange: (v) => setState(() => _focused = v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: _focused
                  ? [BoxShadow(color: _green.withOpacity(0.15),
                      blurRadius: 12, offset: const Offset(0, 4))]
                  : [],
            ),
            child: TextFormField(
              controller: widget.controller,
              obscureText: widget.obscure,
              keyboardType: widget.keyboardType,
              validator: widget.validator,
              style: const TextStyle(fontSize: 15,
                  fontWeight: FontWeight.w500, color: Color(0xFF1B1B1B)),
              decoration: InputDecoration(
                labelText: widget.label,
                hintText:  widget.hint,
                hintStyle: TextStyle(
                    color: Colors.grey.shade400, fontSize: 13),
                labelStyle: TextStyle(
                    color: _focused ? _green : Colors.grey.shade500,
                    fontSize: 14, fontWeight: FontWeight.w500),
                prefixIcon: Icon(widget.icon,
                    color: _focused ? _green : Colors.grey.shade400, size: 20),
                suffixIcon: widget.suffixIcon,
                filled: true,
                fillColor: _focused
                    ? const Color(0xFFF1F8E9)
                    : const Color(0xFFF7F7F7),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                        color: Colors.grey.shade200, width: 1.5)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _green, width: 2)),
                errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: Color(0xFFE53935), width: 1.5)),
                focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: Color(0xFFE53935), width: 2)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  final String label;

  const _AnimatedButton({required this.isLoading,
      required this.onPressed, required this.label});
  @override
  State<_AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<_AnimatedButton> {
  bool _pressed = false;
  static const _green = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.isLoading ? null : widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_green,
                Color.lerp(_green, const Color(0xFF66BB6A), 0.5)!],
              begin: Alignment.centerLeft,
              end:   Alignment.centerRight),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(
                color: _green.withOpacity(_pressed ? 0.2 : 0.35),
                blurRadius: _pressed ? 8 : 16,
                offset: const Offset(0, 6))],
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: widget.isLoading
                  ? const SizedBox(key: ValueKey('loader'), width: 24, height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Row(key: const ValueKey('text'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(widget.label, style: const TextStyle(
                            color: Colors.white, fontSize: 16,
                            fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 18),
                      ]),
            ),
          ),
        ),
      ),
    );
  }
}