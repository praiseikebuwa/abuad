import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/chat_repository.dart';
import '../domain/chat_channel.dart';
import 'group_info_screen.dart';
import 'direct_chat_info_screen.dart';

class ChatInfoScreen extends ConsumerStatefulWidget {
  final String channelId;

  const ChatInfoScreen({super.key, required this.channelId});

  @override
  ConsumerState<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends ConsumerState<ChatInfoScreen> {
  Future<ChatChannel?>? _channelFuture;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(chatRepositoryProvider);
    if (repo.getCachedChannel(widget.channelId) == null) {
      _channelFuture = repo.getChannel(widget.channelId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(chatRepositoryProvider);
    final cached = repo.getCachedChannel(widget.channelId);

    // Instant Fast-Path 1: Channel already in memory cache
    if (cached != null) {
      if (cached.type == 'group' || cached.isGroup) {
        return GroupInfoScreen(channelId: widget.channelId);
      }
      return DirectChatInfoScreen(channelId: widget.channelId);
    }

    // Instant Fast-Path 2: Channel ID clearly indicates group
    final isExplicitGroup = widget.channelId.startsWith('group_') ||
        widget.channelId.contains('_group');
    if (isExplicitGroup) {
      return GroupInfoScreen(channelId: widget.channelId);
    }

    _channelFuture ??= repo.getChannel(widget.channelId);

    return FutureBuilder<ChatChannel?>(
      future: _channelFuture,
      initialData: cached,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Scaffold(
            backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF2F2F7),
            body: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
              ),
            ),
          );
        }

        final channel = snapshot.data;
        if (channel != null && (channel.type == 'group' || channel.isGroup)) {
          return GroupInfoScreen(channelId: widget.channelId);
        }

        return DirectChatInfoScreen(channelId: widget.channelId);
      },
    );
  }
}
