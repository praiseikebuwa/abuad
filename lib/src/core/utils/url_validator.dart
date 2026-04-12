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
}
