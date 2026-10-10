import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart';

class ApiClient {
  /// Base URL for the ABUAD backend API (Cloudflare R2 & Express server).
  static String baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://abuad-backend-elfz.onrender.com/api',
  );

  static String? _accessToken;
  static String? _refreshToken;

  static Future<void> setTokens({
    String? accessToken,
    String? refreshToken,
  }) async {
    if (accessToken != null) _accessToken = accessToken;
    if (refreshToken != null) _refreshToken = refreshToken;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (accessToken != null) {
        await prefs.setString('accessToken', accessToken);
      }
      if (refreshToken != null) {
        await prefs.setString('refreshToken', refreshToken);
      }
    } catch (_) {}
  }

  static Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('accessToken');
      await prefs.remove('refreshToken');
    } catch (_) {}
  }

  static Future<void> ensureTokensLoaded() async {
    if (_accessToken == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        _accessToken = prefs.getString('accessToken');
        _refreshToken = prefs.getString('refreshToken');
      } catch (e) {
        debugPrint('ApiClient.ensureTokensLoaded error: $e');
      }
    }
  }

  static Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
    };
  }

  static Map<String, String> _getAuthHeader() {
    return {if (_accessToken != null) 'Authorization': 'Bearer $_accessToken'};
  }

  // ── Basic CRUD ────────────────────────────────────────────────────────────

  static Future<http.Response> _sendWithRetry(
    Future<http.Response> Function() requestFn,
  ) async {
    await ensureTokensLoaded();
    var response = await requestFn();
    if (response.statusCode == 401) {
      debugPrint(
        '🔑 Access token expired (401). Attempting automatic token refresh...',
      );
      final refreshed = await refreshToken();
      if (refreshed) {
        debugPrint('✅ Token refresh successful. Retrying request...');
        response = await requestFn();
      } else {
        debugPrint('❌ Token refresh failed. User session may have expired.');
      }
    }
    return response;
  }

  static Future<http.Response> get(String endpoint) async {
    return _sendWithRetry(
      () => http.get(Uri.parse('$baseUrl$endpoint'), headers: _getHeaders()),
    );
  }

  static Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    return _sendWithRetry(
      () => http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(),
        body: jsonEncode(body),
      ),
    );
  }

  static Future<http.Response> put(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    return _sendWithRetry(
      () => http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(),
        body: jsonEncode(body),
      ),
    );
  }

  static Future<http.Response> patch(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    return _sendWithRetry(
      () => http.patch(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(),
        body: jsonEncode(body),
      ),
    );
  }

  static Future<http.Response> delete(
    String endpoint, [
    Map<String, dynamic>? body,
  ]) async {
    return _sendWithRetry(
      () => http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(),
        body: body != null ? jsonEncode(body) : null,
      ),
    );
  }

  // ── Multipart file upload ─────────────────────────────────────────────────

  /// Upload a single file via multipart/form-data to /api/media/upload
  static Future<String?> uploadFile(
    String filePath, {
    String fieldName = 'file',
  }) async {
    try {
      Future<http.Response> doUpload() async {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/media/upload'),
        );
        request.headers.addAll(_getAuthHeader());
        request.files.add(
          await http.MultipartFile.fromPath(fieldName, filePath),
        );

        final streamed = await request.send();
        return http.Response.fromStream(streamed);
      }

      final response = await _sendWithRetry(doUpload);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data']['publicUrl'] as String?;
        }
      } else {
        debugPrint(
          'ApiClient.uploadFile failed: status ${response.statusCode}, body ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('ApiClient.uploadFile error: $e');
    }
    return null;
  }

  /// Upload raw bytes as multipart/form-data
  static Future<String?> uploadBytes(
    Uint8List bytes,
    String filename, {
    String contentType = 'application/octet-stream',
    String fieldName = 'file',
  }) async {
    try {
      if (bytes.isEmpty) {
        debugPrint('ApiClient.uploadBytes failed: bytes are empty');
        return null;
      }

      final safeFilename = filename.isNotEmpty && filename.contains('.')
          ? filename
          : 'upload_${DateTime.now().millisecondsSinceEpoch}.jpg';

      Future<http.Response> doUpload() async {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/media/upload'),
        );
        request.headers.addAll(_getAuthHeader());

        MediaType? parsedType;
        try {
          parsedType = MediaType.parse(contentType);
        } catch (_) {
          parsedType = MediaType('image', 'jpeg');
        }

        request.files.add(
          http.MultipartFile.fromBytes(
            fieldName,
            bytes,
            filename: safeFilename,
            contentType: parsedType,
          ),
        );

        final streamed = await request.send();
        return http.Response.fromStream(streamed);
      }

      final response = await _sendWithRetry(doUpload);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data']['publicUrl'] as String?;
        }
      } else {
        debugPrint(
          'ApiClient.uploadBytes failed: status ${response.statusCode}, body ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('ApiClient.uploadBytes error: $e');
    }
    return null;
  }

  // ── Token Management ──────────────────────────────────────────────────────

  /// Refresh JWT Access Token automatically when expired
  static Future<bool> refreshToken() async {
    await ensureTokensLoaded();
    if (_refreshToken == null || _refreshToken!.isEmpty) return false;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': _refreshToken}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final newAccess = data['data']['accessToken'] as String?;
          final newRefresh = data['data']['refreshToken'] as String?;
          if (newAccess != null) {
            await setTokens(accessToken: newAccess, refreshToken: newRefresh);
            return true;
          }
        }
      }
    } catch (e) {
      debugPrint('ApiClient.refreshToken error: $e');
    }
    await clearTokens();
    return false;
  }

  // ── Convenience helpers ───────────────────────────────────────────────────

  static bool get isAuthenticated => _accessToken != null;
}
