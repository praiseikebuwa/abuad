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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Chat',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 24,
            fontFamily: 'Avenir',
          ), // Snapchat font vibe
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.search, color: Colors.black87, size: 28),
          onPressed: () {},
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add, color: Colors.black87, size: 28),
            onPressed: () => context.push('/user-search'),
          ),
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

    return InkWell(
      onTap: () => context.push('/chat/${channel.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Bitmoji-style Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  otherUserId.isNotEmpty ? otherUserId[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Student $otherUserId',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Snapchat Status Indication
                      if (isUnread) ...[
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF23C57), // Snapchat Red
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'New Chat',
                          style: TextStyle(
                            color: Color(0xFFF23C57), // Snapchat Red
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '• ${timeago.format(lastMsgTime, locale: 'en_short')}',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13,
                          ),
                        ),
                      ] else ...[
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey[400]!,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Received • ${timeago.format(lastMsgTime, locale: 'en_short')}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Camera/Chat shortcut (Snapchat style)
            if (!isUnread)
              IconButton(
                icon: Icon(Icons.chat_bubble_outline, color: Colors.grey[400]),
                onPressed: () {}, // Quick reply?
              ),
          ],
        ),
      ),
    );
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
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text(
            "No chats yet",
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: onStartConversation,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
            ),
            child: const Text("Start a Chat"),
          ),
        ],
      ),
    );
  }
}
