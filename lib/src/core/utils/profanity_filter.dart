import '../services/moderation_service.dart';

class ProfanityFilter {
  static final List<String> _blacklist = [
    'fuck',
    'shit',
    'piss',
    'dick',
    'pussy',
    'asshole',
    'bitch',
    'bastard',
    'cunt',
    'nigger',
    'faggot',
    'slut',
    'whore',
    'motherfucker',
  ];

  /// Normalizes leetspeak and symbols to standard letters for robust matching
  static String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll('@', 'a')
        .replaceAll(r'$', 's')
        .replaceAll('0', 'o')
        .replaceAll('1', 'i')
        .replaceAll('!', 'i')
        .replaceAll('3', 'e')
        .replaceAll('5', 's');
  }

  /// Checks if the text contains any profane words (accounting for punctuation & leetspeak).
  static bool hasProfanity(String text) {
    if (text.isEmpty) return false;
    final normalized = _normalize(text);

    // 1. Check clean tokens with punctuation stripped
    final cleanTokens = normalized
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty);

    for (final word in cleanTokens) {
      if (_blacklist.contains(word)) return true;
    }

    // 2. Word boundary check
    for (final badWord in _blacklist) {
      final regExp = RegExp(r'\b' + RegExp.escape(badWord) + r'\b', caseSensitive: false);
      if (regExp.hasMatch(normalized)) return true;
    }

    return false;
  }

  /// Masks profane words in the text with asterisks.
  static String maskProfanity(String text) {
    if (text.isEmpty) return text;
    String maskedText = text;
    for (final word in _blacklist) {
      final regExp = RegExp(
        r'\b' + RegExp.escape(word) + r'\b',
        caseSensitive: false,
      );
      maskedText = maskedText.replaceAllMapped(regExp, (match) {
        return '*' * match.group(0)!.length;
      });
    }
    return maskedText;
  }

  /// Checks text safety via both local blacklist AND backend Gemini / Cloudflare AI moderation.
  /// Returns `true` if safe, `false` if violating policy.
  static Future<bool> isTextSafe(String text) async {
    if (text.trim().isEmpty) return true;
    // 1. Instant local pre-flight check
    if (hasProfanity(text)) return false;
    // 2. Connect to backend AI for contextual understanding, harassment, and safety policies
    return await ModerationService.isContentSafe(text);
  }

  /// Checks if media (image or video URL) is safe via Backend AI Vision moderation.
  /// Returns `true` if safe, `false` if violating policy.
  static Future<bool> isMediaSafe(String mediaUrl, {String mediaType = 'image'}) async {
    if (mediaUrl.trim().isEmpty) return true;
    return await ModerationService.isMediaSafe(mediaUrl, mediaType: mediaType);
  }

  /// Comprehensive all-in-one safety check for content (text + optional image/video media).
  static Future<bool> isContentSafe({
    String? text,
    String? mediaUrl,
    String mediaType = 'image',
  }) async {
    if (text != null && text.isNotEmpty) {
      final textSafe = await isTextSafe(text);
      if (!textSafe) return false;
    }
    if (mediaUrl != null && mediaUrl.isNotEmpty) {
      final mediaSafe = await isMediaSafe(mediaUrl, mediaType: mediaType);
      if (!mediaSafe) return false;
    }
    return true;
  }
}
