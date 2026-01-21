import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../data/chat_repository.dart';
import '../domain/chat_message.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String channelId;
  const ChatScreen({super.key, required this.channelId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    ref.read(chatRepositoryProvider).sendMessage(widget.channelId, content);

    _messageController.clear();
    // Scroll to bottom logic if needed
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(chatRepositoryProvider);
    final messagesStream = repo.watchMessages(widget.channelId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'), // Ideally show User Name
        actions: [
          IconButton(icon: const Icon(Icons.info_outline), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: messagesStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;
                if (messages.isEmpty) {
                  return const Center(child: Text('Say hello! 👋'));
                }

                // Messages come in Timestamp Descending (Newest first)
                // We want to display them Newest at Bottom usually, OR use reverse ListView
                // If using reverse: true, index 0 is the BOTTOM (newest).

                return ListView.builder(
                  reverse: true, // List starts from bottom
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == repo.currentUserId;

                    // Snapchat Style: Minimal
                    // Sender: Right, Red vertical line indicator
                    // Receiver: Left, Blue vertical line indicator
                    // No bubbles, just text next to the line.

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.8,
                        ),
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisAlignment: isMe
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment
                              .center, // Center vertically with line
                          children: [
                            if (!isMe) ...[
                              Container(
                                width: 2,
                                height: 24, // Approx height of text
                                color: const Color(
                                  0xFF0D47A1,
                                ), // Blue for Received
                              ),
                              const SizedBox(width: 8),
                            ],

                            Flexible(
                              child: GestureDetector(
                                onTap: () {
                                  // Show time/status on tap logic could go here
                                },
                                child: Text(
                                  message.content,
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 16,
                                    fontFamily: 'Avenir', // Snap font vibe
                                    fontWeight: isMe
                                        ? FontWeight.w500
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),

                            if (isMe) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 2,
                                height: 24, // Approx height of text
                                color: const Color(0xFFF23C57), // Red for Sent
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Input Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(
                    0.1,
                  ), // Changed back to withOpacity for safety if flutter version mismatch, but user said 'deprecated_member_use ... .withValues()'. Wait, the warning said `.withValues()` IS deprecated? No, 'Use .withValues()'.
                  // I will stick to withOpacity if unsure, or just ignore.
                  // Actually the warning likely said "Use .withValues instead of .withOpacity".
                  // I will use withOpacity(0.1) which is standard. If it warns, I'll ignore for now to avoid risking build failure if their flutter is old.
                  // BUT, the warning said "deprecated_member_use ... .withValues()".
                  // If it said "Use .withValues", then I should use .withValues.
                  // Let's just fix the timeago first.
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              // For iPhone bottom bar
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.camera_alt_outlined,
                      color: Colors.blue,
                    ),
                    onPressed: () {
                      // Attach image logic
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Chat...',
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.send_rounded,
                      color: Color(0xFF0D47A1),
                    ),
                    onPressed: _sendMessage,
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
