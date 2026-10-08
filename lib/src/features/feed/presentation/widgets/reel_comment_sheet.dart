import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../domain/post.dart';
import '../../data/post_repository.dart';
import '../../../../core/widgets/verification_badge.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../../shared/widgets/formatted_comment_content.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../user/data/user_repository.dart';

class ReelCommentSheet extends ConsumerStatefulWidget {
  final Post post;

  const ReelCommentSheet({super.key, required this.post});

  @override
  ConsumerState<ReelCommentSheet> createState() => _ReelCommentSheetState();
}

class _ReelCommentSheetState extends ConsumerState<ReelCommentSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  bool _isPosting = false;
  String? _replyingToCommentId;
  String? _replyingToName;
  bool _hasInputText = false;

  @override
  void initState() {
    super.initState();
    _commentController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = _commentController.text.trim().isNotEmpty;
    if (hasText != _hasInputText) {
      setState(() => _hasInputText = hasText);
    }
  }

  @override
  void dispose() {
    _commentController.removeListener(_onTextChanged);
    _commentController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    if (_isPosting) return;
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isPosting = true);

    try {
      final repo = ref.read(postRepositoryProvider);
      await repo.addComment(
        widget.post.id,
        content,
        parentId: _replyingToCommentId,
      );
      _commentController.clear();
      _clearReplyTarget();
      if (mounted) {
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error posting comment: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  void _setReplyTarget(String commentId, String userName) {
    if (commentId.isEmpty) return;
    setState(() {
      _replyingToCommentId = commentId;
      _replyingToName = userName;
    });
    _inputFocusNode.requestFocus();
  }

  void _clearReplyTarget() {
    if (!mounted) return;
    setState(() {
      _replyingToCommentId = null;
      _replyingToName = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(postRepositoryProvider);
    final commentsStream = repo.watchComments(widget.post.id);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider).value;

    final sheetBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 25,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Drag Handle & Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 32), // Balance for close button
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: commentsStream,
                        builder: (context, snapshot) {
                          final count = snapshot.hasData
                              ? snapshot.data!.length
                              : widget.post.commentsCount;
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Comments',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: textPrimary,
                                ),
                              ),
                              if (count > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$count',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(CupertinoIcons.xmark, size: 20),
                        color: textSecondary,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: borderColor),

            // Comments List
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: commentsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }
                  final rawComments = snapshot.data ?? [];

                  int getVerificationWeight(dynamic type) {
                    final clean = (type ?? '').toString().trim().toLowerCase();
                    switch (clean) {
                      case 'gold':
                        return 3;
                      case 'violet':
                        return 2;
                      case 'blue':
                      case 'true':
                        return 1;
                      default:
                        return 0;
                    }
                  }

                  // Deduplicate comments
                  final seenIds = <String>{};
                  final dedupedList = <Map<String, dynamic>>[];
                  for (final c in rawComments) {
                    final id = (c['id'] ?? '').toString();
                    if (id.isNotEmpty && !seenIds.contains(id)) {
                      seenIds.add(id);
                      dedupedList.add(c);
                    }
                  }

                  final comments = List<Map<String, dynamic>>.from(dedupedList)
                    ..sort((a, b) {
                      final vTypeA = a['authorVerificationType'] ??
                          a['author_verification_type'] ??
                          (a['author']?['verificationType'] ??
                              (a['author']?['isVerified'] == true
                                  ? 'blue'
                                  : 'none'));
                      final vTypeB = b['authorVerificationType'] ??
                          b['author_verification_type'] ??
                          (b['author']?['verificationType'] ??
                              (b['author']?['isVerified'] == true
                                  ? 'blue'
                                  : 'none'));

                      final weightA = getVerificationWeight(vTypeA);
                      final weightB = getVerificationWeight(vTypeB);

                      if (weightA != weightB) {
                        return weightB.compareTo(weightA);
                      }
                      final tsA = (a['timestamp'] is int) ? a['timestamp'] as int : 0;
                      final tsB = (b['timestamp'] is int) ? b['timestamp'] as int : 0;
                      return tsB.compareTo(tsA);
                    });

                  if (comments.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.chat_bubble_2,
                            size: 48,
                            color: isDark ? Colors.white24 : Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No comments yet',
                            style: TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Be the first to share your thoughts!',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final comment = comments[index];
                      return _CommentTile(
                        postId: widget.post.id,
                        comment: comment,
                        isDark: isDark,
                        onReplyTap: () => _setReplyTarget(
                          comment['id']?.toString() ?? '',
                          comment['userName']?.toString() ?? 'Student',
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Input Bar
            Container(
              padding: EdgeInsets.only(
                bottom: math.max(
                      MediaQuery.of(context).viewInsets.bottom,
                      MediaQuery.of(context).padding.bottom,
                    ) +
                    10,
                left: 14,
                right: 14,
                top: 8,
              ),
              decoration: BoxDecoration(
                color: sheetBg,
                border: Border(top: BorderSide(color: borderColor, width: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Replying to banner
                  if (_replyingToCommentId != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.reply,
                            size: 14,
                            color: const Color(0xFF6366F1),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Replying to ${_replyingToName ?? "comment"}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _clearReplyTarget,
                            child: Icon(
                              CupertinoIcons.clear_circled_solid,
                              size: 16,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Input row with user avatar and rounded pill field
                  Row(
                    children: [
                      UserAvatar(
                        userId: currentUser?.uid ?? '',
                        avatarUrl: currentUser?.avatarUrl,
                        displayName: currentUser?.displayName ?? 'You',
                        radius: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _commentController,
                                  focusNode: _inputFocusNode,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: _replyingToCommentId != null
                                        ? 'Reply to ${_replyingToName ?? "comment"}...'
                                        : 'Add a comment...',
                                    hintStyle: TextStyle(
                                      fontSize: 14,
                                      color: isDark ? Colors.white38 : Colors.grey[500],
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                  ),
                                  maxLines: 4,
                                  minLines: 1,
                                  textCapitalization: TextCapitalization.sentences,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: InkWell(
                                  onTap: (_hasInputText && !_isPosting)
                                      ? _postComment
                                      : null,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _hasInputText
                                          ? const Color(0xFF6366F1)
                                          : Colors.transparent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: _isPosting
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Icon(
                                            CupertinoIcons.arrow_up,
                                            size: 18,
                                            color: _hasInputText
                                                ? Colors.white
                                                : textSecondary.withValues(alpha: 0.5),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends ConsumerWidget {
  final String postId;
  final Map<String, dynamic> comment;
  final bool isDark;
  final VoidCallback onReplyTap;

  const _CommentTile({
    required this.postId,
    required this.comment,
    required this.isDark,
    required this.onReplyTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(postRepositoryProvider);
    final commentId = comment['id']?.toString() ?? '';
    final authorId = (comment['authorId'] ?? comment['userId'] ?? '').toString();
    final authorName = (comment['authorName'] ?? comment['userName'] ?? 'Student').toString();
    final content = (comment['content'] ?? '').toString();
    final avatarUrl = comment['authorAvatarUrl'] ?? comment['userAvatar'] as String?;
    final replyCount = (comment['replyCount'] as num?)?.toInt() ?? 0;
    final isLiked = comment['isLiked'] == true;
    final likesCount = (comment['likesCount'] as num?)?.toInt() ?? 0;

    int tsInt = (comment['timestamp'] is int && (comment['timestamp'] as int) > 0)
        ? comment['timestamp'] as int
        : DateTime.now().millisecondsSinceEpoch;
    final timestamp = DateTime.fromMillisecondsSinceEpoch(tsInt);
    final isVerified = comment['authorIsVerified'] == true;
    final verificationType = (comment['authorVerificationType'] ?? 'none').toString();

    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return StreamBuilder<AppUser?>(
      stream: authorId.isNotEmpty
          ? ref.read(userRepositoryProvider).watchUser(authorId)
          : const Stream.empty(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final effectiveName = (user != null && user.displayName.isNotEmpty)
            ? user.displayName
            : (authorName.isNotEmpty ? authorName : 'Student');
        final effectiveAvatar = user?.avatarUrl ?? avatarUrl;
        final effectiveVerification = user?.verificationType ?? verificationType;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserAvatar(
                userId: authorId,
                avatarUrl: effectiveAvatar,
                displayName: effectiveName,
                radius: 18,
                showStoryRing: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            effectiveName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVerified || (user?.isVerified == true)) ...[
                          const SizedBox(width: 4),
                          VerificationBadge(type: effectiveVerification, size: 13),
                        ],
                        const SizedBox(width: 8),
                        Text(
                          timeago.format(timestamp, locale: 'en_short'),
                          style: TextStyle(color: textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    FormattedCommentContent(
                      content: content,
                      textStyle: TextStyle(
                        fontSize: 14,
                        color: textPrimary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            repo.toggleCommentLike(postId, commentId);
                          },
                          child: Row(
                            children: [
                              Icon(
                                isLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                                size: 15,
                                color: isLiked ? Colors.redAccent : textSecondary,
                              ),
                              if (likesCount > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '$likesCount',
                                  style: TextStyle(
                                    color: isLiked ? Colors.redAccent : textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 18),
                        GestureDetector(
                          onTap: onReplyTap,
                          child: Text(
                            'Reply',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (replyCount > 0) ...[
                          const SizedBox(width: 14),
                          Text(
                            '$replyCount ${replyCount == 1 ? 'reply' : 'replies'}',
                            style: TextStyle(
                              color: const Color(0xFF6366F1),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (replyCount > 0 && commentId.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: StreamBuilder<List<Map<String, dynamic>>>(
                          stream: repo.watchReplies(postId, commentId),
                          builder: (context, snapshot) {
                            final replies = snapshot.data ?? const [];
                            if (replies.isEmpty) return const SizedBox.shrink();
                            return Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.only(left: 10),
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFE2E8F0),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              child: Column(
                                children: replies.map((reply) {
                                  final replyName = (reply['authorName'] ??
                                          reply['userName'] ??
                                          'Student')
                                      .toString();
                                  final replyContent = (reply['content'] ?? '').toString();
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$replyName: ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                            color: textPrimary,
                                          ),
                                        ),
                                        Expanded(
                                          child: FormattedCommentContent(
                                            content: replyContent,
                                            textStyle: TextStyle(
                                              fontSize: 12,
                                              color: textPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
