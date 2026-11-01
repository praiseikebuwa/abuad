import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'controllers/audio_room_controller.dart';
import '../domain/audio_room.dart';
import 'widgets/in_room_chat_sheet.dart';
import 'widgets/moderation_sheet.dart';
import 'widgets/live_space_share_sheet.dart';
import 'widgets/live_space_closing_sheet.dart';

class LiveAudioRoomScreen extends ConsumerStatefulWidget {
  final String roomId;
  const LiveAudioRoomScreen({super.key, required this.roomId});

  @override
  ConsumerState<LiveAudioRoomScreen> createState() => _LiveAudioRoomScreenState();
}

class _LiveAudioRoomScreenState extends ConsumerState<LiveAudioRoomScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(liveKitAudioServiceProvider).startAudio();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _shareSpace(AudioRoom room) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LiveSpaceShareSheet(room: room),
    );
  }

  void _promptClosing(AudioRoom room, bool isHost) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LiveSpaceClosingSheet(room: room, isHost: isHost),
    );
  }

  void _openChat() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InRoomChatSheet(roomId: widget.roomId),
    );
  }

  void _openModeration() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ModerationSheet(roomId: widget.roomId),
    );
  }

  void _showTransferProposalDialog(AudioRoomHostTransferProposal proposal) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.workspace_premium_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('Host Transfer Request', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          '${proposal.previousHostName} has requested to transfer primary Host ownership of "${proposal.roomTitle}" to you.\n\nDo you accept becoming the room Host?',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            child: const Text('Decline', style: TextStyle(color: Colors.white60)),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(activeAudioRoomNotifierProvider.notifier).respondToHostTransfer(false);
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C4DFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Accept Ownership'),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(activeAudioRoomNotifierProvider.notifier).respondToHostTransfer(true);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activeAudioRoomNotifierProvider);
    final room = state.room;

    ref.listen<ActiveAudioRoomState>(activeAudioRoomNotifierProvider, (previous, next) {
      if (next.pendingTransferProposal != null &&
          previous?.pendingTransferProposal?.transferId != next.pendingTransferProposal?.transferId) {
        _showTransferProposalDialog(next.pendingTransferProposal!);
      }
    });

    if (state.isConnecting && room == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF7C4DFF)),
              const SizedBox(height: 16),
              Text(
                'Connecting to Live Audio Space...',
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
            ],
          ),
        ),
      );
    }

    if (room == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.podcasts_outlined, size: 60, color: Colors.white24),
              const SizedBox(height: 16),
              const Text('Space ended or unavailable', style: TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to Campus'),
              ),
            ],
          ),
        ),
      );
    }

    final isSpeaker = state.isSpeaker;
    final isHost = state.isHost;
    final isCoHost = state.isCoHost;
    final isMuted = state.isMuted;
    final isHandRaised = state.isHandRaised;

    final speakers = room.speakers;
    final listeners = room.listeners;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => ref.read(liveKitAudioServiceProvider).startAudio(),
        child: Stack(
          children: [
            // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF1E1035),
                  Color(0xFF0F0F1A),
                  Color(0xFF080811),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Main Layout
          SafeArea(
            child: Column(
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      // Minimize button
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 30),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 4),
                      // Live Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFEF4444)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.fiber_manual_record, color: Color(0xFFEF4444), size: 10),
                            SizedBox(width: 4),
                            Text(
                              'LIVE',
                              style: TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Listener Count
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.headphones_rounded, color: Colors.white70, size: 13),
                            const SizedBox(width: 4),
                            Text(
                              '${room.totalParticipants}',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Moderation Button (for Host/Co-host)
                      if (isHost || isCoHost)
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFFB388FF)),
                              onPressed: _openModeration,
                            ),
                            if (state.pendingRequests.isNotEmpty)
                              Positioned(
                                right: 6,
                                top: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${state.pendingRequests.length}',
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      // Share Button
                      IconButton(
                        icon: const Icon(Icons.share_rounded, color: Colors.white70),
                        onPressed: () => _shareSpace(room),
                      ),
                    ],
                  ),
                ),

                // Space Info Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C4DFF).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              room.category,
                              style: const TextStyle(color: Color(0xFFB388FF), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (room.isLocked) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lock_rounded, color: Colors.redAccent, size: 10),
                                  SizedBox(width: 4),
                                  Text('LOCKED', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                          if (room.isRecording) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.fiber_manual_record, color: Colors.redAccent, size: 8),
                                  SizedBox(width: 4),
                                  Text('REC', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (state.isHostDisconnected) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.timer_outlined, color: Colors.amber, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Host disconnected. 60-second reconnection grace period active.',
                                  style: TextStyle(color: Colors.amber.shade200, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        room.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (room.description != null && room.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          room.description!,
                          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),

                const Divider(color: Colors.white10, height: 16),

                // Stage Area (Speakers & Listeners)
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Speakers section header
                        const Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 12),
                          child: Text(
                            'SPEAKERS & STAGE',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),

                        // Speakers Grid
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.8,
                          ),
                          itemCount: speakers.length,
                          itemBuilder: (context, index) {
                            final speaker = speakers[index];
                            final isSpeaking = state.activeSpeakerIds.contains(speaker.userId);
                            return _SpeakerAvatarTile(
                              participant: speaker,
                              isSpeaking: isSpeaking,
                              pulseAnimation: _pulseController,
                              onTap: () {
                                if (isHost || isCoHost) {
                                  _openModeration();
                                }
                              },
                            );
                          },
                        ),

                        const SizedBox(height: 24),

                        // Listeners section header
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 12),
                          child: Text(
                            'LISTENERS (${listeners.length})',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),

                        // Listeners Grid
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 14,
                            childAspectRatio: 0.75,
                          ),
                          itemCount: listeners.length,
                          itemBuilder: (context, index) {
                            final listener = listeners[index];
                            return _ListenerAvatarTile(
                              participant: listener,
                              onTap: () {
                                if (isHost || isCoHost) {
                                  _openModeration();
                                }
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 90),
                      ],
                    ),
                  ),
                ),

                // Live In-Room Floating Chat Preview (latest message)
                if (state.messages.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: _LiveChatFloatingPreview(
                      message: state.messages.last,
                      onTap: _openChat,
                    ),
                  ),

                // Bottom Action Bar
                _BottomSpaceActionBar(
                  isSpeaker: isSpeaker,
                  isHost: isHost,
                  isMuted: isMuted,
                  isHandRaised: isHandRaised,
                  messageCount: state.messages.length,
                  onToggleMic: () {
                    ref.read(activeAudioRoomNotifierProvider.notifier).toggleMicrophone();
                  },
                  onToggleHand: () {
                    ref.read(activeAudioRoomNotifierProvider.notifier).toggleHandRaise();
                  },
                  onSendReaction: (emoji) {
                    ref.read(activeAudioRoomNotifierProvider.notifier).sendReaction(emoji);
                  },
                  onOpenChat: _openChat,
                  onLeaveRoom: () => _promptClosing(room, isHost),
                  onEndRoom: () => _promptClosing(room, isHost),
                ),
              ],
            ),
          ),

          // Floating Reactions Overlay
          Positioned(
            right: 16,
            bottom: 120,
            child: IgnorePointer(
              child: SizedBox(
                width: 140,
                height: 280,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomRight,
                  children: state.floatingReactions.map((reaction) {
                    return Positioned(
                      key: ValueKey(reaction.id.isNotEmpty ? reaction.id : '${DateTime.now().microsecondsSinceEpoch}_${reaction.emoji}'),
                      bottom: 0,
                      right: 10 + (reaction.xOffset * 60),
                      child: _FloatingEmojiItem(emoji: reaction.emoji),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}

class _SpeakerAvatarTile extends StatelessWidget {
  final AudioParticipant participant;
  final bool isSpeaking;
  final AnimationController pulseAnimation;
  final VoidCallback onTap;

  const _SpeakerAvatarTile({
    required this.participant,
    required this.isSpeaking,
    required this.pulseAnimation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: pulseAnimation,
            builder: (context, child) {
              final scale = isSpeaking ? (1.0 + (pulseAnimation.value * 0.08)) : 1.0;
              return Transform.scale(
                scale: scale,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Speaking Pulse Ring
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSpeaking ? const Color(0xFF00E676) : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: isSpeaking
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF00E676).withOpacity(0.5),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    // Avatar Image
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: const Color(0xFF2A2A3E),
                      backgroundImage: participant.user.avatarUrl != null &&
                              participant.user.avatarUrl!.isNotEmpty
                          ? NetworkImage(participant.user.avatarUrl!)
                          : null,
                      child: participant.user.avatarUrl == null ||
                              participant.user.avatarUrl!.isEmpty
                          ? Text(
                              participant.user.fullName.isNotEmpty
                                  ? participant.user.fullName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    // Mute / Unmute Status Badge
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: participant.isMuted
                              ? const Color(0xFF2A2A3E)
                              : const Color(0xFF00E676),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF0F0F1A), width: 2),
                        ),
                        child: Icon(
                          participant.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                          color: participant.isMuted ? Colors.white60 : Colors.black,
                          size: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          // Name
          Text(
            participant.user.fullName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          // Role pill
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: participant.isHost
                  ? const Color(0xFF7C4DFF).withOpacity(0.3)
                  : participant.isCoHost
                      ? Colors.amber.withOpacity(0.3)
                      : Colors.white10,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              participant.isHost
                  ? 'Host'
                  : participant.isCoHost
                      ? 'Co-Host'
                      : 'Speaker',
              style: TextStyle(
                color: participant.isHost
                    ? const Color(0xFFB388FF)
                    : participant.isCoHost
                        ? Colors.amber
                        : Colors.white70,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListenerAvatarTile extends StatelessWidget {
  final AudioParticipant participant;
  final VoidCallback? onTap;

  const _ListenerAvatarTile({
    required this.participant,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFF222232),
                backgroundImage: participant.user.avatarUrl != null &&
                        participant.user.avatarUrl!.isNotEmpty
                    ? NetworkImage(participant.user.avatarUrl!)
                    : null,
                child: participant.user.avatarUrl == null ||
                        participant.user.avatarUrl!.isEmpty
                    ? Text(
                        participant.user.fullName.isNotEmpty
                            ? participant.user.fullName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      )
                    : null,
              ),
              if (participant.isHandRaised)
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    padding: const EdgeInsets.all(3.5),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.6),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.pan_tool_rounded,
                      color: Colors.black,
                      size: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            participant.user.fullName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveChatFloatingPreview extends StatelessWidget {
  final AudioRoomMessageItem message;
  final VoidCallback onTap;

  const _LiveChatFloatingPreview({
    required this.message,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF7C4DFF).withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: const Color(0xFF7C4DFF).withValues(alpha: 0.3),
              backgroundImage: message.user.avatarUrl != null && message.user.avatarUrl!.isNotEmpty
                  ? NetworkImage(message.user.avatarUrl!)
                  : null,
              child: message.user.avatarUrl == null || message.user.avatarUrl!.isEmpty
                  ? Text(
                      message.user.fullName.isNotEmpty ? message.user.fullName[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              '${message.user.fullName}: ',
              style: const TextStyle(
                color: Color(0xFFB388FF),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            Flexible(
              child: Text(
                message.message,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 10),
          ],
        ),
      ),
    );
  }
}

class _BottomSpaceActionBar extends StatelessWidget {
  final bool isSpeaker;
  final bool isHost;
  final bool isMuted;
  final bool isHandRaised;
  final int messageCount;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleHand;
  final ValueChanged<String> onSendReaction;
  final VoidCallback onOpenChat;
  final VoidCallback onLeaveRoom;
  final VoidCallback onEndRoom;

  const _BottomSpaceActionBar({
    required this.isSpeaker,
    required this.isHost,
    required this.isMuted,
    required this.isHandRaised,
    required this.messageCount,
    required this.onToggleMic,
    required this.onToggleHand,
    required this.onSendReaction,
    required this.onOpenChat,
    required this.onLeaveRoom,
    required this.onEndRoom,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF161622),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Emoji Reactions Quick Bar
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _ReactionPill(emoji: '❤️', onTap: () => onSendReaction('❤️')),
                _ReactionPill(emoji: '👏', onTap: () => onSendReaction('👏')),
                _ReactionPill(emoji: '🔥', onTap: () => onSendReaction('🔥')),
                _ReactionPill(emoji: '💡', onTap: () => onSendReaction('💡')),
                _ReactionPill(emoji: '🎓', onTap: () => onSendReaction('🎓')),
                _ReactionPill(emoji: '😂', onTap: () => onSendReaction('😂')),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Main Action Controls
          Row(
            children: [
              // Mic Toggle (Speaker) or Raise Hand (Listener)
              if (isSpeaker) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isMuted ? const Color(0xFF2A2A3C) : const Color(0xFF00E676),
                    foregroundColor: isMuted ? Colors.white : Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  icon: Icon(isMuted ? Icons.mic_off_rounded : Icons.mic_rounded),
                  label: Text(
                    isMuted ? 'Muted' : 'Mic On',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: onToggleMic,
                ),
              ] else ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isHandRaised ? Colors.amber : const Color(0xFF2A2A3C),
                    foregroundColor: isHandRaised ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  icon: Icon(isHandRaised ? Icons.pan_tool_rounded : Icons.pan_tool_outlined),
                  label: Text(
                    isHandRaised ? 'Hand Raised' : 'Request Mic',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  onPressed: onToggleHand,
                ),
              ],

              const Spacer(),

              // In-Room Chat Button with Message Badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
                    onPressed: onOpenChat,
                  ),
                  if (messageCount > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C4DFF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF0F0F1A), width: 1.5),
                        ),
                        child: Text(
                          messageCount > 99 ? '99+' : '$messageCount',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 8),

              // Leave / End Button
              if (isHost)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                    foregroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  onPressed: onEndRoom,
                  child: const Text('End Space', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                )
              else
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2A2A3C),
                    foregroundColor: Colors.white70,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  onPressed: onLeaveRoom,
                  child: const Text('Leave quietly', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReactionPill extends StatelessWidget {
  final String emoji;
  final VoidCallback onTap;
  const _ReactionPill({required this.emoji, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF252538),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12),
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}

class _FloatingEmojiItem extends StatefulWidget {
  final String emoji;
  const _FloatingEmojiItem({required this.emoji});

  @override
  State<_FloatingEmojiItem> createState() => _FloatingEmojiItemState();
}

class _FloatingEmojiItemState extends State<_FloatingEmojiItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _translateY;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..forward();

    _translateY = Tween<double>(begin: 0, end: -220).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 0.4, end: 1.25), weight: 20),
      TweenSequenceItem(tween: Tween<double>(begin: 1.25, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 60),
    ]).animate(_controller);

    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 55),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _translateY.value),
          child: Transform.scale(
            scale: _scale.value,
            child: Opacity(
              opacity: _opacity.value.clamp(0.0, 1.0),
              child: Text(widget.emoji, style: const TextStyle(fontSize: 34)),
            ),
          ),
        );
      },
    );
  }
}
