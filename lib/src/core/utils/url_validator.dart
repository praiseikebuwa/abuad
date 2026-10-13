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

  static const String r2PublicBase = 'https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev';

  static String formatImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return '';
    var trimmed = url.trim();

    // If it points to any uploaded asset (from localhost:5000, Render, or relative path),
    // map it directly to Cloudflare R2 public CDN with CORS enabled
    final uploadIndex = trimmed.indexOf('uploads/');
    if (uploadIndex != -1) {
      return '$r2PublicBase/${trimmed.substring(uploadIndex)}';
    }

    // Upgrade insecure http:// to https:// to prevent browser Mixed Content errors on Web
    if (trimmed.startsWith('http://') && !trimmed.contains('localhost') && !trimmed.contains('127.0.0.1')) {
      trimmed = 'https://${trimmed.substring(7)}';
    }

    return trimmed;
  }
}
