import 'package:flutter/material.dart';
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

    return AbuadMarkdownContent(
      content: content,
      textStyle: defaultStyle,
      maxLines: maxLines,
      enableImages: true,
      enableCodeBlocks: true,
    );
  }
}
