import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/post_repository.dart';
import '../../domain/post.dart' as domain;
import '../post_detail_screen.dart';
import 'animated_like_button.dart';
import 'poll_widget.dart';

class PostCard extends ConsumerWidget {
  final domain.Post post;
  final VoidCallback? onTap;

  const PostCard({super.key, required this.post, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(postRepositoryProvider);
    final isLikedStream = repo.isPostLiked(post.id);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap:
          onTap ??
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostDetailScreen(post: post),
              ),
            );
          },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
          boxShadow: AppColors.softShadow,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            GestureDetector(
              onTap: () {
                if (!post.isAnonymous) {
                  context.push('/user/${post.authorId}');
                }
              },
              child: CircleAvatar(
                radius: 20,
                backgroundColor: post.isAnonymous
                    ? (isDark ? Colors.grey[700] : Colors.grey[800])
                    : (isDark ? Colors.grey[800] : Colors.grey[200]),
                backgroundImage:
                    (post.authorAvatarUrl != null && !post.isAnonymous)
                    ? CachedNetworkImageProvider(post.authorAvatarUrl!)
                    : null,
                child: post.isAnonymous
                    ? const Icon(
                        Icons.person_outline,
                        color: Colors.white,
                        size: 20,
                      )
                    : (post.authorAvatarUrl == null
                          ? Text(
                              post.authorName.isNotEmpty
                                  ? post.authorName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null),
              ),
            ),
            const SizedBox(width: 12),

            // Content Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Metadata Row: Name, Verified, Handle, Time
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          post.isAnonymous
                              ? 'Anonymous Student'
                              : post.authorName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: theme.textTheme.bodyLarge?.color,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (post.isVerified && !post.isAnonymous) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          size: 14,
                          color: AppColors.secondaryTeal,
                        ),
                      ],
                      if (!post.isAnonymous) ...[
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '@${post.authorHandle}',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              fontSize: 14,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      Text(
                        ' • ${timeago.format(post.timestamp, locale: 'en_short')}',
                        style: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _showPostMenu(context, ref, post),
                        child: Icon(
                          Icons.more_horiz,
                          size: 16,
                          color: isDark ? Colors.grey[500] : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Post Content
                  if (post.content.isNotEmpty)
                    Text(
                      post.content,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.3,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),

                  // Repost (Quote) Rendering
                  if (post.repostData != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isDark
                              ? AppColors.borderDark
                              : AppColors.borderLight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : AppColors.surfaceLight,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                post.repostData!['authorName'] ?? 'Unknown',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '@${post.repostData!['authorHandle'] ?? ''}',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey[400]
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
                            style: const TextStyle(fontSize: 14, height: 1.3),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // Optional: Show media thumbnail if original post had media
                          if ((post.repostData!['mediaUrl'] as String?)
                                  ?.isNotEmpty ??
                              false) ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: post.repostData!['mediaUrl'],
                                height: 150,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: isDark
                                      ? Colors.grey[800]
                                      : Colors.grey[200],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // Poll Rendering
                  if (post.pollData != null) ...[
                    const SizedBox(height: 12),
                    PollWidget(post: post, repo: repo),
                  ],

                  // Media (Image)
                  if (post.mediaUrl.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: post.mediaUrl,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 200,
                          color: isDark ? Colors.grey[800] : Colors.grey[100],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) {
                          return Container(
                            height: 200,
                            color: isDark ? Colors.grey[800] : Colors.grey[100],
                            child: const Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Actions Row: Reply, Retweet, Like, Share
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _ActionButton(
                        icon: Icons.chat_bubble_outline,
                        count: post.commentsCount,
                        color: isDark ? Colors.grey[400]! : Colors.grey,
                        onTap: () {
                          context.push('/post-detail', extra: post);
                        },
                      ),
                      // Repost Button
                      _ActionButton(
                        icon: Icons.repeat,
                        count: post.repostCount,
                        color: AppColors.secondaryTeal,
                        onTap: () {
                          _showRepostBottomSheet(context, ref, post);
                        },
                      ),
                      StreamBuilder<bool>(
                        stream: isLikedStream,
                        builder: (context, snapshot) {
                          final isLiked = snapshot.data ?? false;
                          return AnimatedLikeButton(
                            isLiked: isLiked,
                            count: post.likesCount,
                            onTap: () {
                              repo.toggleLike(post.id);
                            },
                          );
                        },
                      ),
                      _ActionButton(
                        icon: Icons.share_outlined,
                        count: null,
                        color: isDark ? Colors.grey[400]! : Colors.grey,
                        onTap: () {
                          Share.share(
                            '${post.authorName} (@${post.authorHandle}): ${post.content}\n\nSent from ABUAD Nest',
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
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
