import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/post_repository.dart';
import '../../domain/post.dart' as domain;
import '../post_detail_screen.dart';
import 'animated_like_button.dart';

class PostCard extends ConsumerWidget {
  final domain.Post post;
  final VoidCallback? onTap;

  const PostCard({super.key, required this.post, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(postRepositoryProvider);
    final isLikedStream = repo.isPostLiked(post.id);

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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
                    ? Colors.grey[800]
                    : Colors.grey[200],
                backgroundImage: null,
                child: post.isAnonymous
                    ? const Icon(
                        Icons.person_outline,
                        color: Colors.white,
                        size: 20,
                      )
                    : Text(
                        post.authorName.isNotEmpty
                            ? post.authorName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Color(0xFF0D47A1),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (post.isVerified && !post.isAnonymous) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          size: 14,
                          color: Colors.blue,
                        ),
                      ],
                      if (!post.isAnonymous) ...[
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '@${post.authorHandle}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      Text(
                        ' • ${timeago.format(post.timestamp, locale: 'en_short')}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.more_horiz,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Post Content
                  if (post.content.isNotEmpty)
                    Text(
                      post.content,
                      style: const TextStyle(fontSize: 15, height: 1.3),
                    ),

                  // Repost (Quote) Rendering
                  if (post.repostData != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey[50], // Light background for quote
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
                                  color: Colors.grey[600],
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
                                  color: Colors.grey[600],
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
                              child: Image.network(
                                post.repostData!['mediaUrl'],
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
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "📊 ${post.pollData?['question'] ?? 'Poll'}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...(post.pollData?['options'] as List<dynamic>? ?? [])
                              .map<Widget>((option) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.blue.withOpacity(0.2),
                                      ),
                                    ),
                                    child: Text(
                                      option.toString(),
                                      style: const TextStyle(
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                                );
                              })
                              .toList(),
                          const Text(
                            "Tap an option to vote",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Media (Image)
                  if (post.mediaUrl.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        post.mediaUrl,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 200,
                            color: Colors.grey[100],
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
                        color: Colors.grey,
                        onTap: () {
                          context.push('/post-detail', extra: post);
                        },
                      ),
                      // Repost Button
                      _ActionButton(
                        icon: Icons.repeat,
                        count: post.repostCount,
                        color: Colors.green,
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
                        color: Colors.grey,
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

  void _showRepostBottomSheet(
    BuildContext context,
    WidgetRef ref,
    domain.Post originalPost,
  ) {
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
                // User Avatar (Placeholder or Current User if we had access)
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
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  if (originalPost.mediaUrl.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        originalPost.mediaUrl,
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
                          style: TextStyle(color: Colors.grey[800]),
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
                  ? Colors.grey
                  : (count! > 0 ? color : Colors.grey),
            ),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 4), // Reduced spacing
              Text(
                '$count',
                style: TextStyle(
                  color: count! > 0 ? color : Colors.grey,
                  fontSize: 12, // Slightly smaller font
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
