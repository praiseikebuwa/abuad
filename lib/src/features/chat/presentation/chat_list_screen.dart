import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../data/chat_repository.dart';
import '../domain/chat_channel.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(chatRepositoryProvider);
    final channelsStream = repo.watchChannels();

    return Scaffold(
      backgroundColor: Colors.white, // Snapchat is clean white
      appBar: AppBar(
        title: const Text(
          'Chat',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent, // No tint
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined), // "Add Friend" style
            onPressed: () => context.push('/user-search'),
          ),
          IconButton(icon: const Icon(Icons.more_horiz), onPressed: () {}),
        ],
      ),
      body: StreamBuilder<List<ChatChannel>>(
        stream: channelsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final channels = snapshot.data ?? [];

          if (channels.isEmpty) {
            return _EmptyState(
              onStartConversation: () => context.push('/user-search'),
            );
          }

          return ListView.builder(
            // No separators in Snapchat style
            itemCount: channels.length,
            itemBuilder: (context, index) {
              final channel = channels[index];
              return _SnapchatListItem(
                channel: channel,
                currentUserId: repo.currentUserId,
              );
            },
          );
        },
      ),
    );
  }
}

class _SnapchatListItem extends StatelessWidget {
  final ChatChannel channel;
  final String? currentUserId;

  const _SnapchatListItem({required this.channel, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final otherUserId = channel.memberIds.firstWhere(
      (id) => id != currentUserId,
      orElse: () => 'Unknown',
    );

    final unreadCount = channel.unreadCounts[currentUserId] ?? 0;
    final isUnread = unreadCount > 0;
    final lastMsgTime = channel.lastMessageTime;

    // Snapchat Logic:
    // Icon: Filled box (New) vs Hollow box (Opened)
    // Subtitle: "New Message" (Bold Color) vs "Received • 2m" (Grey)

    return InkWell(
      onTap: () => context.push('/chat/${channel.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ), // Tighter padding
        child: Row(
          children: [
            // Avatar
            GestureDetector(
              onTap: () => context.push('/user/$otherUserId'),
              child: CircleAvatar(
                radius: 24, // Slightly smaller
                backgroundColor: Colors.grey[200],
                child: Text(
                  otherUserId.isNotEmpty ? otherUserId[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: Colors.blueGrey[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Student $otherUserId', // TODO: Fetch real name
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600, // Semi-bold
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      // Status Icon (Small square)
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: isUnread ? Colors.blue : Colors.transparent,
                          borderRadius: BorderRadius.circular(2), // Soft square
                          border: Border.all(
                            color: isUnread ? Colors.blue : Colors.grey[400]!,
                            width: 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Status Text
                      Expanded(
                        child: Text(
                          isUnread
                              ? 'New Message'
                              : 'Received · ${_formatTime(lastMsgTime)}',
                          style: TextStyle(
                            color: isUnread ? Colors.blue : Colors.grey[500],
                            fontWeight: isUnread
                                ? FontWeight.bold
                                : FontWeight.w400,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Timestamp (Snapchat sometimes hides this if read, but we'll show it for clarity or hide if redundant)
                      // If read, we showed time in status. If unread, show time on right?
                      if (isUnread)
                        Text(
                          _formatTime(lastMsgTime, short: true),
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Optional: Emoji/Divider/Snapstreak (Future)
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime, {bool short = false}) {
    // Uses timeago for "2m" style or specialized formatting
    if (short) {
      return timeago.format(dateTime, locale: 'en_short');
    }
    return timeago.format(dateTime);
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onStartConversation;
  const _EmptyState({required this.onStartConversation});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(
            opacity: 0.5,
            child: Image.asset(
              'assets/ghost_placeholder.png', // Fallback or Icon
              height: 100,
              errorBuilder: (c, e, s) => const Icon(
                Icons.people_outline,
                size: 80,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "No chats yet",
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextButton(
            onPressed: onStartConversation,
            child: const Text("Tap to start chatting"),
          ),
        ],
      ),
    );
  }
}
