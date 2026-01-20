import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../data/post_repository.dart';
import '../domain/post.dart' as domain;

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _contentController = TextEditingController();
  bool _isPosting = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submitPost() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    setState(() {
      _isPosting = true;
    });

    final repo = ref.read(postRepositoryProvider);

    // Create new post
    // Create new post
    final newPost = domain.Post(
      id: const Uuid().v4(),
      authorId: 'dummy_user_id', // Would come from Auth
      authorName: 'You',
      authorHandle: '@you',
      content: content,
      timestamp: DateTime.now(),
      isVerified: true,
    );

    await repo.addPost(newPost);

    if (mounted) {
      setState(() {
        _isPosting = false;
      });
      context.pop(); // Go back to feed
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Post'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: FilledButton(
              onPressed: _isPosting || _contentController.text.isEmpty
                  ? null
                  : _submitPost,
              child: _isPosting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Post'),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  child: Text('Y'), // Placeholder for user avatar
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _contentController,
                    decoration: const InputDecoration(
                      hintText: "What's happening on campus?",
                      border: InputBorder.none,
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (val) => setState(() {}),
                  ),
                ),
              ],
            ),
            if (_isPosting) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
