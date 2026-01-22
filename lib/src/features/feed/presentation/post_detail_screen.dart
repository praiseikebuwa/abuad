import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../data/post_repository.dart';
import '../domain/post.dart' as domain;

class PostDetailScreen extends ConsumerStatefulWidget {
  final domain.Post post;

  const PostDetailScreen({super.key, required this.post});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentController = TextEditingController();
  bool _isPosting = false;

  @override
  void dispose() {
    _commentController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(postRepositoryProvider);
    final commentsStream = repo.watchComments(widget.post.id);
    final currentUserId = repo.currentUserId;

    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: Column(
        children: [
          // Original Post (Twitter Style)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (User Info)
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: widget.post.authorAvatarUrl != null
                          ? NetworkImage(widget.post.authorAvatarUrl!)
                          : null,
                      child: widget.post.authorAvatarUrl == null
                          ? Text(
                              widget.post.authorName.isNotEmpty
                                  ? widget.post.authorName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                widget.post.authorName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              if (widget.post.isVerified) ...[
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
                            widget.post.authorHandle,
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
                      onPressed: () {}, // Todo: Report/Block menu
                      color: Colors.grey,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Content
                Text(
                  widget.post.content,
                  style: const TextStyle(fontSize: 18, height: 1.3),
                ),

                // Media Placeholder (if any)
                ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    widget.post.mediaUrl!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(),
                  ),
                ),
              ],

                const SizedBox(height: 16),

                // Timestamp
                Text(
                  // Formatting like "10:21 AM · Jan 21, 2025" logic would go here
                  // Using simplistic one for now
                  "${widget.post.timestamp.hour}:${widget.post.timestamp.minute.toString().padLeft(2, '0')} · ${widget.post.timestamp.day}/${widget.post.timestamp.month}/${widget.post.timestamp.year}",
                  style: TextStyle(color: Colors.grey[600], fontSize: 15),
                ),

                const SizedBox(height: 16),
                Divider(height: 1, color: Colors.grey[200]),

                // Stats Row
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Row(
                    children: [
                      _StatLabel(count: widget.post.likesCount, label: "Likes"),
                      const SizedBox(width: 16),
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: commentsStream,
                        builder: (context, snapshot) {
                          final count =
                              snapshot.data?.length ??
                              widget.post.commentsCount;
                          return _StatLabel(count: count, label: "Replies");
                        },
                      ),
                    ],
                  ),
                ),

                Divider(height: 1, color: Colors.grey[200]),

                // Action Buttons Row (Twitter Style)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline),
                        onPressed: () {
                          // Focus comment field
                          // Implementation detail
                        },
                        color: Colors.grey[600],
                      ),
                      IconButton(
                        icon: const Icon(Icons.repeat),
                        onPressed: () {},
                        color: Colors.grey[600],
                      ),
                      IconButton(
                        icon: const Icon(Icons.favorite_border),
                        onPressed: () {
                          repo.toggleLike(widget.post.id);
                        },
                        color: Colors.grey[600],
                      ),
                      IconButton(
                        icon: const Icon(Icons.share_outlined),
                        onPressed: () {},
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

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
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No comments yet',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Be the first to comment!',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: comments.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.grey[200],
                    indent: 72,
                  ),
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    final timestamp = DateTime.fromMillisecondsSinceEpoch(
                      comment['timestamp'] ?? 0,
                    );
                    final isOwnComment = comment['userId'] == currentUserId;

                    return Container(
                      color: isOwnComment
                          ? Colors.blue.withOpacity(0.03)
                          : null,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.1),
                            child: Text(
                              (comment['userName'] ?? 'U')[0].toUpperCase(),
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      comment['userName'] ?? 'Student',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      timeago.format(timestamp),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  comment['content'] ?? '',
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                          if (isOwnComment)
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              iconSize: 20,
                              color: Colors.grey[600],
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _deleteComment(comment['id']),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Comment Input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      enabled: !_isPosting,
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _isPosting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          onPressed: _postComment,
                          icon: const Icon(Icons.send),
                          color: Theme.of(context).primaryColor,
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatLabel extends StatelessWidget {
  final int count;
  final String label;

  const _StatLabel({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 15),
        ),
      ],
    );
  }
}
