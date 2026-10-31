import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/audio_room_controller.dart';
import '../live_audio_room_screen.dart';

class FloatingAudioSpaceBar extends ConsumerWidget {
  const FloatingAudioSpaceBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spaceState = ref.watch(activeAudioRoomNotifierProvider);
    final room = spaceState.room;

    if (room == null || !spaceState.isConnected) {
      return const SizedBox.shrink();
    }

    final isSpeaker = spaceState.isSpeaker;
    final isMuted = spaceState.isMuted;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Material(
          elevation: 12,
          borderRadius: BorderRadius.circular(28),
          color: const Color(0xFF1E1E2C),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LiveAudioRoomScreen(roomId: room.id),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: const Color(0xFF7C4DFF).withOpacity(0.5),
                  width: 1.5,
                ),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF1A1A2E),
                    Color(0xFF16213E),
                  ],
                ),
              ),
              child: Row(
                children: [
                  // Animated Pulsing Red Live Badge
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF416C).withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.graphic_eq_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Space Title & Category
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C4DFF).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                room.category,
                                style: const TextStyle(
                                  color: Color(0xFFB388FF),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${room.totalParticipants} listening',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Mute / Speak Control
                  if (isSpeaker)
                    IconButton(
                      icon: Icon(
                        isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        color: isMuted ? Colors.redAccent : const Color(0xFF00E676),
                      ),
                      onPressed: () {
                        ref.read(activeAudioRoomNotifierProvider.notifier).toggleMicrophone();
                      },
                    ),
                  // Leave button
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                      size: 20,
                    ),
                    onPressed: () {
                      ref.read(activeAudioRoomNotifierProvider.notifier).leaveRoom();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

