import 'package:flutter/foundation.dart';
import '../services/api_client.dart';

class UrlValidator {
  /// Returns true if the [url] is a well-formed absolute URL with a host (authority).
  static bool isValidUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;

    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return false;

      // A valid network image URL must have a scheme (http/https) and a host.
      return uri.hasScheme && uri.hasAuthority;
    } catch (_) {
      return false;
    }
  }

  static String? extractFirstUrl(String text) {
    final match = RegExp(
      r'(https?:\/\/[^\s]+)|(www\.[^\s]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return null;
    return normalizeUrl(match.group(0));
  }

  static String? normalizeUrl(String? rawUrl) {
    if (rawUrl == null) return null;
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;

    final withScheme =
        trimmed.startsWith('http://') || trimmed.startsWith('https://')
        ? trimmed
        : 'https://$trimmed';

    return isValidUrl(withScheme) ? withScheme : null;
  }

  static String formatImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return '';
    var trimmed = url.trim();
    if (trimmed.startsWith('http://') && !trimmed.contains('localhost') && !trimmed.contains('127.0.0.1')) {
      trimmed = 'https://${trimmed.substring(7)}';
    }
    if (kIsWeb && (trimmed.contains('r2.dev/') || trimmed.contains('cloudflarestorage.com/'))) {
      final base = ApiClient.baseUrl;
      return '$base/media/proxy?url=${Uri.encodeComponent(trimmed)}';
    }
    return trimmed;
  }
}
