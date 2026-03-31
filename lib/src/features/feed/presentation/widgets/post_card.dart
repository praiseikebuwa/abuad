import 'package:abuad/src/features/user/data/user_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/verification_badge.dart';
import 'package:abuad/src/features/feed/data/post_repository.dart';
import '../../domain/post.dart' as domain;

import '../post_detail_screen.dart';
import 'animated_like_button.dart';
import 'poll_widget.dart';
import 'video_post_widget.dart';
import '../../domain/report.dart';
import 'report_bottom_sheet.dart';
import 'full_screen_image_view.dart';
import 'full_screen_video_view.dart';

class PostCard extends ConsumerWidget {
  final domain.Post post;
  final VoidCallback? onTap;

  const PostCard({super.key, required this.post, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(postRepositoryProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Determine if this is a "Pure Repost" (no added commentary)
    final isPureRepost = post.repostData != null && post.content.trim().isEmpty;

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
        : post.isAnonymous;

    // Media Type Enum Conversion
    domain.MediaType displayMediaType = post.mediaType;
    if (isPureRepost && displayMediaTypeStr != null) {
      displayMediaType = domain.MediaType.values.firstWhere(
        (e) => e.name == displayMediaTypeStr,
        orElse: () => domain.MediaType.none,
      );
    } else if (isPureRepost && displayMediaUrl.isNotEmpty) {
      // Fallback logic for pure repost media type if string is missing
      if (displayMediaUrl.endsWith('.mp4')) {
        displayMediaType = domain.MediaType.video;
      } else if (displayMediaUrl.contains('giphy') ||
          displayMediaUrl.endsWith('.gif')) {
        displayMediaType = domain.MediaType.gif;
      } else {
        displayMediaType = domain.MediaType.image;
      }
    }

    // Determine author ID to watch
    final authorIdToWatch = isPureRepost
        ? post.repostData!['author_id']
        : post.authorId;
    final shouldWatch = !displayIsAnonymous && authorIdToWatch != null;

    return InkWell(
      onTap:
          onTap ??
          () {
            // If pure repost, navigate to ORIGINAL post
            if (isPureRepost && post.repostData != null) {
              final originalPost = domain.Post.fromMap(post.repostData!);
              if (originalPost.id.isEmpty) return; // Safety check
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PostDetailScreen(post: originalPost),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PostDetailScreen(post: post),
                ),
              );
            }
          },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(color: Colors.transparent),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Repost Header (Only for Pure Repost)
            if (isPureRepost)
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0, left: 34.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.repeat,
                      size: 16,
                      color: AppColors.secondaryTeal,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${post.authorName} reposted',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            StreamBuilder<AppUser?>(
              stream: shouldWatch
                  ? ref.read(userRepositoryProvider).watchUser(authorIdToWatch!)
                  : const Stream.empty(),
              builder: (context, snapshot) {
                final user = snapshot.data;
                final effectiveAuthorName =
                    user?.displayName ?? displayAuthorName;
                final effectiveAuthorHandle =
                    user?.handle ?? displayAuthorHandle;
                final effectiveAvatarUrl = user?.avatarUrl ?? displayAvatarUrl;
                final effectiveIsVerified =
                    user?.isVerified ?? displayIsVerified;
                final effectiveVerificationType =
                    user?.verificationType ?? displayVerificationType;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Avatar (Displayed Author)
                    GestureDetector(
                      onTap: () {
                        if (!displayIsAnonymous && authorIdToWatch != null) {
                          context.push('/user/$authorIdToWatch');
                        }
                      },
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: displayIsAnonymous
                            ? (isDark ? Colors.grey[700] : Colors.grey[800])
                            : (isDark ? Colors.grey[800] : Colors.grey[200]),
                        backgroundImage:
                            (effectiveAvatarUrl != null && !displayIsAnonymous)
                            ? CachedNetworkImageProvider(effectiveAvatarUrl)
                            : null,
                        child: displayIsAnonymous
                            ? const Icon(
                                Icons.person_outline,
                                color: Colors.white,
                                size: 22,
                              )
                            : (effectiveAvatarUrl == null
                                  ? Text(
                                      effectiveAuthorName.isNotEmpty
                                          ? effectiveAuthorName[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    )
                                  : null),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Right Column: Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Name, Verified, Handle, Dot, Time
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  displayIsAnonymous
                                      ? 'Anonymous Student'
                                      : effectiveAuthorName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    letterSpacing: -0.2,
                                    color: theme.textTheme.bodyLarge?.color,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              if (effectiveIsVerified &&
                                  !displayIsAnonymous) ...[
                                const SizedBox(width: 4),
                                VerificationBadge(
                                  type: effectiveVerificationType,
                                  size: 16,
                                ),
                              ],
                              if (!displayIsAnonymous) ...[
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '@$effectiveAuthorHandle',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.grey[500]
                                          : Colors.grey[600],
                                      fontSize: 14,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              Text(
                                ' • ${timeago.format(displayTimestamp, locale: 'en_short')}',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey[500]
                                      : Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Follow Button
                              Consumer(
                                builder: (context, ref, child) {
                                  final currentUser = ref
                                      .watch(currentUserProvider)
                                      .value;
                                  if (currentUser?.uid == post.authorId ||
                                      post.isAnonymous) {
                                    return const SizedBox.shrink();
                                  }
                                  final isFollowingAsync = ref.watch(
                                    isFollowingProvider(post.authorId),
                                  );
                                  return isFollowingAsync.when(
                                    data: (isFollowing) {
                                      if (isFollowing) {
                                        return const SizedBox.shrink();
                                      }
                                      return GestureDetector(
                                        onTap: () {
                                          ref
                                              .read(userRepositoryProvider)
                                              .followUser(post.authorId);
                                        },
                                        child: Text(
                                          'Follow',
                                          style: TextStyle(
                                            color: AppColors.secondaryTeal,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      );
                                    },
                                    loading: () => const SizedBox.shrink(),
                                    error: (_, __) => const SizedBox.shrink(),
                                  );
                                },
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () =>
                                    _showPostMenu(context, ref, post),
                                icon: Icon(
                                  Icons.more_horiz,
                                  size: 18,
                                  color: isDark
                                      ? Colors.grey[500]
                                      : Colors.grey[600],
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          if (post.latitude != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    size: 12,
                                    color: AppColors.secondaryTeal,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "ABUAD Campus",
                                    style: TextStyle(
                                      color: AppColors.secondaryTeal,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Post Content
                          if (displayContent.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: _buildHighlightedContent(
                                context,
                                displayContent,
                                theme,
                                ref,
                              ),
                            ),

                          // Repost (Quote) Rendering
                          if (!isPureRepost && post.repostData != null) ...[
                            GestureDetector(
                              onTap: () {
                                final originalPost = domain.Post.fromMap(
                                  post.repostData!,
                                );
                                context.push(
                                  '/post/${originalPost.id}',
                                  extra: originalPost,
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(
                                  bottom: 12,
                                  top: 4,
                                ),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.03)
                                      : Colors.black.withValues(alpha: 0.02),
                                  border: Border.all(
                                    color: isDark
                                        ? AppColors.borderDark
                                        : AppColors.borderLight,
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        if (post.repostData!['author_avatar_url'] !=
                                            null) ...[
                                          CircleAvatar(
                                            radius: 10,
                                            backgroundImage:
                                                CachedNetworkImageProvider(
                                                  post.repostData!['author_avatar_url'],
                                                ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        Flexible(
                                          child: Text(
                                            post.repostData!['author_name'] ??
                                                'Unknown',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            '@${post.repostData!['author_handle'] ?? ''}',
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.grey[500]
                                                  : Colors.grey[600],
                                              fontSize: 13,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          ' • ${timeago.format(DateTime.tryParse(post.repostData!['timestamp'] ?? '') ?? DateTime.now(), locale: 'en_short')}',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[500]
                                                : Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if ((post.repostData!['content'] as String?)
                                            ?.isNotEmpty ??
                                        false)
                                      Text(
                                        post.repostData!['content'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          height: 1.3,
                                        ),
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    if ((post.repostData!['media_url']
                                                as String?)
                                            ?.isNotEmpty ??
                                        false) ...[
                                      const SizedBox(height: 10),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: CachedNetworkImage(
                                          imageUrl:
                                              post.repostData!['media_url'],
                                          height: 160,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],

                          // Poll Rendering
                          if (post.pollData != null) ...[
                            PollWidget(post: post, repo: repo),
                            const SizedBox(height: 12),
                          ],

                          // Media (Displayed - Original or Reposted)
                          if (displayMediaUrl.isNotEmpty) ...[
                            GestureDetector(
                              onTap: () {
                                if (displayMediaType ==
                                    domain.MediaType.video) {
                                  // View Video in Full Screen
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => FullScreenVideoView(
                                        videoUrl: displayMediaUrl,
                                        heroTag: 'post_media_${post.id}',
                                      ),
                                    ),
                                  );
                                } else {
                                  // View Image in Full Screen
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => FullScreenImageView(
                                        imageUrl: displayMediaUrl,
                                        heroTag: 'post_media_${post.id}',
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Hero(
                                tag: 'post_media_${post.id}',
                                child:
                                    displayMediaType == domain.MediaType.video
                                    ? VideoPostWidget(videoUrl: displayMediaUrl)
                                    : CachedNetworkImage(
                                        imageUrl: displayMediaUrl,
                                        height: 250,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorWidget: (context, url, error) =>
                                            Container(
                                              height: 250,
                                              color: Colors.black,
                                              child: const Icon(
                                                Icons.broken_image_outlined,
                                                color: Colors.white,
                                                size: 48,
                                              ),
                                            ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Actions Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _ActionButton(
                                icon: Icons.chat_bubble_outline,
                                count: post.commentsCount,
                                color: isDark
                                    ? Colors.grey[500]!
                                    : Colors.grey[600]!,
                                onTap: () => context.push(
                                  '/post/${post.id}',
                                  extra: post,
                                ),
                              ),
                              _ActionButton(
                                icon: Icons.repeat,
                                count: post.repostCount,
                                color: AppColors.secondaryTeal,
                                onTap: () {
                                  _showRepostBottomSheet(context, ref, post);
                                },
                              ),
                              Consumer(
                                builder: (context, ref, child) {
                                  final isLiked =
                                      ref
                                          .watch(isPostLikedProvider(post.id))
                                          .value ??
                                      false;
                                  return AnimatedLikeButton(
                                    isLiked: isLiked,
                                    count: post.likesCount,
                                    onTap: () {
                                      ref
                                          .read(postRepositoryProvider)
                                          .toggleLike(post.id);
                                    },
                                  );
                                },
                              ),
                              Consumer(
                                builder: (context, ref, child) {
                                  final isSavedAsync = ref.watch(
                                    isPostSavedProvider(post.id),
                                  );
                                  final isSaved = isSavedAsync.value ?? false;

                                  return _ActionButton(
                                    icon: isSaved
                                        ? Icons.bookmark
                                        : Icons.bookmark_border,
                                    count: null, // Private action
                                    color: isSaved
                                        ? AppColors.secondaryTeal
                                        : (isDark
                                              ? Colors.grey[500]!
                                              : Colors.grey[600]!),
                                    onTap: () {
                                      ref
                                          .read(userRepositoryProvider)
                                          .togglePostSave(post.id);
                                    },
                                  );
                                },
                              ),
                              _ActionButton(
                                icon: Icons.share_outlined,
                                count: null,
                                color: isDark
                                    ? Colors.grey[500]!
                                    : Colors.grey[600]!,
                                onTap: () {
                                  Share.share(
                                    'Check out this post on ABUAD Nest: https://abuadapp.web.app/post/${post.id}',
                                    subject: 'Check out this post on ABUAD',
                                  );
                                },
                              ),
                              const SizedBox(width: 8), // Extra edge padding
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0, duration: 300.ms);
  }

  static void _showPostMenu(
    BuildContext context,
    WidgetRef ref,
    domain.Post post,
  ) {
    final repo = ref.read(postRepositoryProvider);
    final currentUserId = repo.currentUserId;
    final isOwnPost = post.authorId == currentUserId;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOwnPost)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete Post',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Post'),
                      content: const Text(
                        'Are you sure you want to delete this post? This action cannot be undone.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    try {
                      await repo.deletePost(post.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Post deleted')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
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
                  leading: Icon(
                    isSaved ? Icons.bookmark : Icons.bookmark_border,
                    color: isSaved ? AppColors.secondaryTeal : null,
                  ),
                  title: Text(isSaved ? 'Unsave Post' : 'Save Post'),
                  onTap: () {
                    Navigator.pop(context);
                    ref.read(userRepositoryProvider).togglePostSave(post.id);
                  },
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share Post'),
              onTap: () {
                Navigator.pop(context);
                Share.share(
                  'Check out this post on ABUAD Nest: https://abuadapp.web.app/post/${post.id}',
                );
              },
            ),
            if (post.mediaUrl.isNotEmpty &&
                (post.mediaType == domain.MediaType.image ||
                    post.mediaType == domain.MediaType.gif))
              ListTile(
                leading: const Icon(Icons.download),
                title: Text(
                  post.mediaType == domain.MediaType.video
                      ? 'Save Video'
                      : 'Save Image',
                ),
                onTap: () {
                  Navigator.pop(context);
                  if (post.mediaType == domain.MediaType.video) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FullScreenVideoView(
                          videoUrl: post.mediaUrl,
                          heroTag: 'post_media_${post.id}',
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FullScreenImageView(
                          imageUrl: post.mediaUrl,
                          heroTag: 'post_media_${post.id}',
                        ),
                      ),
                    );
                  }
                },
              ),
            if (!isOwnPost)
              ListTile(
                leading: const Icon(Icons.block, color: Colors.orange),
                title: const Text(
                  'Block User',
                  style: TextStyle(color: Colors.orange),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Block User?'),
                      content: Text(
                        'Are you sure you want to block ${post.authorName}? You will no longer see their posts and they won\'t be able to message you.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.orange,
                          ),
                          child: const Text('Block'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    await ref
                        .read(userRepositoryProvider)
                        .blockUser(post.authorId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${post.authorName} blocked')),
                      );
                    }
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.report_outlined),
              title: const Text('Report Post'),
              onTap: () {
                Navigator.pop(context);
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

  void _showRepostBottomSheet(
    BuildContext context,
    WidgetRef ref,
    domain.Post originalPost,
  ) {
    final commentController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
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
                  onPressed: () {
                    ref
                        .read(postRepositoryProvider)
                        .repost(originalPost, commentController.text);
                    Navigator.pop(context);
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
                // User Avatar
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.person, color: Colors.white, size: 20),
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
            // Quoted Post Preview
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
                        imageUrl: originalPost.mediaUrl,
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
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          originalPost.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[800],
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
    );
  }

  Widget _buildHighlightedContent(
    BuildContext context,
    String text,
    ThemeData theme,
    WidgetRef ref,
  ) {
    if (text.isEmpty) return const SizedBox.shrink();

    final List<TextSpan> spans = [];
    // Regex to match mentions, hashtags, or normal text
    final pattern = RegExp(r"(@[\w]+|#[\w]+|[^\s@#]+|\s+)");
    final matches = pattern.allMatches(text);

    for (final match in matches) {
      final part = match.group(0)!;

      if (part.startsWith('#')) {
        final tag = part.substring(1);
        spans.add(
          TextSpan(
            text: part,
            style: const TextStyle(
              color: AppColors.secondaryTeal,
              fontWeight: FontWeight.bold,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                context.push('/hashtag/$tag');
              },
          ),
        );
      } else if (part.startsWith('@')) {
        final handle = part.substring(1);
        spans.add(
          TextSpan(
            text: part,
            style: const TextStyle(
              color: AppColors.secondaryTeal,
              fontWeight: FontWeight.bold,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () async {
                final user = await ref
                    .read(userRepositoryProvider)
                    .getUserByHandle(handle);
                if (context.mounted) {
                  if (user != null) {
                    context.push('/user/${user.uid}');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('User not found')),
                    );
                  }
                }
              },
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: part,
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color ?? Colors.black,
            ),
          ),
        );
      }
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 15, height: 1.3),
        children: spans,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final int? count;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.count,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque, // Ensure tap target
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 6.0, // Reduced padding for compact fit
          vertical: 8.0,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: count == null
                  ? color // Use passed color (grey/themed)
                  : (count! > 0 ? color : color.withValues(alpha: 0.7)),
            ),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
