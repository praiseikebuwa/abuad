import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../chat/data/chat_repository.dart';
import '../../domain/audio_room.dart';
import '../controllers/audio_room_controller.dart';

class LiveSpaceShareSheet extends ConsumerStatefulWidget {
  final AudioRoom room;

  const LiveSpaceShareSheet({super.key, required this.room});

  @override
  ConsumerState<LiveSpaceShareSheet> createState() => _LiveSpaceShareSheetState();
}

class _LiveSpaceShareSheetState extends ConsumerState<LiveSpaceShareSheet> {
  bool _isCopied = false;
  final Set<String> _sharedChannelIds = {};
  String _searchQuery = '';

  String get _shareUrl => 'https://abuadapp.com.ng/spaces/${widget.room.id}';

  String get _shareText =>
      '🎙️ Join "${widget.room.title}" on ABUAD Life Live Audio Spaces!\n'
      'Category: ${widget.room.category}\n'
      'Tune in live: $_shareUrl';

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: _shareUrl));
    HapticFeedback.lightImpact();
    setState(() => _isCopied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isCopied = false);
    });
  }

  void _systemShare() {
    HapticFeedback.mediumImpact();
    Share.share(
      _shareText,
      subject: '🎙️ Live Audio Space: ${widget.room.title}',
    );
  }

  Future<void> _shareToChannel(String channelId) async {
    HapticFeedback.selectionClick();
    setState(() => _sharedChannelIds.add(channelId));
    try {
      await ref.read(activeAudioRoomNotifierProvider.notifier).shareSpaceToChannels(
        channelIds: [channelId],
        message: '🎙️ Join "${widget.room.title}" on Live Audio Spaces! Tap to tune in live.',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Space shared to chat channel!'),
            backgroundColor: Color(0xFF7C4DFF),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sharedChannelIds.remove(channelId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(chatChannelsProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF161622),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.share_rounded, color: Color(0xFF7C4DFF), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Share Live Space',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.room.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white60),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white10),

          // Quick actions (Copy Link & System Share)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _copyLink,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _isCopied
                            ? Colors.green.withValues(alpha: 0.2)
                            : const Color(0xFF222232),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isCopied
                              ? Colors.greenAccent
                              : Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isCopied ? Icons.check_circle_rounded : Icons.link_rounded,
                            color: _isCopied ? Colors.greenAccent : Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isCopied ? 'Link Copied!' : 'Copy Link',
                            style: TextStyle(
                              color: _isCopied ? Colors.greenAccent : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _systemShare,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7C4DFF), Color(0xFF448AFF)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.ios_share_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Share via...',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: TextField(
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search campus groups or channels...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
                filled: true,
                fillColor: const Color(0xFF1E1E2C),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase().trim()),
            ),
          ),

          // Section Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Row(
              children: [
                const Icon(Icons.forum_outlined, size: 16, color: Color(0xFF7C4DFF)),
                const SizedBox(width: 6),
                Text(
                  'SHARE TO CAMPUS CHATS & GROUPS',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),

          // Channels / Groups list
          Expanded(
            child: channelsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Failed to load chats: $e', style: const TextStyle(color: Colors.white54)),
              ),
              data: (channels) {
                final filtered = channels.where((c) {
                  final name = (c.displayName ?? '').toLowerCase();
                  if (_searchQuery.isNotEmpty && !name.contains(_searchQuery)) {
                    return false;
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white24, size: 40),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isEmpty ? 'No campus groups found' : 'No matching chats',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final channel = filtered[index];
                    final isShared = _sharedChannelIds.contains(channel.id);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E2C),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: channel.isGroup
                                  ? const Color(0xFF38BDF8).withValues(alpha: 0.15)
                                  : const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              channel.isGroup ? Icons.groups_rounded : Icons.person_rounded,
                              color: channel.isGroup ? const Color(0xFF38BDF8) : const Color(0xFF7C4DFF),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  channel.displayName ?? (channel.isGroup ? 'Campus Group' : 'Direct Chat'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  channel.isGroup
                                      ? '${channel.memberIds.length} members · Group'
                                      : 'Direct Message',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isShared
                                  ? Colors.green.withValues(alpha: 0.2)
                                  : const Color(0xFF7C4DFF),
                              foregroundColor: isShared ? Colors.greenAccent : Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            icon: Icon(
                              isShared ? Icons.check_rounded : Icons.send_rounded,
                              size: 14,
                            ),
                            label: Text(
                              isShared ? 'Sent' : 'Send',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            onPressed: isShared ? null : () => _shareToChannel(channel.id),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
