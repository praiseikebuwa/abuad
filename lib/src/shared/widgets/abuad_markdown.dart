import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../../features/user/data/user_repository.dart';

/// Reusable Markdown & Rich Text Component for Posts, Comments, Reels, and Messages
class AbuadMarkdownContent extends ConsumerWidget {
  final String content;
  final TextStyle? textStyle;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool enableImages;
  final bool enableCodeBlocks;
  final Color? linkColor;
  final VoidCallback? onExpandTap;

  const AbuadMarkdownContent({
    super.key,
    required this.content,
    this.textStyle,
    this.maxLines,
    this.overflow,
    this.enableImages = true,
    this.enableCodeBlocks = true,
    this.linkColor,
    this.onExpandTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (content.trim().isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = textStyle?.color ??
        theme.textTheme.bodyLarge?.color ??
        (isDark ? Colors.white : const Color(0xFF0F172A));
    final defaultStyle = TextStyle(
      fontSize: 15.5,
      height: 1.4,
      color: baseColor,
    ).merge(textStyle);
    final primaryLinkColor = linkColor ?? (isDark ? const Color(0xFF818CF8) : AppColors.primaryInk);

    // Parse blocks for multiline code blocks, images, alerts, quotes, and lists
    final blocks = _parseBlocks(content);
    if (blocks.isEmpty) return const SizedBox.shrink();

    if (blocks.length > 1 || blocks.first.type != _BlockType.text) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: blocks.map((block) {
          switch (block.type) {
            case _BlockType.code:
              return _buildCodeBlockCard(context, block.content, block.language, isDark);
            case _BlockType.image:
              return _buildImageCard(context, block.content, isDark);
            case _BlockType.alert:
              return _buildAlertCard(
                context,
                ref,
                block.content,
                block.meta ?? 'NOTE',
                defaultStyle,
                primaryLinkColor,
                isDark,
              );
            case _BlockType.quote:
              return _buildQuoteBlock(
                context,
                ref,
                block.content,
                defaultStyle,
                primaryLinkColor,
                isDark,
              );
            case _BlockType.taskItem:
              return _buildTaskItem(
                context,
                ref,
                block.content,
                block.isChecked ?? false,
                defaultStyle,
                primaryLinkColor,
                isDark,
              );
            case _BlockType.bulletItem:
              return _buildBulletItem(
                context,
                ref,
                block.content,
                defaultStyle,
                primaryLinkColor,
                isDark,
              );
            case _BlockType.numberedItem:
              return _buildNumberedItem(
                context,
                ref,
                block.meta ?? '1',
                block.content,
                defaultStyle,
                primaryLinkColor,
                isDark,
              );
            case _BlockType.text:
              return _buildRichText(
                context,
                ref,
                block.content,
                defaultStyle,
                primaryLinkColor,
                isDark,
              );
          }
        }).toList(),
      );
    }

    return _buildRichText(
      context,
      ref,
      content,
      defaultStyle,
      primaryLinkColor,
      isDark,
    );
  }

  Widget _buildRichText(
    BuildContext context,
    WidgetRef ref,
    String text,
    TextStyle baseStyle,
    Color linkColor,
    bool isDark,
  ) {
    final spans = _parseInlineSpans(
      context: context,
      ref: ref,
      text: text,
      baseStyle: baseStyle,
      linkColor: linkColor,
      isDark: isDark,
    );

    return RichText(
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
      text: TextSpan(
        style: baseStyle,
        children: spans,
      ),
    );
  }

  List<InlineSpan> _parseInlineSpans({
    required BuildContext context,
    required WidgetRef ref,
    required String text,
    required TextStyle baseStyle,
    required Color linkColor,
    required bool isDark,
  }) {
    final List<InlineSpan> spans = [];

    // Master regex for:
    // 1. Markdown links: [Label](url)
    // 2. Explicit copy tag: [copy:content]
    // 3. Spoilers: ||spoiler||
    // 4. Inline code: `code`
    // 5. Bold: **bold**
    // 6. Italic: *italic* or _italic_
    // 7. Strikethrough: ~~strike~~
    // 8. Plain URLs: https://... or http://...
    // 9. Mentions: @username
    // 10. Hashtags: #hashtag
    // 11. General text & whitespace
    final pattern = RegExp(
      r'(\[(?:copy:)?([^\]]+)\]\((https?://[^\s\)]+)\)|\[copy:([^\]]+)\]|\|\|([^|]+)\|\||`([^`]+)`|\*\*([^*]+)\*\*|~~([^~]+)~~|(?:\*([^*]+)\*)|(?:_([^_]+)_)|(https?://[^\s]+)|@([a-zA-Z0-9_]+)|#([a-zA-Z0-9_]+)|[^\s\[`*~_@#h|]+|\s+|.)',
      multiLine: true,
      caseSensitive: false,
    );

    final matches = pattern.allMatches(text);

    for (final match in matches) {
      final raw = match.group(0)!;

      // 1. Markdown Link: [Label](url)
      final mdLinkMatch = RegExp(r'^\[([^\]]+)\]\((https?://[^\s\)]+)\)$').firstMatch(raw);
      if (mdLinkMatch != null) {
        final label = mdLinkMatch.group(1)!;
        final url = mdLinkMatch.group(2)!;
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: GestureDetector(
              onTap: () => _openUrl(context, url),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: linkColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: linkColor,
                        fontWeight: FontWeight.w600,
                        fontSize: baseStyle.fontSize ?? 15,
                        decoration: TextDecoration.underline,
                        decorationColor: linkColor.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.arrow_outward_rounded,
                      size: (baseStyle.fontSize ?? 15) * 0.85,
                      color: linkColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        continue;
      }

      // 2. Explicit Copy: [copy:content]
      final explicitCopyMatch = RegExp(r'^\[copy:([^\]]+)\]$').firstMatch(raw);
      if (explicitCopyMatch != null) {
        final copyVal = explicitCopyMatch.group(1)!;
        spans.add(_buildCopyableInlineChip(context, copyVal, isDark, linkColor, baseStyle));
        continue;
      }

      // 3. Spoilers: ||content||
      final spoilerMatch = RegExp(r'^\|\|([^|]+)\|\|$').firstMatch(raw);
      if (spoilerMatch != null) {
        final spoilerVal = spoilerMatch.group(1)!;
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _SpoilerChip(
              text: spoilerVal,
              textStyle: baseStyle,
              isDark: isDark,
            ),
          ),
        );
        continue;
      }

      // 4. Inline Code: `code`
      final inlineCodeMatch = RegExp(r'^`([^`]+)`$').firstMatch(raw);
      if (inlineCodeMatch != null) {
        final codeVal = inlineCodeMatch.group(1)!;
        spans.add(_buildCopyableInlineChip(context, codeVal, isDark, linkColor, baseStyle));
        continue;
      }

      // 4. Bold: **text**
      final boldMatch = RegExp(r'^\*\*([^*]+)\*\*$').firstMatch(raw);
      if (boldMatch != null) {
        final inner = boldMatch.group(1)!;
        if (inner.startsWith('@') && inner.length > 1) {
          final handle = inner.substring(1);
          spans.add(_buildMentionSpan(context, ref, handle, linkColor, baseStyle));
        } else if (inner.startsWith('#') && inner.length > 1) {
          final tag = inner.substring(1);
          spans.add(_buildHashtagSpan(context, tag, linkColor, baseStyle));
        } else {
          spans.add(
            TextSpan(
              text: inner,
              style: baseStyle.copyWith(fontWeight: FontWeight.bold),
            ),
          );
        }
        continue;
      }

      // 5. Strikethrough: ~~text~~
      final strikeMatch = RegExp(r'^~~([^~]+)~~$').firstMatch(raw);
      if (strikeMatch != null) {
        spans.add(
          TextSpan(
            text: strikeMatch.group(1)!,
            style: baseStyle.copyWith(decoration: TextDecoration.lineThrough),
          ),
        );
        continue;
      }

      // 6. Italic: *text* or _text_
      final italicMatch = RegExp(r'^(?:\*([^*]+)\*|_([^_]+)_)$').firstMatch(raw);
      if (italicMatch != null) {
        final inner = italicMatch.group(1) ?? italicMatch.group(2) ?? '';
        spans.add(
          TextSpan(
            text: inner,
            style: baseStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        );
        continue;
      }

      // 7. Plain URL: https://...
      if (raw.startsWith('http://') || raw.startsWith('https://')) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: GestureDetector(
              onTap: () => _openUrl(context, raw),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: linkColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _shortenUrl(raw),
                      style: TextStyle(
                        color: linkColor,
                        fontWeight: FontWeight.w600,
                        fontSize: (baseStyle.fontSize ?? 15) * 0.95,
                        decoration: TextDecoration.underline,
                        decorationColor: linkColor.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.arrow_outward_rounded,
                      size: (baseStyle.fontSize ?? 15) * 0.8,
                      color: linkColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        continue;
      }

      // 8. Mentions: @handle
      final mentionMatch = RegExp(r'^@([a-zA-Z0-9_]+)$').firstMatch(raw);
      if (mentionMatch != null) {
        final handle = mentionMatch.group(1)!;
        spans.add(_buildMentionSpan(context, ref, handle, linkColor, baseStyle));
        continue;
      }

      // 9. Hashtags: #tag
      final hashtagMatch = RegExp(r'^#([a-zA-Z0-9_]+)$').firstMatch(raw);
      if (hashtagMatch != null) {
        final tag = hashtagMatch.group(1)!;
        spans.add(_buildHashtagSpan(context, tag, linkColor, baseStyle));
        continue;
      }

      // Default text / whitespace
      if (raw.trim().isEmpty) {
        final cleanSpaces = raw.contains('\n') ? raw : ' ';
        spans.add(
          TextSpan(
            text: cleanSpaces,
            style: baseStyle,
          ),
        );
        continue;
      }

      spans.add(
        TextSpan(
          text: raw,
          style: baseStyle,
        ),
      );
    }

    return spans;
  }

  InlineSpan _buildCopyableInlineChip(
    BuildContext context,
    String text,
    bool isDark,
    Color linkColor,
    TextStyle baseStyle,
  ) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: GestureDetector(
        onTap: () => _copyToClipboard(context, text),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: linkColor.withValues(alpha: isDark ? 0.35 : 0.25),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  fontSize: (baseStyle.fontSize ?? 15) * 0.9,
                  color: isDark ? const Color(0xFF38BDF8) : linkColor,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.copy_rounded,
                size: (baseStyle.fontSize ?? 15) * 0.75,
                color: isDark ? const Color(0xFF38BDF8) : linkColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  InlineSpan _buildMentionSpan(
    BuildContext context,
    WidgetRef ref,
    String handle,
    Color linkColor,
    TextStyle baseStyle,
  ) {
    return TextSpan(
      text: '@$handle',
      style: TextStyle(
        color: linkColor,
        fontWeight: FontWeight.bold,
        fontSize: baseStyle.fontSize,
      ),
      recognizer: TapGestureRecognizer()
        ..onTap = () async {
          final clean = handle.toLowerCase();
          if (clean == 'ai' || clean == 'abuad_ai') {
            context.push('/user/abuad_ai');
            return;
          }
          final user = await ref.read(userRepositoryProvider).getUserByHandle(handle);
          if (context.mounted) {
            if (user != null) {
              context.push('/user/${user.uid}');
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('User @$handle not found'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
        },
    );
  }

  InlineSpan _buildHashtagSpan(
    BuildContext context,
    String tag,
    Color linkColor,
    TextStyle baseStyle,
  ) {
    return TextSpan(
      text: '#$tag',
      style: TextStyle(
        color: linkColor,
        fontWeight: FontWeight.bold,
        fontSize: baseStyle.fontSize,
      ),
      recognizer: TapGestureRecognizer()
        ..onTap = () => context.push('/hashtag/$tag'),
    );
  }

  Widget _buildCodeBlockCard(
    BuildContext context,
    String code,
    String? language,
    bool isDark,
  ) {
    final langLabel = (language?.isNotEmpty == true) ? language!.toUpperCase() : 'CODE';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with language & Copy action
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  langLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
                GestureDetector(
                  onTap: () => _copyToClipboard(context, code),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryInk.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.copy_rounded, size: 12, color: AppColors.primaryInk),
                        SizedBox(width: 4),
                        Text(
                          'Copy',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Code content
          Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              code,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.45,
                color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteBlock(
    BuildContext context,
    WidgetRef ref,
    String quote,
    TextStyle baseStyle,
    Color linkColor,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(
            color: AppColors.primaryInk,
            width: 3.5,
          ),
        ),
      ),
      child: _buildRichText(
        context,
        ref,
        quote,
        baseStyle.copyWith(
          fontStyle: FontStyle.italic,
          color: isDark ? Colors.grey[300] : Colors.grey[700],
        ),
        linkColor,
        isDark,
      ),
    );
  }

  Widget _buildAlertCard(
    BuildContext context,
    WidgetRef ref,
    String content,
    String alertType,
    TextStyle baseStyle,
    Color linkColor,
    bool isDark,
  ) {
    final type = alertType.toUpperCase();
    Color accent;
    IconData icon;

    switch (type) {
      case 'TIP':
        accent = const Color(0xFF10B981);
        icon = Icons.lightbulb_outline_rounded;
        break;
      case 'IMPORTANT':
        accent = const Color(0xFF8B5CF6);
        icon = Icons.priority_high_rounded;
        break;
      case 'WARNING':
        accent = const Color(0xFFF59E0B);
        icon = Icons.warning_amber_rounded;
        break;
      case 'CAUTION':
        accent = const Color(0xFFEF4444);
        icon = Icons.gpp_bad_outlined;
        break;
      case 'NOTE':
      default:
        accent = const Color(0xFF3B82F6);
        icon = Icons.info_outline_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: accent, width: 3.5),
          top: BorderSide(color: accent.withValues(alpha: 0.15)),
          right: BorderSide(color: accent.withValues(alpha: 0.15)),
          bottom: BorderSide(color: accent.withValues(alpha: 0.15)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 6),
              Text(
                type,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          if (content.trim().isNotEmpty) ...[
            const SizedBox(height: 5),
            _buildRichText(
              context,
              ref,
              content.trim(),
              baseStyle.copyWith(
                fontSize: (baseStyle.fontSize ?? 15) * 0.94,
                color: isDark ? Colors.grey[200] : Colors.grey[800],
              ),
              linkColor,
              isDark,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskItem(
    BuildContext context,
    WidgetRef ref,
    String text,
    bool initialChecked,
    TextStyle baseStyle,
    Color linkColor,
    bool isDark,
  ) {
    return _TaskItemWidget(
      initialChecked: initialChecked,
      text: text,
      baseStyle: baseStyle,
      linkColor: linkColor,
      isDark: isDark,
      richTextBuilder: (t) => _buildRichText(context, ref, t, baseStyle, linkColor, isDark),
    );
  }

  Widget _buildBulletItem(
    BuildContext context,
    WidgetRef ref,
    String text,
    TextStyle baseStyle,
    Color linkColor,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, right: 10, left: 4),
            width: 5.5,
            height: 5.5,
            decoration: BoxDecoration(
              color: linkColor,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: _buildRichText(context, ref, text, baseStyle, linkColor, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberedItem(
    BuildContext context,
    WidgetRef ref,
    String number,
    String text,
    TextStyle baseStyle,
    Color linkColor,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(right: 6),
            child: Text(
              '$number.',
              style: baseStyle.copyWith(
                fontWeight: FontWeight.w600,
                color: baseStyle.color,
              ),
            ),
          ),
          Expanded(
            child: _buildRichText(context, ref, text, baseStyle, linkColor, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCard(BuildContext context, String imageUrl, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          placeholder: (context, url) => Container(
            height: 200,
            color: isDark ? Colors.grey[900] : Colors.grey[200],
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          errorWidget: (context, url, error) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open $url')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid link: $e')),
        );
      }
    }
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Copied "$text" to clipboard',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _shortenUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.replaceFirst('www.', '');
      final path = uri.path.length > 15 ? '${uri.path.substring(0, 12)}...' : uri.path;
      return '$host$path';
    } catch (_) {
      return url.length > 28 ? '${url.substring(0, 25)}...' : url;
    }
  }

  List<_ParsedBlock> _parseBlocks(String rawText) {
    final List<_ParsedBlock> blocks = [];
    final codeBlockRegex = RegExp(r'```([a-zA-Z0-9_-]*)\n?([\s\S]*?)```');
    final imageRegex = RegExp(r'!\[(.*?)\]\((https?://[^\s\)]+)\)');

    int currentIndex = 0;

    // Scan for code blocks
    if (enableCodeBlocks) {
      final codeMatches = codeBlockRegex.allMatches(rawText);
      for (final match in codeMatches) {
        if (match.start > currentIndex) {
          final textBefore = rawText.substring(currentIndex, match.start);
          if (textBefore.trim().isNotEmpty) {
            _appendSubBlocks(blocks, textBefore, imageRegex);
          }
        }

        final lang = match.group(1)?.trim();
        final code = match.group(2) ?? '';
        blocks.add(_ParsedBlock(type: _BlockType.code, content: code, language: lang));
        currentIndex = match.end;
      }
    }

    if (currentIndex < rawText.length) {
      final remaining = rawText.substring(currentIndex);
      if (remaining.trim().isNotEmpty) {
        _appendSubBlocks(blocks, remaining, imageRegex);
      }
    }

    return blocks.isEmpty ? [_ParsedBlock(type: _BlockType.text, content: rawText)] : blocks;
  }

  void _appendSubBlocks(List<_ParsedBlock> blocks, String text, RegExp imageRegex) {
    if (enableImages) {
      final imageMatches = imageRegex.allMatches(text);
      if (imageMatches.isNotEmpty) {
        int cur = 0;
        for (final m in imageMatches) {
          if (m.start > cur) {
            final t = text.substring(cur, m.start);
            if (t.trim().isNotEmpty) _parseLinesIntoBlocks(blocks, t);
          }
          final imgUrl = m.group(2) ?? '';
          if (imgUrl.isNotEmpty) {
            blocks.add(_ParsedBlock(type: _BlockType.image, content: imgUrl));
          }
          cur = m.end;
        }
        if (cur < text.length) {
          final t = text.substring(cur);
          if (t.trim().isNotEmpty) _parseLinesIntoBlocks(blocks, t);
        }
        return;
      }
    }

    _parseLinesIntoBlocks(blocks, text);
  }

  void _parseLinesIntoBlocks(List<_ParsedBlock> blocks, String text) {
    final lines = text.split('\n');
    final buffer = StringBuffer();

    void flushBuffer() {
      final str = buffer.toString().trim();
      if (str.isNotEmpty) {
        blocks.add(_ParsedBlock(type: _BlockType.text, content: str));
      }
      buffer.clear();
    }

    int i = 0;
    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      // 1. GitHub Alert callouts: > [!NOTE] or > [!TIP] etc.
      final alertMatch = RegExp(r'^>\s*\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION)\](.*)$', caseSensitive: false).firstMatch(trimmed);
      if (alertMatch != null) {
        flushBuffer();
        final alertType = alertMatch.group(1)!.toUpperCase();
        final firstLineExtra = alertMatch.group(2)?.trim() ?? '';
        final alertLines = <String>[];
        if (firstLineExtra.isNotEmpty) {
          alertLines.add(firstLineExtra);
        }
        i++;
        while (i < lines.length && lines[i].trim().startsWith('>')) {
          final nextLine = lines[i].trim().replaceFirst(RegExp(r'^>\s?'), '');
          alertLines.add(nextLine);
          i++;
        }
        blocks.add(_ParsedBlock(
          type: _BlockType.alert,
          content: alertLines.join('\n'),
          meta: alertType,
        ));
        continue;
      }

      // 2. Standard blockquote: > quote
      if (trimmed.startsWith('>')) {
        flushBuffer();
        final quoteLines = <String>[];
        while (i < lines.length && lines[i].trim().startsWith('>')) {
          quoteLines.add(lines[i].trim().replaceFirst(RegExp(r'^>\s?'), ''));
          i++;
        }
        blocks.add(_ParsedBlock(
          type: _BlockType.quote,
          content: quoteLines.join('\n'),
        ));
        continue;
      }

      // 3. Task checklist items: - [ ] or - [x]
      final taskMatch = RegExp(r'^\s*-\s*\[([ xX])\]\s+(.*)$').firstMatch(line);
      if (taskMatch != null) {
        flushBuffer();
        final isChecked = taskMatch.group(1)!.toLowerCase() == 'x';
        final taskText = taskMatch.group(2)!;
        blocks.add(_ParsedBlock(
          type: _BlockType.taskItem,
          content: taskText,
          isChecked: isChecked,
        ));
        i++;
        continue;
      }

      // 4. Bullet lists: - item or * item
      final bulletMatch = RegExp(r'^\s*[-*]\s+(.*)$').firstMatch(line);
      if (bulletMatch != null) {
        flushBuffer();
        blocks.add(_ParsedBlock(
          type: _BlockType.bulletItem,
          content: bulletMatch.group(1)!,
        ));
        i++;
        continue;
      }

      // 5. Numbered lists: 1. item
      final numMatch = RegExp(r'^\s*(\d+)\.\s+(.*)$').firstMatch(line);
      if (numMatch != null) {
        flushBuffer();
        blocks.add(_ParsedBlock(
          type: _BlockType.numberedItem,
          content: numMatch.group(2)!,
          meta: numMatch.group(1)!,
        ));
        i++;
        continue;
      }

      // Normal text line
      buffer.writeln(line);
      i++;
    }

    flushBuffer();
  }
}

enum _BlockType {
  text,
  code,
  image,
  alert,
  quote,
  taskItem,
  bulletItem,
  numberedItem,
}

class _ParsedBlock {
  final _BlockType type;
  final String content;
  final String? language;
  final String? meta;
  final bool? isChecked;

  _ParsedBlock({
    required this.type,
    required this.content,
    this.language,
    this.meta,
    this.isChecked,
  });
}

class _SpoilerChip extends StatefulWidget {
  final String text;
  final TextStyle textStyle;
  final bool isDark;

  const _SpoilerChip({
    required this.text,
    required this.textStyle,
    required this.isDark,
  });

  @override
  State<_SpoilerChip> createState() => _SpoilerChipState();
}

class _SpoilerChipState extends State<_SpoilerChip> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF334155);
    const bgLight = Color(0xFFCBD5E1);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _revealed = !_revealed;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        decoration: BoxDecoration(
          color: _revealed
              ? (widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))
              : (widget.isDark ? bgDark : bgLight),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _revealed
                ? (widget.isDark ? Colors.white24 : Colors.black12)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: _revealed
            ? Text(
                widget.text,
                style: widget.textStyle.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.visibility_off_rounded,
                    size: (widget.textStyle.fontSize ?? 14) * 0.85,
                    color: widget.isDark ? Colors.white70 : Colors.black54,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Spoiler',
                    style: TextStyle(
                      fontSize: (widget.textStyle.fontSize ?? 14) * 0.85,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                      color: widget.isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TaskItemWidget extends StatefulWidget {
  final bool initialChecked;
  final String text;
  final TextStyle baseStyle;
  final Color linkColor;
  final bool isDark;
  final Widget Function(String text) richTextBuilder;

  const _TaskItemWidget({
    required this.initialChecked,
    required this.text,
    required this.baseStyle,
    required this.linkColor,
    required this.isDark,
    required this.richTextBuilder,
  });

  @override
  State<_TaskItemWidget> createState() => _TaskItemWidgetState();
}

class _TaskItemWidgetState extends State<_TaskItemWidget> {
  late bool _checked = widget.initialChecked;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _checked = !_checked;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 19,
              height: 19,
              margin: const EdgeInsets.only(top: 2, right: 9),
              decoration: BoxDecoration(
                color: _checked
                    ? AppColors.primaryInk
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: _checked
                      ? AppColors.primaryInk
                      : (widget.isDark ? Colors.white38 : Colors.grey[400]!),
                  width: 1.8,
                ),
              ),
              child: _checked
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : null,
            ),
            Expanded(
              child: Opacity(
                opacity: _checked ? 0.6 : 1.0,
                child: widget.richTextBuilder(widget.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
