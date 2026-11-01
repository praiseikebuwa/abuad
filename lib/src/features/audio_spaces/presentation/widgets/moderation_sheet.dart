import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/audio_room.dart';
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
    final isHost = state.isHost;
    final isLocked = room?.isLocked ?? false;

    if (room == null) {
      return const SizedBox.shrink();
    }

    return DefaultTabController(
      length: 2,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.78,
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
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF7C4DFF), size: 20),
                  ),
                  const SizedBox(width: 10),
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

            // Quick Host Controls Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  // Mute All Speakers
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.mic_off_rounded, size: 16, color: Colors.amberAccent),
                      label: const Text('Mute All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        ref.read(activeAudioRoomNotifierProvider.notifier).muteAllSpeakers();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('All speakers have been muted'),
                            backgroundColor: Color(0xFF222232),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Lock/Unlock Room
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isLocked ? Colors.redAccent : Colors.white70,
                        side: BorderSide(
                          color: isLocked ? Colors.redAccent : Colors.white.withValues(alpha: 0.15),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: Icon(
                        isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                        size: 16,
                        color: isLocked ? Colors.redAccent : const Color(0xFF38BDF8),
                      ),
                      label: Text(
                        isLocked ? 'Unlock Space' : 'Lock Space',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        ref.read(activeAudioRoomNotifierProvider.notifier).toggleRoomLock();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isLocked ? 'Space unlocked' : 'Space locked to new listeners'),
                            backgroundColor: const Color(0xFF222232),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

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
                              Icon(Icons.pan_tool_outlined, size: 40, color: Colors.white.withValues(alpha: 0.2)),
                              const SizedBox(height: 8),
                              Text(
                                'No speaking requests right now',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
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
                                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, color: Colors.redAccent),
                                    onPressed: () {
                                      ref.read(activeAudioRoomNotifierProvider.notifier).moderate(
                                            targetUserId: req.userId,
                                            action: 'REJECT_SPEAKER',
                                          );
                                    },
                                  ),
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
                                    child: const Text('Allow Mic',
                                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
                      final isSelf = p.userId == room.hostId;

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
                                      const SizedBox(width: 6),
                                      _RoleBadge(role: p.role),
                                    ],
                                  ),
                                  Text(
                                    '@${p.user.username}',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            if (!isSelf)
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
                                color: const Color(0xFF2A2A3C),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                onSelected: (action) {
                                  if (action == 'TRANSFER_HOST') {
                                    _confirmTransferHost(context, ref, p);
                                  } else {
                                    ref.read(activeAudioRoomNotifierProvider.notifier).moderate(
                                          targetUserId: p.userId,
                                          action: action,
                                        );
                                  }
                                },
                                itemBuilder: (context) => [
                                  if (!p.isSpeaker)
                                    const PopupMenuItem(
                                      value: 'APPROVE_SPEAKER',
                                      child: Row(
                                        children: [
                                          Icon(Icons.mic_rounded, size: 18, color: Color(0xFF00E676)),
                                          SizedBox(width: 8),
                                          Text('Invite to Speak'),
                                        ],
                                      ),
                                    ),
                                  if (p.isSpeaker && !p.isHost)
                                    const PopupMenuItem(
                                      value: 'MUTE',
                                      child: Row(
                                        children: [
                                          Icon(Icons.mic_off_rounded, size: 18, color: Colors.amber),
                                          SizedBox(width: 8),
                                          Text('Mute Microphone'),
                                        ],
                                      ),
                                    ),
                                  if (p.isSpeaker && !p.isHost)
                                    const PopupMenuItem(
                                      value: 'DEMOTE_TO_LISTENER',
                                      child: Row(
                                        children: [
                                          Icon(Icons.arrow_downward_rounded, size: 18, color: Colors.orangeAccent),
                                          SizedBox(width: 8),
                                          Text('Move to Listener'),
                                        ],
                                      ),
                                    ),
                                  if (isHost && !p.isCoHost)
                                    const PopupMenuItem(
                                      value: 'MAKE_CO_HOST',
                                      child: Row(
                                        children: [
                                          Icon(Icons.star_rounded, size: 18, color: Colors.amber),
                                          SizedBox(width: 8),
                                          Text('Make Co-Host'),
                                        ],
                                      ),
                                    ),
                                  if (isHost && p.isCoHost)
                                    const PopupMenuItem(
                                      value: 'REVOKE_CO_HOST',
                                      child: Row(
                                        children: [
                                          Icon(Icons.star_border_rounded, size: 18, color: Colors.white70),
                                          SizedBox(width: 8),
                                          Text('Revoke Co-Host'),
                                        ],
                                      ),
                                    ),
                                  if (!p.isModerator && !p.isCoHost)
                                    const PopupMenuItem(
                                      value: 'MAKE_MODERATOR',
                                      child: Row(
                                        children: [
                                          Icon(Icons.shield_outlined, size: 18, color: Color(0xFF38BDF8)),
                                          SizedBox(width: 8),
                                          Text('Make Moderator'),
                                        ],
                                      ),
                                    ),
                                  if (isHost)
                                    const PopupMenuItem(
                                      value: 'TRANSFER_HOST',
                                      child: Row(
                                        children: [
                                          Icon(Icons.swap_horiz_rounded, size: 18, color: Color(0xFF7C4DFF)),
                                          SizedBox(width: 8),
                                          Text('Transfer Primary Host'),
                                        ],
                                      ),
                                    ),
                                  const PopupMenuDivider(),
                                  const PopupMenuItem(
                                    value: 'KICK',
                                    child: Row(
                                      children: [
                                        Icon(Icons.remove_circle_outline_rounded, size: 18, color: Colors.redAccent),
                                        SizedBox(width: 8),
                                        Text('Remove from Space', style: TextStyle(color: Colors.redAccent)),
                                      ],
                                    ),
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
          ],
        ),
      ),
    );
  }

  void _confirmTransferHost(BuildContext context, WidgetRef ref, AudioParticipant p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Transfer Host Ownership?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to transfer primary host ownership to ${p.user.fullName}? They will have full control over the Live Space.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C4DFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Transfer Ownership'),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(activeAudioRoomNotifierProvider.notifier).proposeHostTransfer(p.userId);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Host transfer proposal sent to ${p.user.fullName}'),
                  backgroundColor: const Color(0xFF7C4DFF),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (role) {
      case 'HOST':
        bg = const Color(0xFF7C4DFF);
        fg = Colors.white;
        label = 'Host';
        break;
      case 'CO_HOST':
        bg = Colors.amber;
        fg = Colors.black;
        label = 'Co-Host';
        break;
      case 'MODERATOR':
        bg = const Color(0xFF38BDF8);
        fg = Colors.black;
        label = 'Mod';
        break;
      case 'SPEAKER':
        bg = const Color(0xFF00E676).withValues(alpha: 0.2);
        fg = const Color(0xFF00E676);
        label = 'Speaker';
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
