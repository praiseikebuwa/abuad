import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../user/data/user_repository.dart';
import '../data/chat_repository.dart';
import '../../../core/theme/app_colors.dart';

class BroadcastMessageScreen extends ConsumerStatefulWidget {
  final List<AppUser> recipients;

  const BroadcastMessageScreen({
    super.key,
    required this.recipients,
  });

  @override
  ConsumerState<BroadcastMessageScreen> createState() => _BroadcastMessageScreenState();
}

class _BroadcastMessageScreenState extends ConsumerState<BroadcastMessageScreen> {
  final _messageController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendBroadcast() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final chatRepo = ref.read(chatRepositoryProvider);
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) throw Exception('Profile not found');

      int count = 0;
      for (final recipient in widget.recipients) {
        final channelId = await chatRepo.createOrGetChannel(
          recipient.uid,
          otherUserName: recipient.displayName,
          otherUserAvatar: recipient.avatarUrl,
          currentUserName: currentUser.displayName,
          currentUserAvatar: currentUser.avatarUrl,
        );

        await chatRepo.sendMessage(channelId, content);
        count++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Broadcast sent to $count recipients!'),
            backgroundColor: AppColors.secondaryTeal,
          ),
        );
        // Go back to chat list
        context.go('/chat');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compose Broadcast'),
        actions: [
          if (!_isSending)
            IconButton(
              onPressed: _sendBroadcast,
              icon: const Icon(Icons.send),
            ),
        ],
      ),
      body: Column(
        children: [
          // Recipients Summary
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).brightness == Brightness.dark 
                ? Colors.white10 
                : Colors.grey[100],
            child: Row(
              children: [
                const Icon(Icons.people, size: 20, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'To: ${widget.recipients.map((u) => u.displayName).join(", ")}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                Text(
                  '${widget.recipients.length} total',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          
          // Message Field
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _messageController,
                maxLines: null,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Type your broadcast message...',
                  border: InputBorder.none,
                ),
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),

          if (_isSending)
            const LinearProgressIndicator(backgroundColor: Colors.transparent),
        ],
      ),
    );
  }
}
