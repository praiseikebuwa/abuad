import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/cupertino.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/utils/url_validator.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../data/post_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/post.dart' as domain;
import 'widgets/poll_widget.dart';
import 'widgets/animated_like_button.dart';
import 'widgets/video_post_widget.dart';
import '../../../core/widgets/verification_badge.dart';

import '../domain/report.dart';
import 'widgets/report_bottom_sheet.dart';
import 'widgets/comment_thread_view.dart';
import '../../../core/theme/app_colors.dart';
import 'widgets/link_preview_card.dart';
import 'widgets/post_media_carousel.dart';
import 'widgets/document_preview_card.dart';
import 'providers/feed_provider.dart';
import '../../../shared/widgets/abuad_markdown.dart';
// import '../../chat/presentation/widgets/attachment_preview.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  final domain.Post? post;
  final String? postId;

  const PostDetailScreen({super.key, this.post, this.postId});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isPosting = false;

  // Reply State
  String? _replyToCommentId;
  String? _replyToUserName;

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onReply(String commentId, String userName) {
    setState(() {
      _replyToCommentId = commentId;
      _replyToUserName = userName;
    });
    _commentController.text = ''; // Clear if they were typing something else
    FocusScope.of(context).requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyToCommentId = null;
      _replyToUserName = null;
    });
  }

  Future<void> _postComment() async {
    if (_isPosting) return;
    final content = _commentController.text.trim();
    if (content.isEmpty) {
      return;
    }

    setState(() => _isPosting = true);

    try {
      final repo = ref.read(postRepositoryProvider);
      final postId = widget.post?.id ?? widget.postId!;

      await repo.addComment(postId, content, parentId: _replyToCommentId);

      _commentController.clear();
      _cancelReply();

      // Scroll to bottom (optional)
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }

      if (mounted) {
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error posting comment: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repo = ref.read(postRepositoryProvider);
      final postId = widget.post?.id ?? widget.postId!;
      await repo.deleteComment(postId, commentId);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Comment deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _editComment(String commentId, String currentContent) async {
    final controller = TextEditingController(text: currentContent);
    final editedText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Comment'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Update your comment...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondaryTeal,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (editedText != null && editedText.isNotEmpty) {
      try {
        final repo = ref.read(postRepositoryProvider);
        final postId = widget.post?.id ?? widget.postId!;
        await repo.editComment(postId, commentId, editedText);

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Comment updated')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error updating comment: $e')));
        }
      }
    }
  }

  void _showCommentMenu(
    BuildContext context,
    String commentId,
    bool isOwn, {
    String? currentContent,
  }) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOwn) ...[
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('Edit Comment'),
                onTap: () {
                  Navigator.pop(context);
                  _editComment(commentId, currentContent ?? '');
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete Comment',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteComment(commentId);
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.report_outlined),
                title: const Text('Report Comment'),
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => ReportBottomSheet(
                      targetId: commentId,
                      type: ReportType.comment,
                    ),
                  );
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showPostMenu(
    BuildContext parentContext,
    domain.Post post,
    PostRepository repo,
  ) {
    final currentUserId = repo.currentUserId;
    final isOwnPost = post.authorId == currentUserId;

    final isDark = Theme.of(parentContext).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);

    showModalBottomSheet(
      context: parentContext,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              // Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF475569)
                        : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (isOwnPost)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.trash,
                      color: Colors.red,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Delete Post',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(modalCtx);
                    final confirmed = await showDialog<bool>(
                      context: parentContext,
                      builder: (dialogCtx) => AlertDialog(
                        title: const Text('Delete Post'),
                        content: const Text(
                          'Are you sure you want to delete this post? This action cannot be undone.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx, true),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true && mounted) {
                      try {
                        await repo.deletePost(post.id);
                        if (mounted) {
                          Navigator.pop(context); // Go back to feed
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Post deleted successfully'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      }
                    }
                  },
                ),
              Consumer(
                builder: (context, ref, child) {
                  final isSavedAsync = ref.watch(isPostSavedProvider(post.id));
                  final isSaved = isSavedAsync.value ?? false;
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            (isSaved
                                    ? const Color(0xFFFFB800)
                                    : const Color(0xFF6366F1))
                                .withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSaved
                            ? CupertinoIcons.bookmark_fill
                            : CupertinoIcons.bookmark,
                        color: isSaved
                            ? const Color(0xFFFFB800)
                            : const Color(0xFF6366F1),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      isSaved ? 'Unsave Post' : 'Save Post',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: textPrimary,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(modalCtx);
                      ref.read(postRepositoryProvider).togglePostSave(post.id);
                    },
                  );
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.flag,
                    color: Colors.amber,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Report Post',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: textPrimary,
                  ),
                ),
                onTap: () {
                  Navigator.pop(modalCtx);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => ReportBottomSheet(
                      targetId: post.id,
                      type: ReportType.post,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showRepostBottomSheet(domain.Post originalPost) {
    final commentController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final commentText = commentController.text;
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        Navigator.pop(context);
                        try {
                          await ref
                              .read(postRepositoryProvider)
                              .repost(originalPost, commentText);
                          ref.invalidate(paginatedFeedProvider);
                          final currentUserId = ref
                              .read(authRepositoryProvider)
                              .currentUser
                              ?.uid;
                          if (currentUserId != null) {
                            ref.invalidate(userPostsProvider(currentUserId));
                          }
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text("Post reposted successfully!"),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        } catch (e) {
                          debugPrint('Error posting repost: $e');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text("Repost"),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.grey,
                      child: Icon(
                        CupertinoIcons.person_add,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: commentController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: "Add a comment...",
                          border: InputBorder.none,
                        ),
                        maxLines: 4,
                        minLines: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      if (originalPost.mediaUrl.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: UrlValidator.formatImageUrl(
                              originalPost.mediaUrl,
                            ),
                            height: 60,
                            width: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              originalPost.authorName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              originalPost.content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[800],
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
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(postRepositoryProvider);
    final postId = widget.post?.id ?? widget.postId;

    if (postId == null || postId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text("Error: No Post ID provided")),
      );
    }

    final commentsStream = repo.watchComments(postId);
    final isLikedStream = repo.watchPostLiked(postId);
    final currentUserId = repo.currentUserId;
    final currentUser = ref.watch(authRepositoryProvider).currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go('/');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(CupertinoIcons.arrow_left),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go('/');
              }
            },
          ),
          title: const Text('Post'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(CupertinoIcons.arrowshape_turn_up_right),
              onPressed: () {
                SharePlus.instance.share(
                  ShareParams(
                    text:
                        'Check out this post on Abuad life: https://abuadapp.com.ng/post/$postId',
                    subject: 'Check out this post on ABUAD',
                  ),
                );
              },
            ),
          ],
        ),
        body: StreamBuilder<domain.Post?>(
          stream: repo.watchPost(postId),
          builder: (context, snapshot) {
            final post = snapshot.data ?? widget.post;

            if (post == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final isPureRepost =
                post.repostData != null && post.content.trim().isEmpty;

            // Data to Display (Swap if Pure Repost)
            final displayAuthorName = isPureRepost
                ? (post.repostData!['author_name'] ?? 'Unknown')
                : post.authorName;
            final displayAuthorHandle = isPureRepost
                ? (post.repostData!['author_handle'] ?? '')
                : post.authorHandle;
            final displayAvatarUrl = isPureRepost
                ? post.repostData!['author_avatar_url']
                : post.authorAvatarUrl;
            final displayContent = isPureRepost
                ? (post.repostData!['content'] ?? '')
                : post.content;
            final displayLinkUrl = isPureRepost
                ? (post.repostData!['link_url'] as String?)
                : post.linkUrl;
            final displayMediaUrl = isPureRepost
                ? (post.repostData!['media_url'] ?? '')
                : post.mediaUrl;
            final displayMediaTypeStr = isPureRepost
                ? (post.repostData!['media_type'] as String?)
                : null;
            final displayTimestamp = isPureRepost
                ? (DateTime.tryParse(post.repostData!['timestamp'] ?? '') ??
                      post.timestamp)
                : post.timestamp;
            final displayIsVerified = isPureRepost
                ? (post.repostData!['is_verified'] == true)
                : post.isVerified;
            final displayVerificationType = isPureRepost
                ? (post.repostData!['verification_type'] ?? 'none')
                : post.verificationType;
            final displayIsAnonymous = isPureRepost
                ? (post.repostData!['is_anonymous'] == true)
                : (post.isAnonymous || post.channelId == 'confessions');

            // Media Type Enum Conversion
            domain.MediaType displayMediaType = post.mediaType;
            if (isPureRepost && displayMediaTypeStr != null) {
              displayMediaType = domain.MediaType.values.firstWhere(
                (e) => e.name == displayMediaTypeStr,
                orElse: () => domain.MediaType.none,
              );
            }
            if (displayMediaUrl.isNotEmpty) {
              final lower = displayMediaUrl.toLowerCase();
              if (lower.contains('.mp4') ||
                  lower.contains('.mov') ||
                  lower.contains('.webm') ||
                  lower.contains('.m3u8')) {
                displayMediaType = domain.MediaType.video;
              } else if (lower.contains('giphy') || lower.endsWith('.gif')) {
                displayMediaType = domain.MediaType.gif;
              } else if (lower.endsWith('.pdf') ||
                  lower.endsWith('.doc') ||
                  lower.endsWith('.docx') ||
                  lower.endsWith('.ppt') ||
                  lower.endsWith('.pptx') ||
                  lower.endsWith('.xls') ||
                  lower.endsWith('.xlsx') ||
                  lower.endsWith('.txt') ||
                  displayMediaTypeStr == 'document' ||
                  post.mediaType == domain.MediaType.document) {
                displayMediaType = domain.MediaType.document;
              } else if (displayMediaType == domain.MediaType.none) {
                displayMediaType = domain.MediaType.image;
              }
            }

            // Determine author ID to watch
            final authorIdToWatch = isPureRepost
                ? post.repostData!['author_id']
                : post.authorId;
            final shouldWatch = !displayIsAnonymous && authorIdToWatch != null;

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: Column(
                      children: [
                        // Main Post Content
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isPureRepost)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: Row(
                                    children: [
                                      Icon(
                                        CupertinoIcons.repeat,
                                        size: 16,
                                        color: isDark
                                            ? Colors.grey[500]
                                            : Colors.grey[600],
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${post.authorName} reposted',
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.grey[500]
                                              : Colors.grey[600],
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              // Header: Avatar, Names, More
                              StreamBuilder<AppUser?>(
                                stream: shouldWatch
                                    ? ref
                                          .read(userRepositoryProvider)
                                          .watchUser(authorIdToWatch)
                                    : const Stream.empty(),
                                builder: (context, userSnapshot) {
                                  final user = userSnapshot.data;
                                  final effectiveAuthorName =
                                      user?.displayName ?? displayAuthorName;
                                  final effectiveAuthorHandle =
                                      user?.handle ?? displayAuthorHandle;
                                  final effectiveAvatarUrl =
                                      user?.avatarUrl ?? displayAvatarUrl;
                                  final effectiveIsVerified =
                                      user?.isVerified ?? displayIsVerified;
                                  final effectiveVerificationType =
                                      user?.verificationType ??
                                      displayVerificationType;

                                  return Row(
                                    children: [
                                      if (displayIsAnonymous)
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF6B21A8),
                                            shape: BoxShape.circle,
                                          ),
                                          alignment: Alignment.center,
                                          child: const Text(
                                            '🎭',
                                            style: TextStyle(fontSize: 24),
                                          ),
                                        )
                                      else
                                        UserAvatar(
                                          userId: post.authorId,
                                          avatarUrl: effectiveAvatarUrl,
                                          displayName: effectiveAuthorName,
                                          radius: 24,
                                          showStoryRing: true,
                                        ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  displayIsAnonymous
                                                      ? 'Anonymous Student'
                                                      : effectiveAuthorName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                if (displayIsAnonymous) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF6B21A8)
                                                          .withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: const Text(
                                                      '🎭 Confession',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: Color(0xFF8B5CF6),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                                if (effectiveIsVerified &&
                                                    !displayIsAnonymous) ...[
                                                  const SizedBox(width: 4),
                                                  VerificationBadge(
                                                    type:
                                                        effectiveVerificationType,
                                                    size: 18,
                                                  ),
                                                ],
                                              ],
                                            ),
                                            if (!displayIsAnonymous)
                                              Text(
                                                '@$effectiveAuthorHandle',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 14,
                                                ),
                                              )
                                            else if (currentUser?.isAdmin == true &&
                                                post.authorHandle.isNotEmpty &&
                                                post.authorHandle != 'anonymous')
                                              Text(
                                                '🛡️ Admin reveal: @${post.authorHandle}',
                                                style: const TextStyle(
                                                  color: Color(0xFF8B5CF6),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.more_horiz),
                                        onPressed: () {
                                          _showPostMenu(context, post, repo);
                                        },
                                        color: Colors.grey,
                                      ),
                                    ],
                                  );
                                },
                              ),

                              const SizedBox(height: 16),

                              // Post Text
                              _buildHighlightedContent(
                                context,
                                displayContent,
                                theme,
                                ref,
                              ),
                              LinkPreviewCard(
                                url:
                                    displayLinkUrl ??
                                    UrlValidator.extractFirstUrl(
                                      displayContent,
                                    ),
                              ),

                              // Repost (Quote) Rendering
                              if (!isPureRepost && post.repostData != null) ...[
                                const SizedBox(height: 12),
                                _buildQuotedPost(
                                  context,
                                  post.repostData!,
                                  isDark,
                                ),
                              ],

                              // Post Media
                              if (displayMediaUrl.isNotEmpty ||
                                  post.allMediaUrls.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                if (displayMediaType == domain.MediaType.video)
                                  VideoPostWidget(
                                    videoUrl: displayMediaUrl,
                                    onTap: () {
                                      context.push(
                                        '/reels',
                                        extra: {
                                          'videos': [post],
                                          'initialIndex': 0,
                                        },
                                      );
                                    },
                                    onOpenFullscreen: () {
                                      context.push(
                                        '/reels',
                                        extra: {
                                          'videos': [post],
                                          'initialIndex': 0,
                                        },
                                      );
                                    },
                                  )
                                else if (displayMediaType ==
                                    domain.MediaType.document)
                                  DocumentPreviewCard(
                                    documentUrl: displayMediaUrl,
                                    fileName:
                                        (post.mediaAltText != null &&
                                            post.mediaAltText!.isNotEmpty)
                                        ? post.mediaAltText
                                        : null,
                                  )
                                else
                                  PostMediaCarousel(
                                    imageUrls: post.allMediaUrls.isNotEmpty
                                        ? post.allMediaUrls
                                        : [displayMediaUrl],
                                    postId: post.id,
                                  ),
                              ],

                              // Poll
                              if (post.pollData != null) ...[
                                const SizedBox(height: 16),
                                PollWidget(post: post, repo: repo),
                              ],

                              const SizedBox(height: 16),

                              // Timestamp and Platform
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat(
                                      'h:mm a · MMM d, yyyy',
                                    ).format(displayTimestamp),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),
                              const Divider(),

                              // Stats Row
                              if (post.repostCount > 0 ||
                                  post.likesCount > 0 ||
                                  post.commentsCount > 0 ||
                                  post.savesCount > 0) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4.0,
                                  ),
                                  child: Row(
                                    children: [
                                      if (post.commentsCount > 0) ...[
                                        _StatText(
                                          count: post.commentsCount,
                                          label: post.commentsCount == 1
                                              ? 'Comment'
                                              : 'Comments',
                                        ),
                                        const SizedBox(width: 20),
                                      ],
                                      if (post.repostCount > 0) ...[
                                        _StatText(
                                          count: post.repostCount,
                                          label: 'Reposts',
                                        ),
                                        const SizedBox(width: 20),
                                      ],
                                      if (post.likesCount > 0) ...[
                                        _StatText(
                                          count: post.likesCount,
                                          label: 'Likes',
                                        ),
                                        const SizedBox(width: 20),
                                      ],
                                      if (post.savesCount > 0)
                                        _StatText(
                                          count: post.savesCount,
                                          label: post.savesCount == 1
                                              ? 'Save'
                                              : 'Saves',
                                        ),
                                    ],
                                  ),
                                ),
                                const Divider(),
                              ],

                              // Action Bar
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      CupertinoIcons.chat_bubble,
                                    ),
                                    onPressed: () {
                                      // Focus logic handled by placing focus node or just tapping the bottom field
                                    },
                                    color: isDark
                                        ? Colors.grey[500]
                                        : Colors.grey[600],
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      CupertinoIcons.arrow_2_squarepath,
                                    ),
                                    onPressed: () =>
                                        _showRepostBottomSheet(post),
                                    color: isDark
                                        ? Colors.grey[500]
                                        : Colors.grey[600],
                                  ),
                                  StreamBuilder<bool>(
                                    stream: isLikedStream,
                                    builder: (context, snapshot) {
                                      final isLiked = snapshot.data ?? false;
                                      return AnimatedLikeButton(
                                        isLiked: isLiked,
                                        count: 0,
                                        showCount: false,
                                        iconSize: 22,
                                        inactiveColor: isDark
                                            ? Colors.grey[500]
                                            : Colors.grey[600],
                                        onTap: () => repo.toggleLike(post.id),
                                      );
                                    },
                                  ),
                                  Consumer(
                                    builder: (context, ref, child) {
                                      final optimisticSaveMap = ref.watch(
                                        optimisticSaveProvider,
                                      );
                                      final apiSaved =
                                          ref
                                              .watch(
                                                isPostSavedProvider(post.id),
                                              )
                                              .value ??
                                          post.isSaved;
                                      final isSaved =
                                          optimisticSaveMap.containsKey(post.id)
                                          ? optimisticSaveMap[post.id]!
                                          : apiSaved;
                                      const goldColor = Color(0xFFFFB800);

                                      return IconButton(
                                        icon: Icon(
                                          isSaved
                                              ? CupertinoIcons.bookmark_solid
                                              : CupertinoIcons.bookmark,
                                          color: isSaved
                                              ? goldColor
                                              : (isDark
                                                    ? Colors.grey[500]
                                                    : Colors.grey[600]),
                                        ),
                                        onPressed: () async {
                                          HapticFeedback.lightImpact();
                                          ref
                                              .read(
                                                optimisticSaveProvider.notifier,
                                              )
                                              .toggle(post.id, apiSaved);
                                          try {
                                            await ref
                                                .read(postRepositoryProvider)
                                                .togglePostSave(post.id);
                                            ref
                                                .read(
                                                  optimisticSaveProvider
                                                      .notifier,
                                                )
                                                .confirm(post.id);
                                          } catch (_) {
                                            ref
                                                .read(
                                                  optimisticSaveProvider
                                                      .notifier,
                                                )
                                                .revert(post.id, apiSaved);
                                          }
                                        },
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(CupertinoIcons.share),
                                    onPressed: () {
                                      SharePlus.instance.share(
                                        ShareParams(
                                          text:
                                              '${post.authorName} (@${post.authorHandle}): ${post.content}\n\nSent from Abuad life',
                                        ),
                                      );
                                    },
                                    color: isDark
                                        ? Colors.grey[500]
                                        : Colors.grey[600],
                                  ),
                                ],
                              ),
                              const Divider(),
                            ],
                          ),
                        ),

                        // Comments List
                        StreamBuilder<List<Map<String, dynamic>>>(
                          stream: commentsStream,
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return Center(
                                child: Text('Error: ${snapshot.error}'),
                              );
                            }

                            final rawComments = snapshot.data ?? [];
                            return CommentThreadView(
                              post: post,
                              comments: rawComments,
                              onReply: _onReply,
                              onMenu: _showCommentMenu,
                              currentUserId: currentUserId,
                              isScrollable: false,
                            );
                          },
                        ),
                        // Add some bottom padding so content isn't hidden by input
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),

                // Sticky Comment Input
                SafeArea(
                  top: false,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      border: Border(
                        top: BorderSide(
                          color: isDark ? Colors.grey[900]! : Colors.grey[200]!,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Reply Indicator
                        if (_replyToCommentId != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            color: AppColors.secondaryTeal.withValues(
                              alpha: 0.1,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  "Replying to ",
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  "@$_replyToUserName",
                                  style: TextStyle(
                                    color: AppColors.secondaryTeal,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: _cancelReply,
                                  child: Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Visibility Indicator
                        if (_replyToCommentId == null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.public,
                                  size: 13,
                                  color: AppColors.secondaryTeal.withValues(
                                    alpha: 0.8,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "Everyone can reply",
                                  style: TextStyle(
                                    color: AppColors.secondaryTeal.withValues(
                                      alpha: 0.8,
                                    ),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        Padding(
                          padding: EdgeInsets.only(
                            left: 12,
                            right: 12,
                            top: 6,
                            bottom: max(
                              MediaQuery.of(context).padding.bottom > 0
                                  ? 6
                                  : 12,
                              12,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              UserAvatar(
                                userId: currentUserId ?? '',
                                avatarUrl: currentUser?.avatarUrl,
                                displayName: currentUser?.displayName,
                                radius: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white12
                                          : Colors.grey[300]!,
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _commentController,
                                    cursorColor: AppColors.secondaryTeal,
                                    maxLines: 4,
                                    minLines: 1,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Post your reply',
                                      hintStyle: TextStyle(
                                        fontSize: 14,
                                        color: isDark
                                            ? Colors.grey[400]
                                            : Colors.grey[500],
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 10,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                onPressed: _isPosting ? null : _postComment,
                                icon: _isPosting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.secondaryTeal,
                                        ),
                                      )
                                    : const Icon(
                                        CupertinoIcons.arrow_up_circle_fill,
                                        color: AppColors.secondaryTeal,
                                        size: 30,
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHighlightedContent(
    BuildContext context,
    String text,
    ThemeData theme,
    WidgetRef ref,
  ) {
    if (text.isEmpty) return const SizedBox.shrink();
    final isDark = theme.brightness == Brightness.dark;
    return AbuadMarkdownContent(
      content: text,
      textStyle: TextStyle(
        fontSize: 18,
        height: 1.4,
        color:
            theme.textTheme.bodyLarge?.color ??
            (isDark ? Colors.white : Colors.black87),
      ),
    );
  }

  Widget _buildQuotedPost(
    BuildContext context,
    Map<String, dynamic> data,
    bool isDark,
  ) {
    final mediaUrl = data['media_url'] as String?;
    final timestampStr = data['timestamp'] as String?;
    final timestamp = timestampStr != null
        ? DateTime.tryParse(timestampStr) ?? DateTime.now()
        : DateTime.now();

    return GestureDetector(
      onTap: () {
        // Create a basic post from map for the detail screen
        final originalPost = domain.Post.fromMap(data);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(post: originalPost),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  data['author_name'] ?? 'Unknown',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '@${data['author_handle'] ?? ''}',
                  style: TextStyle(
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  timeago.format(timestamp, locale: 'en_short'),
                  style: TextStyle(
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              data['content'] ?? '',
              style: const TextStyle(fontSize: 14, height: 1.3),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (mediaUrl != null && mediaUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: (() {
                  final formattedMedia = UrlValidator.formatImageUrl(mediaUrl);
                  return (formattedMedia.isNotEmpty &&
                          UrlValidator.isValidUrl(formattedMedia))
                      ? CachedNetworkImage(
                          imageUrl: formattedMedia,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : const SizedBox();
                })(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatText extends StatelessWidget {
  final int count;
  final String label;

  const _StatText({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$count',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 15)),
      ],
    );
  }
}


