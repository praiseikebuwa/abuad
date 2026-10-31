import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/audio_room_controller.dart';

class ModerationSheet extends ConsumerWidget {
  final String roomId;
  const ModerationSheet({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activeAudioRoomNotifierProvider);
    final room = state.room;
    final requests = state.pendingRequests;
    final participants = room?.participants ?? [];

    if (room == null) {
      return const SizedBox.shrink();
    }

    return DefaultTabController(
      length: 2,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.70,
        decoration: const BoxDecoration(
          color: Color(0xFF161622),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF7C4DFF)),
                  const SizedBox(width: 8),
                  const Text(
                    'Host & Moderation Tools',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Tabs
            TabBar(
              indicatorColor: const Color(0xFF7C4DFF),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Requests'),
                      if (requests.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${requests.length}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Tab(text: 'Members (${participants.length})'),
              ],
            ),
            const Divider(color: Colors.white12, height: 1),

            // Tab Views
            Expanded(
              child: TabBarView(
                children: [
                  // Tab 1: Requests to Speak
                  requests.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.pan_tool_outlined, size: 40, color: Colors.white.withOpacity(0.2)),
                              const SizedBox(height: 8),
                              Text(
                                'No speaking requests right now',
                                style: TextStyle(color: Colors.white.withOpacity(0.5)),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: requests.length,
                          itemBuilder: (context, index) {
                            final req = requests[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF222232),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundImage: req.user.avatarUrl != null && req.user.avatarUrl!.isNotEmpty
                                        ? NetworkImage(req.user.avatarUrl!)
                                        : null,
                                    child: req.user.avatarUrl == null || req.user.avatarUrl!.isEmpty
                                        ? Text(req.user.fullName.isNotEmpty ? req.user.fullName[0] : '?')
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          req.user.fullName,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                        ),
                                        Text(
                                          '@${req.user.username}',
                                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Reject
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
                                    onPressed: () {
                                      ref.read(activeAudioRoomNotifierProvider.notifier).moderate(
                                            targetUserId: req.userId,
                                            action: 'REJECT_SPEAKER',
                                          );
                                    },
                                  ),
                                  // Approve
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00E676),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                    ),
                                    onPressed: () {
                                      ref.read(activeAudioRoomNotifierProvider.notifier).moderate(
                                            targetUserId: req.userId,
                                            action: 'APPROVE_SPEAKER',
                                          );
                                    },
                                    child: const Text('Allow Mic', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                  // Tab 2: Participants list
                  ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: participants.length,
                    itemBuilder: (context, index) {
                      final p = participants[index];
                      final isHost = p.isHost;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF222232),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundImage: p.user.avatarUrl != null && p.user.avatarUrl!.isNotEmpty
                                  ? NetworkImage(p.user.avatarUrl!)
                                  : null,
                              child: p.user.avatarUrl == null || p.user.avatarUrl!.isEmpty
                                  ? Text(p.user.fullName.isNotEmpty ? p.user.fullName[0] : '?')
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
                                        p.user.fullName,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                      ),
                                      if (p.isHost) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF7C4DFF),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text('Host', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ),
                                      ] else if (p.isCoHost) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.amber,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text('Co-Host', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    p.role,
                                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            if (!isHost)
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
                                color: const Color(0xFF2A2A3C),
                                onSelected: (action) {
                                  ref.read(activeAudioRoomNotifierProvider.notifier).moderate(
                                        targetUserId: p.userId,
                                        action: action,
                                      );
                                },
                                itemBuilder: (context) => [
                                  if (!p.isSpeaker)
                                    const PopupMenuItem(
                                      value: 'APPROVE_SPEAKER',
                                      child: Text('Promote to Speaker', style: TextStyle(color: Colors.white)),
                                    ),
                                  if (p.isSpeaker) ...[
                                    const PopupMenuItem(
                                      value: 'DEMOTE_TO_LISTENER',
                                      child: Text('Demote to Listener', style: TextStyle(color: Colors.white)),
                                    ),
                                    const PopupMenuItem(
                                      value: 'MUTE',
                                      child: Text('Mute Participant', style: TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                  if (!p.isCoHost)
                                    const PopupMenuItem(
                                      value: 'MAKE_CO_HOST',
                                      child: Text('Make Co-Host', style: TextStyle(color: Colors.white)),
                                    ),
                                  const PopupMenuItem(
                                    value: 'KICK',
                                    child: Text('Remove from Room', style: TextStyle(color: Colors.redAccent)),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // End Space Button
            if (state.isHost)
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.2),
                      foregroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: const BorderSide(color: Colors.redAccent, width: 1.5),
                      ),
                    ),
                    icon: const Icon(Icons.stop_circle_rounded),
                    label: const Text('End Space for Everyone', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.of(context).pop();
                      ref.read(activeAudioRoomNotifierProvider.notifier).endRoom();
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
