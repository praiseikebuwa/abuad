import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/chat_repository.dart';
import 'group_info_screen.dart';
import 'direct_chat_info_screen.dart';

class ChatInfoScreen extends ConsumerWidget {
  final String channelId;

  const ChatInfoScreen({super.key, required this.channelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(chatRepositoryProvider);

    return FutureBuilder(
      future: repo.getChannel(channelId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Scaffold(
            backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF2F2F7),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final channel = snapshot.data;
        if (channel != null && channel.type == 'group') {
          return GroupInfoScreen(channelId: channelId);
        }

        return DirectChatInfoScreen(channelId: channelId);
      },
    );
  }
}
