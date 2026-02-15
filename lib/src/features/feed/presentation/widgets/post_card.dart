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
import '../../data/post_repository.dart';
import '../../domain/post.dart' as domain;
import '../../../../features/user/data/user_repository.dart';
import '../post_detail_screen.dart';
import 'animated_like_button.dart';
import 'poll_widget.dart';
import 'video_post_widget.dart';

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

    return InkWell(
      onTap:
          onTap ??
          () {
            // If pure repost, navigate to ORIGINAL post
            if (isPureRepost && post.repostData != null) {
              final originalPost = domain.Post.fromMap(post.repostData!);
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
                padding: const EdgeInsets.only(bottom: 8.0, left: 34.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.repeat,
                      size: 14,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${post.authorName} reposted',
                      style: TextStyle(
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Avatar (Displayed Author)
                GestureDetector(
                  onTap: () {
                    final authorIdForNavigation = isPureRepost
                        ? post.repostData!['author_id']
                        : post.authorId;
                    if (!displayIsAnonymous && authorIdForNavigation != null) {
                      context.push('/user/$authorIdForNavigation');
                    }
                  },
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: displayIsAnonymous
                        ? (isDark ? Colors.grey[700] : Colors.grey[800])
                        : (isDark ? Colors.grey[800] : Colors.grey[200]),
                    backgroundImage:
                        (displayAvatarUrl != null && !displayIsAnonymous)
                        ? CachedNetworkImageProvider(displayAvatarUrl)
                        : null,
                    child: displayIsAnonymous
                        ? const Icon(
                            Icons.person_outline,
                            color: Colors.white,
                            size: 22,
                          )
                        : (displayAvatarUrl == null
                              ? Text(
                                  displayAuthorName.isNotEmpty
                                      ? displayAuthorName[0].toUpperCase()
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
                                  : displayAuthorName,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                letterSpacing: -0.2,
                                color: theme.textTheme.bodyLarge?.color,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          if (displayIsVerified && !displayIsAnonymous) ...[
                            const SizedBox(width: 4),
                            VerificationBadge(
                              type: displayVerificationType,
                              size: 16,
                            ),
                          ],
                          if (!displayIsAnonymous) ...[
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '@$displayAuthorHandle',
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
                                  if (isFollowing)
                                    return const SizedBox.shrink();
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
                            onPressed: () => _showPostMenu(context, ref, post),
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
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isDark
                                  ? AppColors.borderDark
                                  : AppColors.borderLight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    post.repostData!['author_name'] ??
                                        'Unknown',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '@${post.repostData!['author_handle'] ?? ''}',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.grey[500]
                                          : Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    timeago.format(
                                      DateTime.tryParse(
                                            post.repostData!['timestamp'] ?? '',
                                          ) ??
                                          DateTime.now(),
                                      locale: 'en_short',
                                    ),
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.grey[500]
                                          : Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                post.repostData!['content'] ?? '',
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.3,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if ((post.repostData!['media_url'] as String?)
                                      ?.isNotEmpty ??
                                  false) ...[
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CachedNetworkImage(
                                    imageUrl: post.repostData!['media_url'],
                                    height: 150,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ],
                            ],
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
                            final mediaPost = isPureRepost
                                ? domain.Post.fromMap(post.repostData!)
                                : post;
                            if (displayMediaType == domain.MediaType.video) {
                              // Navigate to Reels Screen
                              context.push(
                                '/reels',
                                extra: {
                                  'videos': [mediaPost],
                                  'index': 0,
                                },
                              );
                            } else {
                              // View Image etc
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      PostDetailScreen(post: mediaPost),
                                ),
                              );
                            }
                          },
                          child: displayMediaType == domain.MediaType.video
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
                        const SizedBox(height: 12),
                      ],

                      // Actions Row: Reply, Repost, Like, Share
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _ActionButton(
                            icon: Icons.chat_bubble_outline,
                            count: post.commentsCount,
                            color: isDark
                                ? Colors.grey[500]!
                                : Colors.grey[600]!,
                            onTap: () {
                              context.push('/post-detail', extra: post);
                            },
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
                          _ActionButton(
                            icon: Icons.remove_red_eye_outlined,
                            count: post.viewsCount,
                            color: isDark
                                ? Colors.grey[500]!
                                : Colors.grey[600]!,
                            onTap: () {
                              ref
                                  .read(postRepositoryProvider)
                                  .incrementViewCount(post.id);
                              _showPostAnalytics(context, post);
                            },
                          ),
                          _ActionButton(
                            icon: Icons.share_outlined,
                            count: null,
                            color: isDark
                                ? Colors.grey[500]!
                                : Colors.grey[600]!,
                            onTap: () {
                              final text =
                                  '${post.authorName} (@${post.authorHandle}): ${post.content}\n\nSent from ABUAD Nest';
                              // ignore: deprecated_member_use
                              Share.share(
                                text,
                                subject: 'Check out this post on ABUAD Nest',
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
            ListTile(
              leading: const Icon(Icons.report_outlined),
              title: const Text('Report Post'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report feature coming soon')),
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

  static void _showPostAnalytics(BuildContext context, domain.Post post) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600]!.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Icon(
                  Icons.analytics_outlined,
                  size: 48,
                  color: AppColors.secondaryTeal,
                )
                .animate()
                .scale(
                  delay: 100.ms,
                  duration: 400.ms,
                  curve: Curves.easeOutBack,
                )
                .rotate(begin: -0.1, end: 0),
            const SizedBox(height: 16),
            Text(
              'Post Analytics',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAnalyticItem(
                  'Total Views',
                  '${post.viewsCount}',
                  Icons.remove_red_eye_outlined,
                  AppColors.secondaryTeal,
                  isDark,
                ),
                _buildAnalyticItem(
                  'Engagements',
                  '${post.likesCount + post.commentsCount + post.repostCount}',
                  Icons.auto_graph,
                  Colors.orange,
                  isDark,
                ),
              ],
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildAnalyticItem(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ).animate().fadeIn(duration: 400.ms).scale(delay: 200.ms),
        const SizedBox(height: 12),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ).animate().slideY(begin: 0.5, end: 0, delay: 300.ms).fadeIn(),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            letterSpacing: 0.5,
          ),
        ),
      ],
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
                  : (count! > 0 ? color : color.withOpacity(0.7)),
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
