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

  /// Checks if the text contains any profane words.
  static bool hasProfanity(String text) {
    if (text.isEmpty) return false;
    final words = text.toLowerCase().split(RegExp(r'\s+'));
    return words.any((word) => _blacklist.contains(word));
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
}
