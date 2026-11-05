import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'abuad_markdown.dart';

class FormattedCommentContent extends StatelessWidget {
  final String content;
  final TextStyle? textStyle;
  final int? maxLines;

  const FormattedCommentContent({
    super.key,
    required this.content,
    this.textStyle,
    this.maxLines,
  });

  static final RegExp _imageRegex = RegExp(r'!\[(.*?)\]\((.*?)\)');

  @override
  Widget build(BuildContext context) {
    if (content.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = textStyle?.color ?? (isDark ? Colors.white : const Color(0xFF0F172A));
    final defaultStyle = TextStyle(
      fontSize: 14.5,
      height: 1.35,
      color: effectiveColor,
    ).merge(textStyle);

    final match = _imageRegex.firstMatch(content);
    if (match != null) {
      final imageUrl = match.group(2)?.trim() ?? '';
      final textOnly = content.replaceAll(_imageRegex, '').trim();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (textOnly.isNotEmpty)
            AbuadMarkdownContent(
              content: textOnly,
              textStyle: defaultStyle,
              maxLines: maxLines,
              enableImages: false,
              enableCodeBlocks: true,
            ),
          if (imageUrl.isNotEmpty) ...[
            if (textOnly.isNotEmpty) const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 190,
                  maxHeight: 190,
                ),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => Container(
                    width: 140,
                    height: 140,
                    color: isDark ? Colors.white10 : Colors.black12,
                    child: const Center(
                      child: CupertinoActivityIndicator(radius: 8),
                    ),
                  ),
                  errorWidget: (context, url, error) => const Icon(
                    Icons.sticky_note_2_rounded,
                    size: 28,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ],
        ],
      );
    }

    return AbuadMarkdownContent(
      content: content,
      textStyle: defaultStyle,
      maxLines: maxLines,
      enableImages: true,
      enableCodeBlocks: true,
    );
  }
}
