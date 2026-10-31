import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../../core/services/socket_service.dart';
import '../../data/audio_room_repository.dart';
import '../../data/livekit_audio_service.dart';
import '../../domain/audio_room.dart';
import '../../services/audio_live_activity_service.dart';

final audioRoomRepositoryProvider = Provider<AudioRoomRepository>((ref) {
  return const AudioRoomRepository();
});

final liveKitAudioServiceProvider = Provider<LiveKitAudioService>((ref) {
  final service = LiveKitAudioService();
  ref.onDispose(() => service.dispose());
  return service;
});

// Category filter for the Spaces Hub
final selectedCategoryProvider = StateProvider<String>((ref) => 'ALL');

// Discovery feed provider for live/upcoming spaces
final audioRoomsProvider = FutureProvider.autoDispose<List<AudioRoom>>((ref) async {
  final repo = ref.watch(audioRoomRepositoryProvider);
  final category = ref.watch(selectedCategoryProvider);
  return repo.getRooms(category: category);
});

// Reaction model for floating emojis
class AudioReactionEvent {
  final String id;
  final String userId;
  final String emoji;
  final DateTime timestamp;

  const AudioReactionEvent({
    required this.id,
    required this.userId,
    required this.emoji,
    required this.timestamp,
  });
}

// Active Space session state
class ActiveAudioRoomState {
  final AudioRoom? room;
  final String role; // HOST, CO_HOST, SPEAKER, LISTENER
  final bool isConnecting;
  final bool isConnected;
  final bool isMuted;
  final bool isHandRaised;
  final List<String> activeSpeakerIds;
  final List<AudioReactionEvent> floatingReactions;
  final List<AudioRoomMessageItem> messages;
  final List<AudioSpeakRequest> pendingRequests;
  final String? errorMessage;

  const ActiveAudioRoomState({
    this.room,
    this.role = 'LISTENER',
    this.isConnecting = false,
    this.isConnected = false,
    this.isMuted = true,
    this.isHandRaised = false,
    this.activeSpeakerIds = const [],
    this.floatingReactions = const [],
    this.messages = const [],
    this.pendingRequests = const [],
    this.errorMessage,
  });

  bool get isHost => role == 'HOST';
  bool get isCoHost => role == 'CO_HOST';
  bool get isSpeaker => role == 'SPEAKER' || isHost || isCoHost;
  bool get isListener => role == 'LISTENER';
  bool get hasActiveRoom => room != null;

  ActiveAudioRoomState copyWith({
    AudioRoom? room,
    String? role,
    bool? isConnecting,
    bool? isConnected,
    bool? isMuted,
    bool? isHandRaised,
    List<String>? activeSpeakerIds,
    List<AudioReactionEvent>? floatingReactions,
    List<AudioRoomMessageItem>? messages,
    List<AudioSpeakRequest>? pendingRequests,
    String? errorMessage,
    bool clearError = false,
    bool clearRoom = false,
  }) {
    return ActiveAudioRoomState(
      room: clearRoom ? null : (room ?? this.room),
      role: role ?? this.role,
      isConnecting: isConnecting ?? this.isConnecting,
      isConnected: isConnected ?? this.isConnected,
      isMuted: isMuted ?? this.isMuted,
      isHandRaised: isHandRaised ?? this.isHandRaised,
      activeSpeakerIds: activeSpeakerIds ?? this.activeSpeakerIds,
      floatingReactions: floatingReactions ?? this.floatingReactions,
      messages: messages ?? this.messages,
      pendingRequests: pendingRequests ?? this.pendingRequests,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// Global active audio room notifier
class ActiveAudioRoomNotifier extends StateNotifier<ActiveAudioRoomState> {
  final Ref _ref;
  final AudioRoomRepository _repository;
  final LiveKitAudioService _audioService;
  final SocketService _socketService = SocketService.instance;

  StreamSubscription? _socketReactionSub;
  StreamSubscription? _socketMessageSub;
  StreamSubscription? _socketHandRaisedSub;
  StreamSubscription? _socketHandLoweredSub;
  StreamSubscription? _socketPartJoinedSub;
  StreamSubscription? _socketPartLeftSub;
  StreamSubscription? _socketPartUpdatedSub;
  StreamSubscription? _socketEndedSub;
  StreamSubscription? _socketRolePromotedSub;
  StreamSubscription? _socketRoleDemotedSub;
  StreamSubscription? _socketForceMutedSub;
  StreamSubscription? _socketKickedSub;

  StreamSubscription? _speakersSub;
  StreamSubscription? _micSub;

  ActiveAudioRoomNotifier(this._ref)
      : _repository = _ref.read(audioRoomRepositoryProvider),
        _audioService = _ref.read(liveKitAudioServiceProvider),
        super(const ActiveAudioRoomState());

  void _setupSubscriptions() {
    _cancelSubscriptions();

    _socketReactionSub = _socketService.onAudioRoomReaction.listen((data) {
      final emoji = data['emoji'] as String?;
      final userId = data['userId'] as String?;
      if (emoji != null && userId != null) {
        final reaction = AudioReactionEvent(
          id: '${DateTime.now().millisecondsSinceEpoch}_$userId',
          userId: userId,
          emoji: emoji,
          timestamp: DateTime.now(),
        );
        state = state.copyWith(
          floatingReactions: [...state.floatingReactions, reaction],
        );
        // Auto remove reaction after 3.5 seconds
        Timer(const Duration(milliseconds: 3500), () {
          state = state.copyWith(
            floatingReactions: state.floatingReactions
                .where((r) => r.id != reaction.id)
                .toList(),
          );
        });
      }
    });

    _socketMessageSub = _socketService.onAudioRoomMessage.listen((data) {
      final rawMsg = data['message'];
      if (rawMsg is Map<String, dynamic>) {
        final message = AudioRoomMessageItem.fromJson(rawMsg);
        state = state.copyWith(
          messages: [...state.messages, message],
        );
      }
    });

    _socketHandRaisedSub = _socketService.onAudioRoomHandRaised.listen((data) {
      final rawReq = data['request'];
      if (rawReq is Map<String, dynamic>) {
        final req = AudioSpeakRequest.fromJson(rawReq);
        final existing = state.pendingRequests.indexWhere((r) => r.userId == req.userId);
        if (existing >= 0) {
          final updated = List<AudioSpeakRequest>.from(state.pendingRequests);
          updated[existing] = req;
          state = state.copyWith(pendingRequests: updated);
        } else {
          state = state.copyWith(pendingRequests: [...state.pendingRequests, req]);
        }
      }
    });

    _socketHandLoweredSub = _socketService.onAudioRoomHandLowered.listen((data) {
      final userId = data['userId'] as String?;
      if (userId != null) {
        state = state.copyWith(
          pendingRequests: state.pendingRequests.where((r) => r.userId != userId).toList(),
          isHandRaised: userId == _ref.read(activeAudioRoomNotifierProvider).room?.hostId ? false : state.isHandRaised,
        );
      }
    });

    _socketPartJoinedSub = _socketService.onAudioRoomParticipantJoined.listen((data) {
      final rawPart = data['participant'];
      if (rawPart is Map<String, dynamic> && state.room != null) {
        final participant = AudioParticipant.fromJson(rawPart);
        final currentParticipants = List<AudioParticipant>.from(state.room!.participants);
        final idx = currentParticipants.indexWhere((p) => p.userId == participant.userId);
        if (idx >= 0) {
          currentParticipants[idx] = participant;
        } else {
          currentParticipants.add(participant);
        }
        state = state.copyWith(
          room: AudioRoom(
            id: state.room!.id,
            hostId: state.room!.hostId,
            title: state.room!.title,
            description: state.room!.description,
            category: state.room!.category,
            visibility: state.room!.visibility,
            speakersPermission: state.room!.speakersPermission,
            status: state.room!.status,
            isRecording: state.room!.isRecording,
            isChatEnabled: state.room!.isChatEnabled,
            scheduledAt: state.room!.scheduledAt,
            startedAt: state.room!.startedAt,
            endedAt: state.room!.endedAt,
            createdAt: state.room!.createdAt,
            host: state.room!.host,
            participants: currentParticipants,
            requests: state.pendingRequests,
            totalParticipants: currentParticipants.length,
          ),
        );
      }
    });

    _socketPartLeftSub = _socketService.onAudioRoomParticipantLeft.listen((data) {
      final userId = data['userId'] as String?;
      if (userId != null && state.room != null) {
        final currentParticipants = state.room!.participants.where((p) => p.userId != userId).toList();
        state = state.copyWith(
          room: AudioRoom(
            id: state.room!.id,
            hostId: state.room!.hostId,
            title: state.room!.title,
            description: state.room!.description,
            category: state.room!.category,
            visibility: state.room!.visibility,
            speakersPermission: state.room!.speakersPermission,
            status: state.room!.status,
            isRecording: state.room!.isRecording,
            isChatEnabled: state.room!.isChatEnabled,
            scheduledAt: state.room!.scheduledAt,
            startedAt: state.room!.startedAt,
            endedAt: state.room!.endedAt,
            createdAt: state.room!.createdAt,
            host: state.room!.host,
            participants: currentParticipants,
            requests: state.pendingRequests,
            totalParticipants: currentParticipants.length,
          ),
        );
      }
    });

    _socketPartUpdatedSub = _socketService.onAudioRoomParticipantUpdated.listen((data) {
      final rawPart = data['participant'];
      if (rawPart is Map<String, dynamic> && state.room != null) {
        final participant = AudioParticipant.fromJson(rawPart);
        final current = List<AudioParticipant>.from(state.room!.participants);
        final idx = current.indexWhere((p) => p.userId == participant.userId);
        if (idx >= 0) {
          current[idx] = participant;
        } else {
          current.add(participant);
        }
        state = state.copyWith(
          room: AudioRoom(
            id: state.room!.id,
            hostId: state.room!.hostId,
            title: state.room!.title,
            description: state.room!.description,
            category: state.room!.category,
            visibility: state.room!.visibility,
            speakersPermission: state.room!.speakersPermission,
            status: state.room!.status,
            isRecording: state.room!.isRecording,
            isChatEnabled: state.room!.isChatEnabled,
            scheduledAt: state.room!.scheduledAt,
            startedAt: state.room!.startedAt,
            endedAt: state.room!.endedAt,
            createdAt: state.room!.createdAt,
            host: state.room!.host,
            participants: current,
            requests: state.pendingRequests,
            totalParticipants: current.length,
          ),
        );
      }
    });

    _socketEndedSub = _socketService.onAudioRoomEnded.listen((_) {
      leaveRoom();
    });

    _socketRolePromotedSub = _socketService.onAudioRoomRolePromoted.listen((data) async {
      final newRole = data['role'] as String? ?? 'SPEAKER';
      final token = data['token'] as String?;
      if (token != null && state.room != null) {
        state = state.copyWith(role: newRole, isHandRaised: false);
        await _audioService.connect(
          url: 'wss://abuad-cgeux9e8.livekit.cloud',
          token: token,
          canPublish: true,
        );
      }
    });

    _socketRoleDemotedSub = _socketService.onAudioRoomRoleDemoted.listen((data) async {
      final token = data['token'] as String?;
      if (token != null && state.room != null) {
        state = state.copyWith(role: 'LISTENER', isMuted: true);
        await _audioService.connect(
          url: 'wss://abuad-cgeux9e8.livekit.cloud',
          token: token,
          canPublish: false,
        );
      }
    });

    _socketForceMutedSub = _socketService.onAudioRoomForceMuted.listen((_) async {
      await _audioService.setMicrophoneEnabled(false);
      state = state.copyWith(isMuted: true);
    });

    _socketKickedSub = _socketService.onAudioRoomKicked.listen((_) {
      leaveRoom();
    });

    _speakersSub = _audioService.activeSpeakersStream.listen((speakerIds) {
      state = state.copyWith(activeSpeakerIds: speakerIds);
    });

    _micSub = _audioService.micStateStream.listen((isMicOn) {
      state = state.copyWith(isMuted: !isMicOn);
      if (state.room != null) {
        try {
          _ref.read(audioLiveActivityServiceProvider).updateSpaceActivity(
            roomId: state.room!.id,
            participantCount: state.room!.totalParticipants,
            isMuted: !isMicOn,
          );
        } catch (_) {}
      }
    });
  }

  void _cancelSubscriptions() {
    _socketReactionSub?.cancel();
    _socketMessageSub?.cancel();
    _socketHandRaisedSub?.cancel();
    _socketHandLoweredSub?.cancel();
    _socketPartJoinedSub?.cancel();
    _socketPartLeftSub?.cancel();
    _socketPartUpdatedSub?.cancel();
    _socketEndedSub?.cancel();
    _socketRolePromotedSub?.cancel();
    _socketRoleDemotedSub?.cancel();
    _socketForceMutedSub?.cancel();
    _socketKickedSub?.cancel();
    _speakersSub?.cancel();
    _micSub?.cancel();
  }

  Future<void> joinRoom(String roomId) async {
    try {
      state = state.copyWith(isConnecting: true, clearError: true);

      // Fetch room details
      final room = await _repository.getRoomDetails(roomId);

      // Join room & get token
      final joinResult = await _repository.joinRoom(roomId);
      final token = joinResult['token'] as String;
      final role = joinResult['role'] as String;

      _setupSubscriptions();
      _socketService.joinAudioRoom(roomId);

      // Connect to LiveKit Cloud WebRTC session
      const livekitUrl = 'wss://abuad-cgeux9e8.livekit.cloud';
      final canPublish = role == 'HOST' || role == 'CO_HOST' || role == 'SPEAKER';

      await _audioService.connect(
        url: livekitUrl,
        token: token,
        canPublish: canPublish,
      );

      // Load initial chat messages
      final messages = await _repository.getMessages(roomId);

      state = state.copyWith(
        room: room,
        role: role,
        isConnecting: false,
        isConnected: true,
        isMuted: true,
        messages: messages,
        pendingRequests: room.requests,
      );

      // Launch Live Activity on Join
      try {
        _ref.read(audioLiveActivityServiceProvider).startSpaceActivity(
          roomId: room.id,
          title: room.title,
          hostName: room.host.fullName,
          category: room.category,
          participantCount: room.totalParticipants,
          isHost: role == 'HOST',
          isMuted: true,
        );
      } catch (_) {}
    } catch (e) {
      debugPrint('❌ [AudioRoomNotifier] Join error: $e');
      state = state.copyWith(
        isConnecting: false,
        isConnected: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<AudioRoom> startRoom({
    required String title,
    String? description,
    String category = 'ACADEMIC',
    String visibility = 'PUBLIC',
    String speakersPermission = 'HOST_APPROVED',
    bool isRecording = false,
    bool isChatEnabled = true,
    DateTime? scheduledAt,
    List<String> taggedGroupIds = const [],
    List<String> taggedUserIds = const [],
    List<String> tags = const [],
  }) async {
    try {
      state = state.copyWith(isConnecting: true, clearError: true);

      final result = await _repository.createRoom(
        title: title,
        description: description,
        category: category,
        visibility: visibility,
        speakersPermission: speakersPermission,
        isRecording: isRecording,
        isChatEnabled: isChatEnabled,
        scheduledAt: scheduledAt,
        taggedGroupIds: taggedGroupIds,
        taggedUserIds: taggedUserIds,
        tags: tags,
      );

      final room = result['room'] as AudioRoom;
      final token = result['token'] as String?;

      if (token != null) {
        _setupSubscriptions();
        _socketService.joinAudioRoom(room.id);

        const livekitUrl = 'wss://abuad-cgeux9e8.livekit.cloud';
        await _audioService.connect(
          url: livekitUrl,
          token: token,
          canPublish: true,
          autoEnableMic: true,
        );

        state = state.copyWith(
          room: room,
          role: 'HOST',
          isConnecting: false,
          isConnected: true,
          isMuted: false,
          messages: [],
          pendingRequests: [],
        );

        // Start Live Activity for the host
        try {
          _ref.read(audioLiveActivityServiceProvider).startSpaceActivity(
            roomId: room.id,
            title: room.title,
            hostName: room.host.fullName,
            category: room.category,
            participantCount: 1,
            isHost: true,
            isMuted: false,
          );
        } catch (_) {}
      } else {
        // Scheduled room created
        state = state.copyWith(isConnecting: false, isConnected: false);
      }
      return room;
    } catch (e) {
      debugPrint('❌ [AudioRoomNotifier] Start room error: $e');
      state = state.copyWith(
        isConnecting: false,
        isConnected: false,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> toggleMicrophone() async {
    if (!state.isSpeaker) return;
    try {
      await _audioService.toggleMicrophone();
      state = state.copyWith(isMuted: !_audioService.isMicEnabled);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to toggle mic: $e');
    }
  }

  Future<void> toggleHandRaise() async {
    if (state.room == null) return;
    try {
      if (state.isHandRaised) {
        await _repository.lowerHand(state.room!.id);
        state = state.copyWith(isHandRaised: false);
      } else {
        await _repository.raiseHand(state.room!.id);
        state = state.copyWith(isHandRaised: true);
      }
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to update hand raise: $e');
    }
  }

  void sendReaction(String emoji) {
    if (state.room == null) return;
    _socketService.sendAudioRoomReaction(state.room!.id, emoji);
  }

  Future<void> sendChatMessage(String text) async {
    if (state.room == null || text.trim().isEmpty) return;
    await _repository.sendMessage(state.room!.id, text);
  }

  Future<void> moderate({
    required String targetUserId,
    required String action,
  }) async {
    if (state.room == null) return;
    await _repository.moderate(
      state.room!.id,
      targetUserId: targetUserId,
      action: action,
    );
  }

  Future<void> endRoom() async {
    if (state.room == null) return;
    final roomId = state.room!.id;
    try {
      _ref.read(audioLiveActivityServiceProvider).endSpaceActivity(roomId);
      await _repository.endRoom(roomId);
    } catch (_) {}
    await leaveRoom();
  }

  Future<void> leaveRoom() async {
    final roomId = state.room?.id;
    if (roomId != null) {
      _ref.read(audioLiveActivityServiceProvider).endSpaceActivity(roomId);
      _socketService.leaveAudioRoom(roomId);
      await _repository.leaveRoom(roomId);
    }
    _cancelSubscriptions();
    await _audioService.disconnect();
    state = const ActiveAudioRoomState();
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }
}

final activeAudioRoomNotifierProvider =
    StateNotifierProvider<ActiveAudioRoomNotifier, ActiveAudioRoomState>((ref) {
  return ActiveAudioRoomNotifier(ref);
});
