import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../controllers/audio_room_controller.dart';
import '../../domain/audio_room.dart';

class InRoomChatSheet extends ConsumerStatefulWidget {
  final String roomId;
  const InRoomChatSheet({super.key, required this.roomId});

  @override
  ConsumerState<InRoomChatSheet> createState() => _InRoomChatSheetState();
}

class _InRoomChatSheetState extends ConsumerState<InRoomChatSheet> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  final List<String> _quickEmojis = ['❤️', '🔥', '👏', '😂', '💡', '🎓', '🎉', '💯'];

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;
    _textController.clear();
    setState(() => _isSending = true);
    HapticFeedback.lightImpact();

    try {
      await ref.read(activeAudioRoomNotifierProvider.notifier).sendChatMessage(text);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _appendEmoji(String emoji) {
    HapticFeedback.selectionClick();
    _textController.text += emoji;
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: _textController.text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activeAudioRoomNotifierProvider);
    final room = state.room;
    final messages = state.messages;

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF141420),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFFB388FF), size: 18),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Live Space Chat',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${messages.length} messages',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),

          // Pinned Message / Space Rules Header Banner
          if (room != null && room.description != null && room.description!.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF7C4DFF).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF7C4DFF).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.push_pin_rounded, color: Color(0xFFB388FF), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      room.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

          // Messages list
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.chat_bubble_outline_rounded, size: 36, color: Colors.white30),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No messages yet',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Be the first to share your thoughts or questions!',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      // Find participant role if available
                      final participant = room?.participants.firstWhere(
                        (p) => p.userId == msg.userId,
                        orElse: () => AudioParticipant(
                          id: '',
                          roomId: widget.roomId,
                          userId: msg.userId,
                          role: room?.hostId == msg.userId ? 'HOST' : 'LISTENER',
                          joinedAt: DateTime.now(),
                          user: msg.user,
                        ),
                      );

                      return _ChatMessageTile(
                        message: msg,
                        participantRole: participant.role,
                      );
                    },
                  ),
          ),

          // Quick Emoji Selector Bar
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: const Color(0xFF1A1A28),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _quickEmojis.length,
              itemBuilder: (context, idx) {
                final emoji = _quickEmojis[idx];
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      _appendEmoji(emoji);
                      ref.read(activeAudioRoomNotifierProvider.notifier).sendReaction(emoji);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      alignment: Alignment.center,
                      child: Text(emoji, style: const TextStyle(fontSize: 18)),
                    ),
                  ),
                );
              },
            ),
          ),

          // Message input bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A28),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Share a question or thought...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFF242436),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF7C4DFF),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessageTile extends StatelessWidget {
  final AudioRoomMessageItem message;
  final String participantRole;

  const _ChatMessageTile({
    required this.message,
    required this.participantRole,
  });

  @override
  Widget build(BuildContext context) {
    Color roleColor;
    String roleLabel;

    switch (participantRole) {
      case 'HOST':
        roleColor = const Color(0xFFB388FF);
        roleLabel = 'Host';
        break;
      case 'CO_HOST':
        roleColor = Colors.amber;
        roleLabel = 'Co-Host';
        break;
      case 'MODERATOR':
        roleColor = Colors.cyanAccent;
        roleLabel = 'Moderator';
        break;
      case 'SPEAKER':
        roleColor = const Color(0xFF00E676);
        roleLabel = 'Speaker';
        break;
      default:
        roleColor = Colors.white38;
        roleLabel = 'Listener';
    }

    final timeStr = DateFormat.jm().format(message.createdAt.toLocal());

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: roleColor.withValues(alpha: 0.2),
            backgroundImage: message.user.avatarUrl != null && message.user.avatarUrl!.isNotEmpty
                ? NetworkImage(message.user.avatarUrl!)
                : null,
            child: message.user.avatarUrl == null || message.user.avatarUrl!.isEmpty
                ? Text(
                    message.user.fullName.isNotEmpty ? message.user.fullName[0].toUpperCase() : '?',
                    style: TextStyle(color: roleColor, fontSize: 13, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      message.user.fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        roleLabel,
                        style: TextStyle(color: roleColor, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      timeStr,
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF222234),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    message.message,
                    style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
