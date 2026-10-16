import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart';

class ApiClient {
  /// Base URL for the ABUAD backend API (Cloudflare R2 & Express server).
  static String baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.abuadapp.com.ng/api',
  );

  static String? _accessToken;
  static String? _refreshToken;

  static String? get accessToken => _accessToken;

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
    Future<http.Response> Function() requestFn, {
    bool canRetry = true,
  }) async {
    await ensureTokensLoaded();
    var response = await requestFn();
    if (canRetry &&
        response.statusCode == 401 &&
        _refreshToken != null &&
        _refreshToken!.isNotEmpty) {
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

  static Future<http.Response> get(String endpoint, {bool? canRetry}) async {
    final retry = canRetry ?? !endpoint.startsWith('/auth/');
    return _sendWithRetry(
      () => http.get(Uri.parse('$baseUrl$endpoint'), headers: _getHeaders()),
      canRetry: retry,
    );
  }

  static Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool? canRetry,
  }) async {
    final retry = canRetry ?? !endpoint.startsWith('/auth/');
    return _sendWithRetry(
      () => http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(),
        body: jsonEncode(body),
      ),
      canRetry: retry,
    );
  }

  static Future<http.Response> put(
    String endpoint,
    Map<String, dynamic> body, {
    bool? canRetry,
  }) async {
    final retry = canRetry ?? !endpoint.startsWith('/auth/');
    return _sendWithRetry(
      () => http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(),
        body: jsonEncode(body),
      ),
      canRetry: retry,
    );
  }

  static Future<http.Response> patch(
    String endpoint,
    Map<String, dynamic> body, {
    bool? canRetry,
  }) async {
    final retry = canRetry ?? !endpoint.startsWith('/auth/');
    return _sendWithRetry(
      () => http.patch(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(),
        body: jsonEncode(body),
      ),
      canRetry: retry,
    );
  }

  static Future<http.Response> delete(
    String endpoint, [
    Map<String, dynamic>? body,
    bool? canRetry,
  ]) async {
    final retry = canRetry ?? !endpoint.startsWith('/auth/');
    return _sendWithRetry(
      () => http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(),
        body: body != null ? jsonEncode(body) : null,
      ),
      canRetry: retry,
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

      // 1. Attempt high-speed direct upload to Cloudflare R2 via presigned URL
      // This bypasses Nginx payload size limits and prevents "Failed to fetch" on large videos/media
      try {
        final presignedRes = await post('/media/presigned-url', {
          'filename': safeFilename,
          'contentType': contentType,
        });

        if (presignedRes.statusCode == 200) {
          final pData = jsonDecode(presignedRes.body);
          if (pData['success'] == true && pData['data'] != null) {
            final uploadUrl = pData['data']['uploadUrl'] as String?;
            final publicUrl = pData['data']['publicUrl'] as String?;
            if (uploadUrl != null && publicUrl != null) {
              final putRes = await http.put(
                Uri.parse(uploadUrl),
                headers: {'Content-Type': contentType},
                body: bytes,
              ).timeout(const Duration(seconds: 10));
              if (putRes.statusCode >= 200 && putRes.statusCode < 300) {
                return publicUrl;
              }
            }
          }
        }
      } catch (presignedErr) {
        debugPrint('Presigned upload failed, falling back to direct multipart: $presignedErr');
      }

      // 2. Fallback to backend multipart upload route
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

  static VoidCallback? onSessionExpired;
  static Future<bool>? _activeRefreshFuture;

  /// Refresh JWT Access Token automatically with mutex deduplication
  static Future<bool> refreshToken() async {
    if (_activeRefreshFuture != null) {
      return _activeRefreshFuture!;
    }

    _activeRefreshFuture = _performTokenRefresh();
    try {
      final success = await _activeRefreshFuture!;
      return success;
    } finally {
      _activeRefreshFuture = null;
    }
  }

  static Future<bool> _performTokenRefresh() async {
    await ensureTokensLoaded();
    if (_refreshToken == null || _refreshToken!.isEmpty) {
      return false;
    }
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': _refreshToken}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final newAccess = data['data']['accessToken'] as String?;
          final newRefresh = data['data']['refreshToken'] as String?;
          if (newAccess != null && newAccess.isNotEmpty) {
            await setTokens(
              accessToken: newAccess,
              refreshToken: newRefresh ?? _refreshToken,
            );
            return true;
          }
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint(
          '⚠️ Refresh token rejected (status ${response.statusCode}). Session expired.',
        );
        await clearTokens();
        onSessionExpired?.call();
        return false;
      } else {
        debugPrint(
          '⚠️ Refresh token server error ${response.statusCode}. Retaining credentials.',
        );
        return false;
      }
    } catch (e) {
      debugPrint('⚠️ Refresh token network error: $e. Retaining credentials.');
      return false;
    }

    return false;
  }

  // ── Convenience helpers ───────────────────────────────────────────────────

  static bool get isAuthenticated => _accessToken != null;
}
