import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_animate/flutter_animate.dart';
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
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                GestureDetector(
                  onTap: () {
                    context.push('/user/${post.authorId}');
                  },
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Theme.of(
                      context,
                    ).primaryColor.withOpacity(0.1),
                    backgroundImage: null,
                    child: Text(
                      post.authorName.isNotEmpty
                          ? post.authorName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              post.authorName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          if (post.isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified,
                              size: 14,
                              color: Colors.blue,
                            ),
                          ],
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              post.authorHandle,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 15,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          Text(
                            ' · ${timeago.format(post.timestamp, locale: 'en_short')}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 15,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.more_horiz,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      // Text Content
                      Text(
                        post.content,
                        style: const TextStyle(fontSize: 15, height: 1.3),
                      ),

                      // Media (Placeholder)
                      if (post.mediaUrl.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: const Center(
                            child: Icon(Icons.image, color: Colors.grey),
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Action Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _ActionButton(
                            icon: Icons.chat_bubble_outline,
                            count: post.commentsCount,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      PostDetailScreen(post: post),
                                ),
                              );
                            },
                          ),
                          _ActionButton(
                            icon: Icons.repeat,
                            count: 0,
                            onTap: () {},
                          ),
                          StreamBuilder<bool>(
                            stream: isLikedStream,
                            builder: (context, snapshot) {
                              final isLiked = snapshot.data ?? false;
                              return AnimatedLikeButton(
                                isLiked: isLiked,
                                count: post.likesCount,
                                onTap: () => repo.toggleLike(post.id),
                              );
                            },
                          ),
                          _ActionButton(
                            icon: Icons.share_outlined,
                            count: null,
                            onTap: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.1, end: 0, duration: 300.ms);
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final int? count;
  final VoidCallback onTap;
  final Color? color;

  const _ActionButton({
    required this.icon,
    this.count,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final displayColor = color ?? Colors.grey[600];
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: displayColor),
          if (count != null && count! > 0) ...[
            const SizedBox(width: 4),
            Text('$count', style: TextStyle(color: displayColor, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}
