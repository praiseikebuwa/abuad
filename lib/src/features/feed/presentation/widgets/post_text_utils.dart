/// Utility methods to handle smart shortening and clamping of long post content.
class PostTextUtils {
  /// Checks whether a post's content should be considered "long" in the feed card.
  static bool isContentLong(
    String text, {
    int maxChars = 320,
    int maxLines = 5,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.length > maxChars) return true;

    final lines = trimmed.split('\n');
    if (lines.length > maxLines) return true;

    return false;
  }

  /// Checks whether a post in detail screen is "longer than long again" (extraordinarily long story/article).
  static bool isContentExtraLong(
    String text, {
    int maxChars = 850,
    int maxLines = 10,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.length > maxChars) return true;

    final lines = trimmed.split('\n');
    if (lines.length > maxLines) return true;

    return false;
  }

  /// Shortens post text to approximately [maxChars] or [maxLines], breaking at clean word/line boundaries
  /// and sanitizing any unclosed markdown tags.
  static String truncatePostContent(
    String text, {
    int maxChars = 280,
    int maxLines = 4,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return trimmed;

    final lines = trimmed.split('\n');
    final selectedLines = <String>[];
    int currentChars = 0;
    bool wasTruncated = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Exceeded max lines
      if (i >= maxLines) {
        wasTruncated = true;
        break;
      }

      // Check if adding this line exceeds character limit
      if (currentChars + line.length > maxChars) {
        final remaining = maxChars - currentChars;
        if (remaining > 30) {
          final sub = line.substring(0, remaining);
          final lastSpace = sub.lastIndexOf(' ');
          final cut = (lastSpace > 15) ? sub.substring(0, lastSpace) : sub;
          selectedLines.add(cut.trimRight());
        } else if (selectedLines.isEmpty) {
          selectedLines.add(line.substring(0, maxChars).trimRight());
        }
        wasTruncated = true;
        break;
      }

      selectedLines.add(line);
      currentChars += line.length + 1; // +1 for newline
    }

    if (!wasTruncated && trimmed.length > maxChars) {
      final sub = trimmed.substring(0, maxChars);
      final lastSpace = sub.lastIndexOf(' ');
      final cut = (lastSpace > 20) ? sub.substring(0, lastSpace) : sub;
      return _closeMarkdownTags(cut.trimRight(), appendEllipsis: true);
    }

    if (wasTruncated) {
      final joined = selectedLines.join('\n').trimRight();
      return _closeMarkdownTags(joined, appendEllipsis: true);
    }

    return trimmed;
  }

  /// Sanitizes unclosed markdown tags so markdown parsing doesn't bleed across truncation boundaries.
  static String _closeMarkdownTags(String content, {bool appendEllipsis = true}) {
    var result = content;

    // Remove any trailing ellipsis if already present
    while (result.endsWith('.')) {
      result = result.substring(0, result.length - 1);
    }
    result = result.trimRight();

    // Check code blocks
    final codeBlockMatches = RegExp(r'```').allMatches(result).length;
    final needsCodeBlockClose = codeBlockMatches % 2 != 0;

    // Check inline code
    final inlineCodeMatches = RegExp(r'`').allMatches(result).length - (codeBlockMatches * 3);
    final needsInlineCodeClose = inlineCodeMatches % 2 != 0;

    // Check bold **
    final boldMatches = RegExp(r'\*\*').allMatches(result).length;
    final needsBoldClose = boldMatches % 2 != 0;

    // Check italic * (excluding **)
    final starCount = RegExp(r'\*').allMatches(result).length;
    final italicStarCount = starCount - (boldMatches * 2);
    final needsStarClose = italicStarCount % 2 != 0;

    // Check italic _
    final underscoreCount = RegExp(r'_').allMatches(result).length;
    final needsUnderscoreClose = underscoreCount % 2 != 0;

    if (needsInlineCodeClose) result = '$result`';
    if (needsBoldClose) result = '$result**';
    if (needsStarClose) result = '$result*';
    if (needsUnderscoreClose) result = '${result}_';
    if (needsCodeBlockClose) result = '$result\n```';

    if (appendEllipsis) {
      result = '$result...';
    }

    return result;
  }
}
