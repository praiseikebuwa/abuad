import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../data/post_repository.dart';
import '../domain/post.dart' as domain;
import 'widgets/poll_widget.dart';
import 'widgets/animated_like_button.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  final domain.Post post;

  const PostDetailScreen({super.key, required this.post});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isPosting = false;

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isPosting = true);

    try {
      final repo = ref.read(postRepositoryProvider);
      await repo.addComment(widget.post.id, content);
      _commentController.clear();

      // Scroll to bottom to see new comment (optional, but nice)
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
      await repo.deleteComment(widget.post.id, commentId);

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

  void _showPostMenu(
    BuildContext context,
    domain.Post post,
    PostRepository repo,
  ) {
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

                  if (confirmed == true && mounted) {
                    try {
                      await repo.deletePost(post.id);
                      if (mounted) {
                        Navigator.pop(context); // Go back to feed
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Post deleted')),
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

  void _showRepostBottomSheet(domain.Post originalPost) {
    // Basic implementation for now, mirroring the one in PostCard if possible
    // For now we just show a SnackBar as a placeholder or copy the logic if we want to be thorough.
    // Ideally this logic should be shared.
    // Reuse the logic from PostCard but we need to implement it here or extract it.
    // For brevity, let's implement a simple version or just call the repo directly if we don't need the UI.
    // But the user asked for features. I'll duplicate the bottom sheet logic from PostCard for now to ensure it works fully.

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

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(postRepositoryProvider);
    final commentsStream = repo.watchComments(widget.post.id);
    final isLikedStream = repo.isPostLiked(widget.post.id);
    final currentUserId = repo.currentUserId;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Post'), centerTitle: true),
      body: StreamBuilder<domain.Post?>(
        stream: repo.watchPost(widget.post.id),
        builder: (context, snapshot) {
          final post = snapshot.data ?? widget.post;

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
                            // Header: Avatar, Names, More
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.grey[200],
                                  backgroundImage:
                                      (post.authorAvatarUrl != null)
                                      ? CachedNetworkImageProvider(
                                          post.authorAvatarUrl!,
                                        )
                                      : null,
                                  child: post.authorAvatarUrl == null
                                      ? Text(
                                          post.authorName.isNotEmpty
                                              ? post.authorName[0].toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            color: theme.primaryColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20,
                                          ),
                                        )
                                      : null,
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
                                            post.authorName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          if (post.isVerified) ...[
                                            const SizedBox(width: 4),
                                            const Icon(
                                              Icons.verified,
                                              size: 16,
                                              color: Colors.blue,
                                            ),
                                          ],
                                        ],
                                      ),
                                      Text(
                                        '@${post.authorHandle}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
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
                            ),

                            const SizedBox(height: 16),

                            // Post Text
                            Text(
                              post.content,
                              style: const TextStyle(fontSize: 18, height: 1.4),
                            ),

                            // Post Media
                            if (post.mediaUrl.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: CachedNetworkImage(
                                  imageUrl: post.mediaUrl,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    height: 300,
                                    color: Colors.grey[100],
                                    child: const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                                  errorWidget: (_, __, ___) => const SizedBox(),
                                ),
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
                                  ).format(post.timestamp),
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
                                post.likesCount > 0) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4.0,
                                ),
                                child: Row(
                                  children: [
                                    if (post.repostCount > 0) ...[
                                      _StatText(
                                        count: post.repostCount,
                                        label: 'Reposts',
                                      ),
                                      const SizedBox(width: 20),
                                    ],
                                    if (post.likesCount > 0)
                                      _StatText(
                                        count: post.likesCount,
                                        label: 'Likes',
                                      ),
                                  ],
                                ),
                              ),
                              const Divider(),
                            ],

                            // Action Bar
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chat_bubble_outline),
                                  onPressed: () {
                                    // Focus logic handled by placing focus node or just tapping the bottom field
                                    // For now, we can rely on the user tapping the bottom field
                                  },
                                  color: Colors.grey[600],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.repeat),
                                  onPressed: () => _showRepostBottomSheet(post),
                                  color: Colors.grey[600],
                                ),
                                StreamBuilder<bool>(
                                  stream: isLikedStream,
                                  builder: (context, snapshot) {
                                    final isLiked = snapshot.data ?? false;
                                    return AnimatedLikeButton(
                                      isLiked: isLiked,
                                      count:
                                          0, // We hide count in the button for this view
                                      showCount: false,
                                      iconSize: 24,
                                      onTap: () => repo.toggleLike(post.id),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.bookmark_border),
                                  onPressed: () {
                                    // Todo: Implement bookmark
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Bookmarked"),
                                      ),
                                    );
                                  },
                                  color: Colors.grey[600],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.share_outlined),
                                  onPressed: () {
                                    Share.share(
                                      '${post.authorName} (@${post.authorHandle}): ${post.content}\n\nSent from ABUAD Nest',
                                    );
                                  },
                                  color: Colors.grey[600],
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

                          final comments = snapshot.data ?? [];

                          if (comments.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Center(
                                child: Text(
                                  'No comments yet. Be the first to reply!',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            );
                          }

                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: comments.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final comment = comments[index];
                              final timestamp =
                                  DateTime.fromMillisecondsSinceEpoch(
                                    comment['timestamp'] ?? 0,
                                  );
                              final isOwnComment =
                                  comment['userId'] == currentUserId;

                              return InkWell(
                                onLongPress: isOwnComment
                                    ? () => _deleteComment(comment['id'])
                                    : null,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: theme.primaryColor
                                            .withOpacity(0.1),
                                        child: Text(
                                          (comment['userName'] ?? 'U')[0]
                                              .toUpperCase(),
                                          style: TextStyle(
                                            color: theme.primaryColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
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
                                                  comment['userName'] ??
                                                      'Student',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  timeago.format(
                                                    timestamp,
                                                    locale: 'en_short',
                                                  ),
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              comment['content'] ?? '',
                                              style: TextStyle(
                                                fontSize: 15,
                                                color: theme
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.color,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
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
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey[200]!)),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.grey[200],
                        // Ideally show current user avatar here
                        child: Icon(
                          Icons.person,
                          color: Colors.grey[400],
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: const InputDecoration(
                            hintText: 'Post your reply',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                      ),
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
                            : Icon(Icons.send, color: theme.primaryColor),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
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
