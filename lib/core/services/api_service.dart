import 'dart:convert';
import 'dart:typed_data';                          
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';    
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
  static const String _lanIp = '192.168.1.5';

  static String get baseUrl {
    if (kIsWeb) return 'https://smart-attendance-system-necx.onrender.com';
    return 'https://smart-attendance-system-necx.onrender.com';
    // return 'http://localhost:5000';
    // return 'http://$_lanIp:5000';
    // return 'http://10.0.2.2:5000';
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
    if (s.contains('TimeoutException')) return 'Request timed out. Check your server.';
    if (s.contains('XMLHttpRequest') || s.contains('CORS')) return 'CORS error. Check server configuration.';
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
              'role':               role,
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

  // ── GET (generic) ───────────────────────────────────────────────────────────

  Future<ApiResult<Map<String, dynamic>>> get(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    try {
      var uri = Uri.parse('$baseUrl/api$path');
      if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }
      final res = await http
          .get(uri, headers: await _authHeaders)
          .timeout(const Duration(seconds: 15));
      return _handle(res);
    } on Exception catch (e) {
      return ApiResult.err(_friendlyError(e));
    }
  }

  // ── DELETE (generic) ────────────────────────────────────────────────────────

  Future<ApiResult<Map<String, dynamic>>> delete(String path) async {
    try {
      final uri = Uri.parse('$baseUrl/api$path');
      final res = await http
          .delete(uri, headers: await _authHeaders)
          .timeout(const Duration(seconds: 15));
      return _handle(res);
    } on Exception catch (e) {
      return ApiResult.err(_friendlyError(e));
    }
  }

  // ── PATCH (generic) ─────────────────────────────────────────────────────────

  Future<ApiResult<Map<String, dynamic>>> patch(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final uri = Uri.parse('$baseUrl/api$path');
      final res = await http
          .patch(uri, headers: await _authHeaders, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      return _handle(res);
    } on Exception catch (e) {
      return ApiResult.err(_friendlyError(e));
    }
  }

  // ── POST (generic) ──────────────────────────────────────────────────────────

  Future<ApiResult<Map<String, dynamic>>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final uri = Uri.parse('$baseUrl/api$path');
      final res = await http
          .post(uri, headers: await _authHeaders, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
      return _handle(res);
    } on Exception catch (e) {
      return ApiResult.err(_friendlyError(e));
    }
  }

  // ── POST /api/units ─────────────────────────────────────────────────────────

  Future<ApiResult<Map<String, dynamic>>> createUnit({
    required String code,
    required String name,
    required String department,
    required int    year,
    required int    semester,
    String description = '',
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/units'),
            headers: await _authHeaders,
            body: jsonEncode({
              'code':        code,
              'name':        name,
              'department':  department,
              'year':        year,
              'semester':    semester,
              'description': description,
            }),
          )
          .timeout(const Duration(seconds: 15));
      return _handle(res);
    } on Exception catch (e) {
      return ApiResult.err(_friendlyError(e));
    }
  }

  // ── POST /api/assignments ───────────────────────────────────────────────────

  Future<ApiResult<Map<String, dynamic>>> createAssignment({
    required String      unitId,
    required String      lecturerId,
    required String      academicYear,
    required int         semester,
    List<String>         studentIds = const [],
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/assignments'),
            headers: await _authHeaders,
            body: jsonEncode({
              'unitId':       unitId,
              'lecturerId':   lecturerId,
              'academicYear': academicYear,
              'semester':     semester,
              'studentIds':   studentIds,
            }),
          )
          .timeout(const Duration(seconds: 15));
      return _handle(res);
    } on Exception catch (e) {
      return ApiResult.err(_friendlyError(e));
    }
  }

 Future<ApiResult<Map<String, dynamic>>> uploadFile(
    String path, {
    required Uint8List          fileBytes,
    required String             fileName,
    Map<String, String>         queryParams = const {},
    String                      fileField   = 'file',       // multipart field name
    Map<String, String>         extraFields = const {},     // extra text fields
  }) async {
    try {
      var uri = Uri.parse('$baseUrl/api$path');
      if (queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }
 
      final token = await getToken();
 
      // Build multipart request
      final request = http.MultipartRequest('POST', uri);
 
      // Auth header (no Content-Type — http sets it with boundary automatically)
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
 
      // Attach the file
      final mimeType = _mimeFromName(fileName);
      request.files.add(http.MultipartFile.fromBytes(
        fileField,
        fileBytes,
        filename: fileName,
        contentType: MediaType.parse(mimeType),
      ));
 
      // Any extra text fields the caller wants to send alongside the file
      request.fields.addAll(extraFields);
 
      debugPrint('[API] POST (multipart) $uri  file=$fileName  size=${fileBytes.length}b');
 
      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final res      = await http.Response.fromStream(streamed);
 
      return _handle(res);
    } on Exception catch (e) {
      return ApiResult.err(_friendlyError(e));
    }
  }
 
  /// Infer a MIME type from the file extension.
  static String _mimeFromName(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':  return 'application/pdf';
      case 'doc':  return 'application/msword';
      case 'docx': return 'application/vnd.openxmlformats-officedocument'
                          '.wordprocessingml.document';
      case 'png':  return 'image/png';
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      default:     return 'application/octet-stream';
    }
  }

  // ── POST /api/sessions ──────────────────────────────────────────────────────

  Future<ApiResult<Map<String, dynamic>>> createSession({
    required String assignmentId,
    int    durationMinutes = 15,
    String location        = '',
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/sessions'),
            headers: await _authHeaders,
            body: jsonEncode({
              'assignmentId':   assignmentId,
              'durationMinutes': durationMinutes,
              'location':       location,
            }),
          )
          .timeout(const Duration(seconds: 15));
      return _handle(res);
    } on Exception catch (e) {
      return ApiResult.err(_friendlyError(e));
    }
  }

  // ── POST /api/attendance ────────────────────────────────────────────────────

  Future<ApiResult<Map<String, dynamic>>> markAttendance({
    required String sessionToken,
    required bool   biometricVerified,
    required bool   faceVerified,
    required String digitalSignature,
    required String signedAt,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/attendance'),
            headers: await _authHeaders,
            body: jsonEncode({
              'sessionToken':      sessionToken,
              'biometricVerified': biometricVerified,
              'faceVerified':      faceVerified,
              'digitalSignature':  digitalSignature,
              'signedAt':          signedAt,
            }),
          )
          .timeout(const Duration(seconds: 15));
      return _handle(res);
    } on Exception catch (e) {
      return ApiResult.err(_friendlyError(e));
    }
  }

  

} // ← END OF ApiService class