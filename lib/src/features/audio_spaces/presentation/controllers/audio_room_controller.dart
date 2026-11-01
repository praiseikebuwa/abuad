import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../../core/services/socket_service.dart';
import '../../../auth/data/auth_repository.dart';
import '../../domain/audio_room.dart';
import '../../data/audio_room_repository.dart';
import '../../data/livekit_audio_service.dart';
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

class AudioReactionEvent {
  final String id;
  final String emoji;
  final String userId;
  final double xOffset;

  AudioReactionEvent({
    required this.id,
    required this.emoji,
    required this.userId,
    this.xOffset = 0.5,
  });
}

class ActiveAudioRoomState {
  final AudioRoom? room;
  final String role; // HOST, CO_HOST, MODERATOR, SPEAKER, LISTENER
  final bool isConnecting;
  final bool isConnected;
  final bool isMuted;
  final bool isHandRaised;
  final List<String> activeSpeakerIds;
  final List<AudioReactionEvent> floatingReactions;
  final List<AudioRoomMessageItem> messages;
  final List<AudioSpeakRequest> pendingRequests;
  final AudioRoomHostTransferProposal? pendingTransferProposal;
  final DateTime? hostGracePeriodEndsAt;
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
    this.pendingTransferProposal,
    this.hostGracePeriodEndsAt,
    this.errorMessage,
  });

  bool get isHost => role == 'HOST';
  bool get isCoHost => role == 'CO_HOST';
  bool get isModerator => role == 'MODERATOR';
  bool get isSpeaker => role == 'SPEAKER' || isHost || isCoHost || isModerator;
  bool get isListener => role == 'LISTENER';
  bool get canModerate => isHost || isCoHost || isModerator;
  bool get hasActiveRoom => room != null;
  bool get isHostDisconnected =>
      hostGracePeriodEndsAt != null && DateTime.now().isBefore(hostGracePeriodEndsAt!);

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
    AudioRoomHostTransferProposal? pendingTransferProposal,
    DateTime? hostGracePeriodEndsAt,
    String? errorMessage,
    bool clearError = false,
    bool clearRoom = false,
    bool clearProposal = false,
    bool clearGracePeriod = false,
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
      pendingTransferProposal:
          clearProposal ? null : (pendingTransferProposal ?? this.pendingTransferProposal),
      hostGracePeriodEndsAt:
          clearGracePeriod ? null : (hostGracePeriodEndsAt ?? this.hostGracePeriodEndsAt),
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
  StreamSubscription? _socketTransferProposedSub;
  StreamSubscription? _socketTransferRejectedSub;
  StreamSubscription? _socketHostTransferredSub;
  StreamSubscription? _socketHostDisconnectedSub;
  StreamSubscription? _socketHostReconnectedSub;
  StreamSubscription? _socketAllMutedSub;
  StreamSubscription? _socketLockedChangedSub;

  StreamSubscription? _speakersSub;
  StreamSubscription? _micSub;

  Timer? _heartbeatTimer;

  ActiveAudioRoomNotifier(this._ref)
      : _repository = _ref.read(audioRoomRepositoryProvider),
        _audioService = _ref.read(liveKitAudioServiceProvider),
        super(const ActiveAudioRoomState());

  void _setupSubscriptions() {
    _cancelSubscriptions();

    _socketReactionSub = _socketService.onAudioRoomReaction.listen((data) {
      final emoji = data['emoji'] as String?;
      final userId = data['userId'] as String?;
      final currentUserId = _ref.read(authRepositoryProvider).currentUserId;
      // If the reaction was triggered by someone else, display it
      if (emoji != null && userId != null && userId != currentUserId) {
        final reaction = AudioReactionEvent(
          id: '${DateTime.now().millisecondsSinceEpoch}_$userId',
          emoji: emoji,
          userId: userId,
          xOffset: (data['xOffset'] as num?)?.toDouble() ??
              ((DateTime.now().millisecond % 80) / 100.0),
        );
        state = state.copyWith(
          floatingReactions: [...state.floatingReactions, reaction],
        );
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (!mounted) return;
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
        if (!state.messages.any((m) => m.id == message.id)) {
          state = state.copyWith(
            messages: [...state.messages, message],
          );
        }
      }
    });

    _socketHandRaisedSub = _socketService.onAudioRoomHandRaised.listen((data) {
      final rawReq = data['request'];
      if (rawReq is Map<String, dynamic>) {
        final req = AudioSpeakRequest.fromJson(rawReq);
        final existing = state.pendingRequests.indexWhere((r) => r.userId == req.userId);
        List<AudioSpeakRequest> updatedRequests;
        if (existing >= 0) {
          updatedRequests = List<AudioSpeakRequest>.from(state.pendingRequests);
          updatedRequests[existing] = req;
        } else {
          updatedRequests = [...state.pendingRequests, req];
        }

        // Update participant isHandRaised flag in state.room
        if (state.room != null) {
          final updatedParts = state.room!.participants.map((p) {
            if (p.userId == req.userId) {
              return p.copyWith(isHandRaised: true);
            }
            return p;
          }).toList();
          state = state.copyWith(
            pendingRequests: updatedRequests,
            room: state.room!.copyWith(participants: updatedParts),
          );
        } else {
          state = state.copyWith(pendingRequests: updatedRequests);
        }
      }
    });

    _socketHandLoweredSub = _socketService.onAudioRoomHandLowered.listen((data) {
      final userId = data['userId'] as String?;
      if (userId != null) {
        final currentUserId = _ref.read(authRepositoryProvider).currentUserId;
        final updatedRequests =
            state.pendingRequests.where((r) => r.userId != userId).toList();
        if (state.room != null) {
          final updatedParts = state.room!.participants.map((p) {
            if (p.userId == userId) {
              return p.copyWith(isHandRaised: false);
            }
            return p;
          }).toList();
          state = state.copyWith(
            pendingRequests: updatedRequests,
            room: state.room!.copyWith(participants: updatedParts),
            isHandRaised: userId == currentUserId ? false : state.isHandRaised,
          );
        } else {
          state = state.copyWith(
            pendingRequests: updatedRequests,
            isHandRaised: userId == currentUserId ? false : state.isHandRaised,
          );
        }
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
        _updateRoomParticipants(currentParticipants);
      }
    });

    _socketPartLeftSub = _socketService.onAudioRoomParticipantLeft.listen((data) {
      final userId = data['userId'] as String?;
      if (userId != null && state.room != null) {
        final currentParticipants =
            state.room!.participants.where((p) => p.userId != userId).toList();
        _updateRoomParticipants(currentParticipants);
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
        _updateRoomParticipants(current);
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
          autoEnableMic: newRole == 'HOST',
        );
      }
    });

    _socketRoleDemotedSub = _socketService.onAudioRoomRoleDemoted.listen((data) async {
      final newRole = data['role'] as String? ?? 'LISTENER';
      final token = data['token'] as String?;
      if (token != null && state.room != null) {
        state = state.copyWith(role: newRole, isMuted: true);
        await _audioService.connect(
          url: 'wss://abuad-cgeux9e8.livekit.cloud',
          token: token,
          canPublish: newRole == 'SPEAKER' || newRole == 'CO_HOST' || newRole == 'MODERATOR',
        );
      }
    });

    _socketForceMutedSub = _socketService.onAudioRoomForceMuted.listen((_) async {
      await _audioService.setMicrophoneEnabled(false);
      state = state.copyWith(isMuted: true);
    });

    _socketAllMutedSub = _socketService.onAudioRoomAllMuted.listen((_) async {
      if (!state.isHost) {
        await _audioService.setMicrophoneEnabled(false);
        state = state.copyWith(isMuted: true);
      }
    });

    _socketKickedSub = _socketService.onAudioRoomKicked.listen((_) {
      leaveRoom();
    });

    // Host Transfer Proposal received
    _socketTransferProposedSub =
        _socketService.onAudioRoomTransferProposed.listen((data) {
      final proposal = AudioRoomHostTransferProposal.fromJson(data);
      state = state.copyWith(pendingTransferProposal: proposal);
    });

    // Host Handover Completed
    _socketHostTransferredSub =
        _socketService.onAudioRoomHostTransferred.listen((data) {
      final newHostId = data['newHostId'] as String?;
      if (newHostId != null && state.room != null) {
        state = state.copyWith(
          room: AudioRoom(
            id: state.room!.id,
            hostId: newHostId,
            currentHostId: newHostId,
            title: state.room!.title,
            description: state.room!.description,
            category: state.room!.category,
            visibility: state.room!.visibility,
            speakersPermission: state.room!.speakersPermission,
            status: state.room!.status,
            isRecording: state.room!.isRecording,
            isChatEnabled: state.room!.isChatEnabled,
            isLocked: state.room!.isLocked,
            maxSpeakers: state.room!.maxSpeakers,
            scheduledAt: state.room!.scheduledAt,
            startedAt: state.room!.startedAt,
            endedAt: state.room!.endedAt,
            createdAt: state.room!.createdAt,
            host: state.room!.host,
            participants: state.room!.participants,
            requests: state.pendingRequests,
            totalParticipants: state.room!.totalParticipants,
          ),
          clearGracePeriod: true,
        );
      }
    });

    // Host Disconnected (Grace Period Active)
    _socketHostDisconnectedSub =
        _socketService.onAudioRoomHostDisconnected.listen((data) {
      final rawEnds = data['endsAt'] as String?;
      DateTime? endsAt;
      if (rawEnds != null) endsAt = DateTime.tryParse(rawEnds);
      endsAt ??= DateTime.now().add(const Duration(seconds: 60));
      state = state.copyWith(hostGracePeriodEndsAt: endsAt);
    });

    // Host Reconnected
    _socketHostReconnectedSub =
        _socketService.onAudioRoomHostReconnected.listen((_) {
      state = state.copyWith(clearGracePeriod: true);
    });

    // Room Lock Changed
    _socketLockedChangedSub =
        _socketService.onAudioRoomLockedChanged.listen((data) {
      final isLocked = data['isLocked'] as bool? ?? false;
      if (state.room != null) {
        state = state.copyWith(
          room: AudioRoom(
            id: state.room!.id,
            hostId: state.room!.hostId,
            currentHostId: state.room!.currentHostId,
            title: state.room!.title,
            description: state.room!.description,
            category: state.room!.category,
            visibility: state.room!.visibility,
            speakersPermission: state.room!.speakersPermission,
            status: state.room!.status,
            isRecording: state.room!.isRecording,
            isChatEnabled: state.room!.isChatEnabled,
            isLocked: isLocked,
            maxSpeakers: state.room!.maxSpeakers,
            scheduledAt: state.room!.scheduledAt,
            startedAt: state.room!.startedAt,
            endedAt: state.room!.endedAt,
            createdAt: state.room!.createdAt,
            host: state.room!.host,
            participants: state.room!.participants,
            requests: state.pendingRequests,
            totalParticipants: state.room!.totalParticipants,
          ),
        );
      }
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

  void _updateRoomParticipants(List<AudioParticipant> currentParticipants) {
    if (state.room == null) return;
    state = state.copyWith(
      room: state.room!.copyWith(
        participants: currentParticipants,
        totalParticipants: math.max(state.room!.totalParticipants, currentParticipants.length),
      ),
    );
  }

  void _startHeartbeat(String roomId) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      _repository.sendHeartbeat(roomId);
      _socketService.sendAudioHeartbeat(roomId);

      // Periodically refresh room details from backend to prevent state drift
      try {
        final freshRoom = await _repository.getRoomDetails(roomId);
        if (mounted && state.room != null && state.room!.id == roomId) {
          final selfId = _ref.read(authRepositoryProvider).currentUserId;
          final updatedParts = List<AudioParticipant>.from(freshRoom.participants);
          // Keep self participant if missing from fresh fetch
          if (selfId != null && !updatedParts.any((p) => p.userId == selfId)) {
            final existingSelf = state.room!.participants.firstWhere(
              (p) => p.userId == selfId,
              orElse: () => AudioParticipant(
                id: 'self_$selfId',
                roomId: roomId,
                userId: selfId,
                role: state.role,
                isMuted: state.isMuted,
                connectionStatus: 'ONLINE',
                joinedAt: DateTime.now(),
                user: state.room!.host.id == selfId
                    ? state.room!.host
                    : AudioRoomUser(id: selfId, username: 'Me', fullName: 'You'),
              ),
            );
            updatedParts.add(existingSelf);
          }

          state = state.copyWith(
            room: state.room!.copyWith(
              participants: updatedParts,
              totalParticipants: math.max(freshRoom.totalParticipants, updatedParts.length),
              isLocked: freshRoom.isLocked,
              status: freshRoom.status,
            ),
            pendingRequests: freshRoom.requests,
          );
        }
      } catch (_) {}
    });
  }

  void _cancelSubscriptions() {
    _heartbeatTimer?.cancel();
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
    _socketTransferProposedSub?.cancel();
    _socketTransferRejectedSub?.cancel();
    _socketHostTransferredSub?.cancel();
    _socketHostDisconnectedSub?.cancel();
    _socketHostReconnectedSub?.cancel();
    _socketAllMutedSub?.cancel();
    _socketLockedChangedSub?.cancel();
    _speakersSub?.cancel();
    _micSub?.cancel();
  }

  Future<void> joinRoom(String roomId) async {
    try {
      state = state.copyWith(isConnecting: true, clearError: true);

      // 1. Join room on backend to register participant in DB
      final joinResult = await _repository.joinRoom(roomId);
      final token = joinResult['token'] as String;
      final role = joinResult['role'] as String;

      // 2. Setup subscriptions and join socket room
      _setupSubscriptions();
      _socketService.joinAudioRoom(roomId);
      _startHeartbeat(roomId);

      // 3. Fetch fresh room details containing all participants
      final room = await _repository.getRoomDetails(roomId);

      // 4. Ensure current user is in participants list so they always see themselves
      final participants = List<AudioParticipant>.from(room.participants);
      final selfId = _ref.read(authRepositoryProvider).currentUserId;
      final rawPart = joinResult['participant'];
      if (rawPart is Map<String, dynamic>) {
        final selfPart = AudioParticipant.fromJson(rawPart);
        final idx = participants.indexWhere((p) => p.userId == selfPart.userId);
        if (idx >= 0) {
          participants[idx] = selfPart;
        } else {
          participants.add(selfPart);
        }
      } else if (selfId != null && !participants.any((p) => p.userId == selfId)) {
        participants.add(AudioParticipant(
          id: 'self_$selfId',
          roomId: roomId,
          userId: selfId,
          role: role,
          isMuted: role != 'HOST',
          connectionStatus: 'ONLINE',
          joinedAt: DateTime.now(),
          user: AudioRoomUser(id: selfId, username: 'Me', fullName: 'You'),
        ));
      }

      final updatedRoom = room.copyWith(
        participants: participants,
        totalParticipants: math.max(room.totalParticipants, participants.length),
      );

      const livekitUrl = 'wss://abuad-cgeux9e8.livekit.cloud';
      final canPublish = role == 'HOST' || role == 'CO_HOST' || role == 'MODERATOR' || role == 'SPEAKER';

      await _audioService.connect(
        url: livekitUrl,
        token: token,
        canPublish: canPublish,
        autoEnableMic: role == 'HOST',
      );

      final messages = await _repository.getMessages(roomId);

      state = state.copyWith(
        room: updatedRoom,
        role: role,
        isConnecting: false,
        isConnected: true,
        isMuted: role != 'HOST',
        messages: messages,
        pendingRequests: updatedRoom.requests,
      );

      try {
        _ref.read(audioLiveActivityServiceProvider).startSpaceActivity(
          roomId: room.id,
          title: room.title,
          hostName: room.host.fullName,
          category: room.category,
          participantCount: updatedRoom.totalParticipants,
          isHost: role == 'HOST',
          isMuted: role != 'HOST',
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
        _startHeartbeat(room.id);

        // Ensure host participant is present in participants list
        final participants = List<AudioParticipant>.from(room.participants);
        if (!participants.any((p) => p.userId == room.hostId)) {
          participants.add(AudioParticipant(
            id: 'host_${room.hostId}',
            roomId: room.id,
            userId: room.hostId,
            role: 'HOST',
            isMuted: false,
            connectionStatus: 'ONLINE',
            joinedAt: DateTime.now(),
            user: room.host,
          ));
        }

        final updatedRoom = room.copyWith(
          participants: participants,
          totalParticipants: math.max(1, participants.length),
        );

        const livekitUrl = 'wss://abuad-cgeux9e8.livekit.cloud';
        await _audioService.connect(
          url: livekitUrl,
          token: token,
          canPublish: true,
          autoEnableMic: true,
        );

        state = state.copyWith(
          room: updatedRoom,
          role: 'HOST',
          isConnecting: false,
          isConnected: true,
          isMuted: false,
          messages: [],
          pendingRequests: [],
        );

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
    final selfId = _ref.read(authRepositoryProvider).currentUserId;
    final nextState = !state.isHandRaised;

    // Optimistic UI update
    state = state.copyWith(isHandRaised: nextState);
    if (state.room != null && selfId != null) {
      final updatedParts = state.room!.participants.map((p) {
        if (p.userId == selfId) {
          return p.copyWith(isHandRaised: nextState);
        }
        return p;
      }).toList();
      state = state.copyWith(room: state.room!.copyWith(participants: updatedParts));
    }

    try {
      if (nextState) {
        await _repository.raiseHand(state.room!.id);
      } else {
        await _repository.lowerHand(state.room!.id);
      }
    } catch (e) {
      debugPrint('❌ [AudioRoomNotifier] Hand raise error: $e');
      // Revert if error
      state = state.copyWith(
        isHandRaised: !nextState,
        errorMessage: 'Failed to update hand raise: $e',
      );
    }
  }

  void sendReaction(String emoji) {
    if (state.room == null) return;
    final selfId = _ref.read(authRepositoryProvider).currentUserId ?? 'self';
    final reaction = AudioReactionEvent(
      id: '${DateTime.now().millisecondsSinceEpoch}_$selfId',
      emoji: emoji,
      userId: selfId,
      xOffset: ((DateTime.now().millisecond % 80) / 100.0),
    );

    // Optimistically show reaction immediately for local user
    state = state.copyWith(
      floatingReactions: [...state.floatingReactions, reaction],
    );
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      state = state.copyWith(
        floatingReactions: state.floatingReactions
            .where((r) => r.id != reaction.id)
            .toList(),
      );
    });

    // Broadcast to room via socket
    _socketService.sendAudioRoomReaction(state.room!.id, emoji);
  }

  Future<void> sendChatMessage(String text) async {
    if (state.room == null || text.trim().isEmpty) return;
    try {
      final sentMsg = await _repository.sendMessage(state.room!.id, text);
      if (!state.messages.any((m) => m.id == sentMsg.id)) {
        state = state.copyWith(messages: [...state.messages, sentMsg]);
      }
    } catch (e) {
      debugPrint('❌ [AudioRoomNotifier] Send message error: $e');
      rethrow;
    }
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

  Future<void> proposeHostTransfer(String targetUserId) async {
    if (state.room == null) return;
    await _repository.transferHost(state.room!.id, targetUserId);
  }

  Future<void> respondToHostTransfer(bool accept) async {
    final proposal = state.pendingTransferProposal;
    if (proposal == null || state.room == null) return;
    try {
      final res = await _repository.respondHostTransfer(
        state.room!.id,
        transferId: proposal.transferId,
        accept: accept,
      );
      if (accept && res['token'] != null) {
        state = state.copyWith(role: 'HOST', clearProposal: true, isMuted: false);
        await _audioService.connect(
          url: 'wss://abuad-cgeux9e8.livekit.cloud',
          token: res['token'] as String,
          canPublish: true,
          autoEnableMic: true,
        );
      } else {
        state = state.copyWith(clearProposal: true);
      }
    } catch (e) {
      state = state.copyWith(clearProposal: true, errorMessage: 'Failed to process host transfer: $e');
    }
  }

  Future<void> muteAllSpeakers() async {
    if (state.room == null || !state.canModerate) return;
    await _repository.muteAll(state.room!.id);
  }

  Future<void> toggleRoomLock() async {
    if (state.room == null || !state.canModerate) return;
    final currentLock = state.room!.isLocked;
    await _repository.toggleRoomLock(state.room!.id, !currentLock);
  }

  Future<String> shareSpaceToChannels({
    List<String> channelIds = const [],
    List<String> userIds = const [],
    String? message,
  }) async {
    if (state.room == null) return '';
    return await _repository.shareSpace(
      state.room!.id,
      channelIds: channelIds,
      userIds: userIds,
      message: message,
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
