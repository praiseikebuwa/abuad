import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/post.dart';
import '../../data/post_repository.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../user/data/user_repository.dart';
import 'comment_thread_view.dart';

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
  late Stream<List<Map<String, dynamic>>> _commentsStream;

  @override
  void initState() {
    super.initState();
    _commentController.addListener(_onTextChanged);
    _commentsStream = ref
        .read(postRepositoryProvider)
        .watchComments(widget.post.id)
        .asBroadcastStream();
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
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _commentsStream,
          builder: (context, snapshot) {
            final rawComments = snapshot.data ?? [];
            final count = snapshot.hasData
                ? rawComments.length
                : widget.post.commentsCount;

            return Column(
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
                          Row(
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
                  child: Builder(
                    builder: (context) {
                      if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }
                      final rawComments = snapshot.data ?? [];
                      return CommentThreadView(
                        post: widget.post,
                        comments: rawComments,
                        onReply: _setReplyTarget,
                        currentUserId: currentUser?.uid,
                        isScrollable: true,
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
        );
      },
    ),
  ),
);
  }
}


