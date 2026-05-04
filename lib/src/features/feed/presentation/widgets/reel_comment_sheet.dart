import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../domain/post.dart';
import '../../data/post_repository.dart';
import '../../../../core/widgets/verification_badge.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/user_avatar.dart';
import 'dart:ui';
import 'dart:math' as math;

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

  @override
  void dispose() {
    _commentController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Stack(
        children: [
          // Blur effect
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[600],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${widget.post.commentsCount} comments',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Comments List
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: commentsStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final comments = snapshot.data ?? [];
                      if (comments.isEmpty) {
                        return Center(
                          child: Text(
                            'No comments yet',
                            style: TextStyle(color: Colors.grey[500]),
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
                // Input field
                Padding(
                  padding: EdgeInsets.only(
                    bottom:
                        math.max(
                          MediaQuery.of(context).viewInsets.bottom,
                          MediaQuery.of(context).padding.bottom,
                        ) +
                        16,
                    left: 16,
                    right: 16,
                    top: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_replyingToCommentId != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.grey[800]
                                      : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Replying to ${_replyingToName ?? "comment"}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? Colors.grey[300]
                                              : Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: _clearReplyTarget,
                                      child: const Icon(Icons.close, size: 16),
                                    ),
                                  ],
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.grey[900]
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: TextField(
                                controller: _commentController,
                                focusNode: _inputFocusNode,
                                decoration: InputDecoration(
                                  hintText: _replyingToCommentId != null
                                      ? 'Add reply...'
                                      : 'Add comment...',
                                  border: InputBorder.none,
                                  hintStyle: const TextStyle(fontSize: 14),
                                ),
                                maxLines: null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _isPosting ? null : _postComment,
                        icon: _isPosting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.send,
                                color: AppColors.secondaryTeal,
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends ConsumerWidget {
  final String postId;
  final Map<String, dynamic> comment;
  final VoidCallback onReplyTap;

  const _CommentTile({
    required this.postId,
    required this.comment,
    required this.onReplyTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(postRepositoryProvider);
    final commentId = comment['id']?.toString() ?? '';
    final authorName = comment['userName'] ?? 'Unknown';
    final content = comment['content'] ?? '';
    final avatarUrl = comment['userAvatar'];
    final replyCount = (comment['replyCount'] as num?)?.toInt() ?? 0;
    final timestamp = comment['timestamp'] != null
        ? (comment['timestamp'] is int
              ? DateTime.fromMillisecondsSinceEpoch(comment['timestamp'])
              : DateTime.tryParse(comment['timestamp'].toString()) ??
                    DateTime.now())
        : DateTime.now();
    final isVerified = comment['authorIsVerified'] == true;
    final verificationType = comment['authorVerificationType'] ?? 'none';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            userId: comment['userId'] ?? '',
            avatarUrl: avatarUrl,
            displayName: authorName,
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
                    Text(
                      authorName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 4),
                      VerificationBadge(type: verificationType, size: 12),
                    ],
                    const SizedBox(width: 8),
                    Text(
                      timeago.format(timestamp, locale: 'en_short'),
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(content, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: onReplyTap,
                      child: Text(
                        'Reply',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ),
                    if (replyCount > 0) ...[
                      const SizedBox(width: 12),
                      Text(
                        '$replyCount replies',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
                        return Column(
                          children: replies.map((reply) {
                            final replyName =
                                reply['userName']?.toString() ?? 'Unknown';
                            final replyContent =
                                reply['content']?.toString() ?? '';
                            return Padding(
                              padding: const EdgeInsets.only(
                                left: 8,
                                bottom: 6,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$replyName: ',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      replyContent,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
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
  }
}
