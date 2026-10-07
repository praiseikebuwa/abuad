import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FormattedCommentContent extends StatelessWidget {
  final String content;
  final TextStyle? textStyle;

  const FormattedCommentContent({
    super.key,
    required this.content,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (content.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultStyle = textStyle ?? const TextStyle(fontSize: 14, height: 1.3);

    // Regex for markdown images: ![alt](url)
    final mdImageRegex = RegExp(r'!\[(.*?)\]\((https?://[^\s\)]+)\)');
    final matches = mdImageRegex.allMatches(content);

    if (matches.isEmpty) {
      // Check if the whole string or part of it is a raw image URL
      final rawImageRegex = RegExp(r'(https?://[^\s]+\.(?:png|jpg|jpeg|gif|webp)(?:\?[^\s]*)?|https?://image\.pollinations\.ai/[^\s]+)');
      final rawMatches = rawImageRegex.allMatches(content);

      if (rawMatches.isEmpty) {
        return Text(content, style: defaultStyle);
      }

      final List<Widget> children = [];
      int lastEnd = 0;

      for (final match in rawMatches) {
        if (match.start > lastEnd) {
          final textSegment = content.substring(lastEnd, match.start).trim();
          if (textSegment.isNotEmpty) {
            children.add(Text(textSegment, style: defaultStyle));
            children.add(const SizedBox(height: 8));
          }
        }

        final imageUrl = match.group(0);
        if (imageUrl != null && imageUrl.isNotEmpty) {
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (context, url) => Container(
                    height: 200,
                    color: isDark ? Colors.grey[900] : Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => const SizedBox(),
                ),
              ),
            ),
          );
        }
        lastEnd = match.end;
      }

      if (lastEnd < content.length) {
        final remainingText = content.substring(lastEnd).trim();
        if (remainingText.isNotEmpty) {
          children.add(const SizedBox(height: 8));
          children.add(Text(remainingText, style: defaultStyle));
        }
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      );
    }

    final List<Widget> children = [];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        final textSegment = content.substring(lastEnd, match.start).trim();
        if (textSegment.isNotEmpty) {
          children.add(Text(textSegment, style: defaultStyle));
          children.add(const SizedBox(height: 8));
        }
      }

      final imageUrl = match.group(2);
      if (imageUrl != null && imageUrl.isNotEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                placeholder: (context, url) => Container(
                  height: 200,
                  color: isDark ? Colors.grey[900] : Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => const SizedBox(),
              ),
            ),
          ),
        );
      }
      lastEnd = match.end;
    }

    if (lastEnd < content.length) {
      final remainingText = content.substring(lastEnd).trim();
      if (remainingText.isNotEmpty) {
        children.add(const SizedBox(height: 8));
        children.add(Text(remainingText, style: defaultStyle));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
