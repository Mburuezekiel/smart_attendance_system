// lib/features/auth/presentation/login_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/services/api_service.dart';

// Use the same UserRole enum from signup_page.dart
// If you extract it to a shared file (recommended), import from there.
enum _Role { student, lecturer, admin }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  _Role _selectedRole = _Role.student;

  final _emailController = TextEditingController();
  final _passController  = TextEditingController();
  final _formKey         = GlobalKey<FormState>();

  bool    _isLoading    = false;
  bool    _obscurePass  = true;
  String? _errorMessage;

  final _api = ApiService();

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  // ── Dashboard route per role ───────────────────────────────────────────────
  static String _dashboardRoute(String role) => switch (role) {
    'lecturer' => '/lecturer-home',
    'admin'    => '/admin-home',
    _          => '/home',           // student (default)
  };

  // ── Login ──────────────────────────────────────────────────────────────────
  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    final result = await _api.login(
      email:    _emailController.text.trim(),
      password: _passController.text,
      role:     _selectedRole.name,
    );

    if (!mounted) return;

    if (result.success) {
      final role = result.data?['user']?['role'] as String? ?? _selectedRole.name;
      context.go(_dashboardRoute(role));
    } else {
      setState(() { _isLoading = false; _errorMessage = result.error; });
    }
  }

  static const _green = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: Column(children: [
          // ── Header ─────────────────────────────────────────────────────────
          Container(
            height: 250,
            decoration: const BoxDecoration(
              color: _green,
              borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40)),
            ),
            child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const CircleAvatar(radius: 45, backgroundColor: Color(0xFFE0E0E0),
                    child: Icon(Icons.person, size: 45, color: _green))),
              const SizedBox(height: 16),
              const Text("Welcome Back", style: TextStyle(fontSize: 28,
                  fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              const Text("Sign in to continue",
                  style: TextStyle(fontSize: 16, color: Colors.white70)),
            ])),
          ),

          const SizedBox(height: 36),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

                // ── Error banner ────────────────────────────────────────────
                if (_errorMessage != null) ...[
                  _ErrorBanner(message: _errorMessage!,
                      onDismiss: () => setState(() => _errorMessage = null)),
                  const SizedBox(height: 16),
                ],

                // ── Role selector ───────────────────────────────────────────
                Text('Sign in as…', style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                Row(children: _Role.values.map((role) {
                  const icons = {
                    _Role.student:  (Icons.school_rounded,     '🎓', 'Student'),
                    _Role.lecturer: (Icons.person_pin_rounded,  '👨‍🏫', 'Lecturer'),
                    _Role.admin:    (Icons.shield_rounded,      '🛡️', 'Admin'),
                  };
                  final (_, emoji, label) = icons[role]!;
                  final isSelected = _selectedRole == role;
                  return Expanded(child: GestureDetector(
                    onTap: () => setState(() => _selectedRole = role),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? _green : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isSelected ? _green : Colors.grey.shade200,
                            width: isSelected ? 2 : 1.5),
                        boxShadow: isSelected ? [BoxShadow(color: _green.withOpacity(0.2),
                            blurRadius: 8, offset: const Offset(0, 3))] : [],
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(emoji, style: const TextStyle(fontSize: 18)),
                        const SizedBox(height: 2),
                        Text(label, style: TextStyle(fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : Colors.grey.shade600)),
                      ]),
                    ),
                  ));
                }).toList()),
                const SizedBox(height: 24),

                // ── Email ───────────────────────────────────────────────────
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v != null && v.contains('@') ? null : "Invalid email",
                  decoration: InputDecoration(
                    labelText: "Email Address",
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade400)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _green, width: 2)),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Password ────────────────────────────────────────────────
                TextFormField(
                  controller: _passController,
                  obscureText: _obscurePass,
                  validator: (v) => v != null && v.isNotEmpty ? null : "Required",
                  decoration: InputDecoration(
                    labelText: "Password",
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePass ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () => setState(() => _obscurePass = !_obscurePass),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade400)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _green, width: 2)),
                  ),
                ),

                Align(alignment: Alignment.centerRight,
                  child: TextButton(onPressed: () {},
                    child: const Text("Forgot Password?", style: TextStyle(
                        color: _green, fontWeight: FontWeight.w600)))),

                const SizedBox(height: 8),

                // ── Login button ────────────────────────────────────────────
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green, foregroundColor: Colors.white,
                    disabledBackgroundColor: _green.withOpacity(0.7),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text("Login", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),

                const SizedBox(height: 24),

                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text("Don't have an account? ",
                      style: TextStyle(color: Colors.grey)),
                  GestureDetector(onTap: () => context.go('/signup'),
                    child: const Text("Sign Up", style: TextStyle(
                        color: _green, fontWeight: FontWeight.bold))),
                ]),

                const SizedBox(height: 36),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message; final VoidCallback onDismiss;
  const _ErrorBanner({required this.message, required this.onDismiss});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE53935).withOpacity(0.4))),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded, color: Color(0xFFE53935), size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(message, style: const TextStyle(fontSize: 13,
          color: Color(0xFFB71C1C), fontWeight: FontWeight.w500))),
      GestureDetector(onTap: onDismiss,
          child: const Icon(Icons.close_rounded, color: Color(0xFFE53935), size: 18)),
    ]),
  );
}