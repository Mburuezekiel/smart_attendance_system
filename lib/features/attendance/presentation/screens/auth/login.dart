// lib/features/auth/presentation/login_page.dart
//
// API-integrated login page.
// Calls POST /api/auth/login → saves JWT → navigates to /home
// ─────────────────────────────────────────────────────────────────────────────

import 'package:edutrack_mut/core/usecases/role.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/services/api_service.dart'; 

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  UserRole _selectedRole = RoleManager().currentRole;

  // ── Controllers ────────────────────────────────────────────────────────────
  final _emailController = TextEditingController();
  final _passController  = TextEditingController();
  final _formKey         = GlobalKey<FormState>();

  // ── State ──────────────────────────────────────────────────────────────────
  bool    _isLoading      = false;
  bool    _obscurePass    = true;
  String? _errorMessage;

  // ── API ────────────────────────────────────────────────────────────────────
  final _api = ApiService();

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  // ── Login handler ──────────────────────────────────────────────────────────
  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() { _isLoading = true; _errorMessage = null; });

    final result = await _api.login(
      email:    _emailController.text.trim(),
      password: _passController.text,
      role:     _selectedRole.name, // "student" | "lecturer" | "admin"
    );

    if (!mounted) return;

    if (result.success) {
      // Update global role from server response if provided
      final serverRole = result.data?['user']?['role'] as String?;
      if (serverRole != null) {
        final matched = UserRole.values
            .where((r) => r.name == serverRole)
            .firstOrNull;
        if (matched != null) RoleManager().setRole(matched);
      }
      context.go('/home');
    } else {
      setState(() {
        _isLoading    = false;
        _errorMessage = result.error;
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.green.shade600;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: Column(children: [
          // ── Header ─────────────────────────────────────────────────────────
          Container(
            height: 250,
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: const BorderRadius.only(
                bottomLeft:  Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle),
                    child: CircleAvatar(
                      radius: 45,
                      backgroundColor: const Color(0xFFE0E0E0),
                      child: Icon(Icons.person, size: 45,
                          color: primaryColor),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text("Welcome Back",
                      style: TextStyle(fontSize: 28,
                          fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  const Text("Sign in to continue",
                      style: TextStyle(fontSize: 16, color: Colors.white70)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),

          // ── Form ───────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  // ── Error banner ────────────────────────────────────────────
                  if (_errorMessage != null) ...[
                    _ErrorBanner(
                      message: _errorMessage!,
                      onDismiss: () =>
                          setState(() => _errorMessage = null),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Email ───────────────────────────────────────────────────
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                        v != null && v.contains('@') ? null : "Invalid email",
                    decoration: InputDecoration(
                      labelText: "Email Address",
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade500)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: primaryColor, width: 2)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Password ────────────────────────────────────────────────
                  TextFormField(
                    controller: _passController,
                    obscureText: _obscurePass,
                    validator: (v) =>
                        v != null && v.isNotEmpty ? null : "Required",
                    decoration: InputDecoration(
                      labelText: "Password",
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePass
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () =>
                            setState(() => _obscurePass = !_obscurePass),
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade500)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: primaryColor, width: 2)),
                    ),
                  ),

                  // ── Forgot Password ─────────────────────────────────────────
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {},
                      child: Text("Forgot Password?",
                          style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── Role selector ───────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: UserRole.values.map((role) {
                      final isSelected = _selectedRole == role;
                      return ChoiceChip(
                        label: Text(role.name.toUpperCase()),
                        selected: isSelected,
                        selectedColor: primaryColor,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedRole = role);
                            RoleManager().setRole(role);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // ── Login button ────────────────────────────────────────────
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          primaryColor.withOpacity(0.7),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : const Text("Login",
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                  ),

                  const SizedBox(height: 30),

                  // ── Sign up link ────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account? ",
                          style: TextStyle(color: Colors.grey)),
                      GestureDetector(
                        onTap: () => context.go('/signup'),
                        child: Text("Sign Up",
                            style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
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
        border: Border.all(
            color: const Color(0xFFE53935).withOpacity(0.4)),
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