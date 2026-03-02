// lib/core/services/api_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Centralised HTTP client for MUT SmartTrack.
//
// BASE URL QUICK REFERENCE:
//   Flutter Web (Chrome)        → http://localhost:5000   ← YOUR CURRENT SETUP
//   Android Emulator            → http://10.0.2.2:5000
//   iOS Simulator               → http://localhost:5000
//   Physical Android/iOS device → http://<YOUR_LAN_IP>:5000
//
// pubspec.yaml dependencies:
//   http: ^1.2.1
//   shared_preferences: ^2.2.3
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ── Result wrapper ────────────────────────────────────────────────────────────

class ApiResult<T> {
  final bool success;
  final T? data;
  final String? error;

  const ApiResult.ok(this.data)
      : success = true,
        error = null;

  const ApiResult.err(this.error)
      : success = false,
        data = null;
}

// ── Service ───────────────────────────────────────────────────────────────────

class ApiService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // ── Base URL (auto-detected by platform) ───────────────────────────────────
  // Physical device: replace with your machine's LAN IP, e.g. 192.168.1.5
  static const String _lanIp = '192.168.1.5'; // ← change for physical device

  static String get baseUrl {
    if (kIsWeb) {
      // Flutter Web in Chrome — same machine as the backend
      return 'http://localhost:5000';
    }
    // Android Emulator routes host machine via 10.0.2.2
    // iOS Simulator can use localhost directly
    // Uncomment the relevant line:
    return 'http://10.0.2.2:5000';              // Android emulator
    // return 'http://localhost:5000';           // iOS simulator
    // return 'http://$_lanIp:5000';            // Physical device
  }

  // ── Storage keys ───────────────────────────────────────────────────────────
  static const _tokenKey = 'auth_token';
  static const _userKey  = 'auth_user';

  // ── Token helpers ──────────────────────────────────────────────────────────

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
  }

  Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  Future<bool> get isLoggedIn async => (await getToken()) != null;

  // ── Headers ────────────────────────────────────────────────────────────────

  Map<String, String> get _jsonHeaders => {'Content-Type': 'application/json'};

  Future<Map<String, String>> get _authHeaders async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── POST /api/auth/signup ─────────────────────────────────────────────────

  Future<ApiResult<Map<String, dynamic>>> signup({
    required String fullName,
    required String registrationNumber,
    required String email,
    required String password,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/auth/signup');
      debugPrint('[API] POST $uri');

      final res = await http
          .post(
            uri,
            headers: _jsonHeaders,
            body: jsonEncode({
              'fullName': fullName,
              'registrationNumber': registrationNumber,
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('[API] signup → ${res.statusCode}: ${res.body}');
      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200 || res.statusCode == 201) {
        final token = body['token'] as String?;
        final user  = body['user']  as Map<String, dynamic>?;
        if (token != null) await saveToken(token);
        if (user  != null) await saveUser(user);
        return ApiResult.ok(body);
      }

      return ApiResult.err(
          body['message'] as String? ?? 'Signup failed (${res.statusCode})');
    } on Exception catch (e) {
      debugPrint('[API] signup error: $e');
      return ApiResult.err(_friendlyError(e));
    }
  }

  // ── POST /api/auth/login ──────────────────────────────────────────────────

  Future<ApiResult<Map<String, dynamic>>> login({
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/auth/login');
      debugPrint('[API] POST $uri');

      final res = await http
          .post(
            uri,
            headers: _jsonHeaders,
            body: jsonEncode({
              'email': email,
              'password': password,
              'role': role,
            }),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('[API] login → ${res.statusCode}: ${res.body}');
      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200) {
        final token = body['token'] as String?;
        final user  = body['user']  as Map<String, dynamic>?;
        if (token != null) await saveToken(token);
        if (user  != null) await saveUser(user);
        return ApiResult.ok(body);
      }

      return ApiResult.err(
          body['message'] as String? ?? 'Login failed (${res.statusCode})');
    } on Exception catch (e) {
      debugPrint('[API] login error: $e');
      return ApiResult.err(_friendlyError(e));
    }
  }

  // ── POST /api/biometric/fingerprint ──────────────────────────────────────

  Future<ApiResult<Map<String, dynamic>>> registerFingerprint() async {
    try {
      final headers = await _authHeaders;
      final uri     = Uri.parse('$baseUrl/api/biometric/fingerprint');
      debugPrint('[API] POST $uri');

      final res = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({'biometricRegistered': true}),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('[API] fingerprint → ${res.statusCode}: ${res.body}');
      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200 || res.statusCode == 201) return ApiResult.ok(body);
      return ApiResult.err(body['message'] as String? ?? 'Fingerprint registration failed');
    } on Exception catch (e) {
      debugPrint('[API] fingerprint error: $e');
      return ApiResult.err(_friendlyError(e));
    }
  }

  // ── POST /api/biometric/faceid ────────────────────────────────────────────

  Future<ApiResult<Map<String, dynamic>>> registerFaceId({
    String? base64Image,
  }) async {
    try {
      final headers = await _authHeaders;
      final uri     = Uri.parse('$baseUrl/api/biometric/faceid');
      debugPrint('[API] POST $uri');

      final res = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              'faceRegistered': true,
              if (base64Image != null) 'image': base64Image,
            }),
          )
          .timeout(const Duration(seconds: 20));

      debugPrint('[API] faceid → ${res.statusCode}: ${res.body}');
      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200 || res.statusCode == 201) return ApiResult.ok(body);
      return ApiResult.err(body['message'] as String? ?? 'Face ID registration failed');
    } on Exception catch (e) {
      debugPrint('[API] faceid error: $e');
      return ApiResult.err(_friendlyError(e));
    }
  }

  // ── Friendly error messages ────────────────────────────────────────────────

  String _friendlyError(Exception e) {
    final msg = e.toString();
    if (msg.contains('SocketException') ||
        msg.contains('Connection refused') ||
        msg.contains('Network is unreachable') ||
        msg.contains('Failed host lookup')) {
      return 'Cannot reach server. Is it running on port 5000?';
    }
    if (msg.contains('TimeoutException')) {
      return 'Request timed out. Check your server is running.';
    }
    if (msg.contains('XMLHttpRequest') || msg.contains('CORS')) {
      return 'CORS error — see server fix instructions.';
    }
    return 'Error: $msg';
  }
}