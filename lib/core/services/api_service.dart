// lib/core/services/api_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ApiResult — wraps every response so callers never deal with try/catch
// ─────────────────────────────────────────────────────────────────────────────

class ApiResult<T> {
  final bool    success;
  final T?      data;
  final String? error;

  const ApiResult.ok(this.data)   : success = true,  error = null;
  const ApiResult.err(this.error) : success = false,  data  = null;
}

// ─────────────────────────────────────────────────────────────────────────────
// ApiService — singleton HTTP client
// ─────────────────────────────────────────────────────────────────────────────

class ApiService {
  ApiService._();
  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;

  // ── Base URL ────────────────────────────────────────────────────────────────
  // Flutter Web            → localhost:5000
  // Android emulator       → 10.0.2.2:5000
  // Physical device / LAN  → change _lanIp below
  static const String _lanIp = '192.168.1.5';

  static String get baseUrl {
    if (kIsWeb) return 'https://smart-attendance-system-necx.onrender.com';
    return 'http://10.0.2.2:5000';
    // return 'http://localhost:5000';      // iOS simulator
    // return 'http://$_lanIp:5000';        // physical device
  }

  // ── SharedPreferences keys ──────────────────────────────────────────────────
  static const String _tokenKey = 'auth_token';
  static const String _userKey  = 'auth_user';

  // ── Token / session helpers ─────────────────────────────────────────────────

  Future<String?> getToken() async =>
      (await SharedPreferences.getInstance()).getString(_tokenKey);

  Future<void> saveToken(String token) async =>
      (await SharedPreferences.getInstance()).setString(_tokenKey, token);

  Future<void> saveUser(Map<String, dynamic> user) async =>
      (await SharedPreferences.getInstance())
          .setString(_userKey, jsonEncode(user));

  Future<Map<String, dynamic>?> getUser() async {
    final raw = (await SharedPreferences.getInstance()).getString(_userKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  Future<bool> get isLoggedIn async => (await getToken()) != null;

  // ── HTTP headers ────────────────────────────────────────────────────────────

  static const Map<String, String> _jsonHeaders = {
    'Content-Type': 'application/json',
  };

  Future<Map<String, String>> get _authHeaders async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Internal helpers ────────────────────────────────────────────────────────

  /// Decodes the response and returns an [ApiResult].
  ApiResult<Map<String, dynamic>> _handle(http.Response res) {
    debugPrint('[API] ${res.request?.method} ${res.request?.url} → ${res.statusCode}');
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return ApiResult.ok(body);
      }
      final msg = body['message'] as String? ?? 'Error ${res.statusCode}';
      return ApiResult.err(msg);
    } catch (_) {
      return ApiResult.err('Unexpected response from server');
    }
  }

  String _friendlyError(Exception e) {
    final s = e.toString();
    if (s.contains('SocketException') ||
        s.contains('Connection refused') ||
        s.contains('Failed host lookup')) {
      return 'Cannot reach server. Is it running on port 5000?';
    }
    if (s.contains('TimeoutException')) {
      return 'Request timed out. Check your server.';
    }
    if (s.contains('XMLHttpRequest') || s.contains('CORS')) {
      return 'CORS error. Check server configuration.';
    }
    return 'Unexpected error: $s';
  }

  // ── POST /api/auth/signup ───────────────────────────────────────────────────

  Future<ApiResult<Map<String, dynamic>>> signup({
    required String fullName,
    required String registrationNumber,
    required String email,
    required String password,
    String role = 'student',
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/auth/signup'),
            headers: _jsonHeaders,
            body: jsonEncode({
              'fullName':           fullName,
              'registrationNumber': registrationNumber,
              'email':              email,
              'password':           password,
              'role':               role,         // ← always included
            }),
          )
          .timeout(const Duration(seconds: 15));

      final result = _handle(res);
      if (result.success) {
        final token = result.data?['token'] as String?;
        final user  = result.data?['user']  as Map<String, dynamic>?;
        if (token != null) await saveToken(token);
        if (user  != null) await saveUser(user);
      }
      return result;
    } on Exception catch (e) {
      return ApiResult.err(_friendlyError(e));
    }
  }

  // ── POST /api/auth/login ────────────────────────────────────────────────────

  Future<ApiResult<Map<String, dynamic>>> login({
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/auth/login'),
            headers: _jsonHeaders,
            body: jsonEncode({
              'email':    email,
              'password': password,
              'role':     role,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final result = _handle(res);
      if (result.success) {
        final token = result.data?['token'] as String?;
        final user  = result.data?['user']  as Map<String, dynamic>?;
        if (token != null) await saveToken(token);
        if (user  != null) await saveUser(user);
      }
      return result;
    } on Exception catch (e) {
      return ApiResult.err(_friendlyError(e));
    }
  }

  // ── POST /api/biometric/fingerprint ────────────────────────────────────────

  Future<ApiResult<Map<String, dynamic>>> registerFingerprint() async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/biometric/fingerprint'),
            headers: await _authHeaders,
            body: jsonEncode({'biometricRegistered': true}),
          )
          .timeout(const Duration(seconds: 15));
      return _handle(res);
    } on Exception catch (e) {
      return ApiResult.err(_friendlyError(e));
    }
  }

  // ── POST /api/biometric/faceid ──────────────────────────────────────────────

  Future<ApiResult<Map<String, dynamic>>> registerFaceId({
    String? base64Image,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/biometric/faceid'),
            headers: await _authHeaders,
            body: jsonEncode({
              'faceRegistered': true,
              if (base64Image != null) 'image': base64Image,
            }),
          )
          .timeout(const Duration(seconds: 20));
      return _handle(res);
    } on Exception catch (e) {
      return ApiResult.err(_friendlyError(e));
    }
  }
}