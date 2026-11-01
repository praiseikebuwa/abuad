import 'dart:convert';

class AudioRoomUser {
  final String id;
  final String username;
  final String fullName;
  final String? avatarUrl;
  final String? department;
  final String? level;
  final bool isVerified;
  final String verificationType;

  const AudioRoomUser({
    required this.id,
    required this.username,
    required this.fullName,
    this.avatarUrl,
    this.department,
    this.level,
    this.isVerified = false,
    this.verificationType = 'NONE',
  });

  factory AudioRoomUser.fromJson(Map<String, dynamic> json) {
    return AudioRoomUser(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      department: json['department'] as String?,
      level: json['level'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
      verificationType: json['verificationType'] as String? ?? 'NONE',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'fullName': fullName,
    'avatarUrl': avatarUrl,
    'department': department,
    'level': level,
    'isVerified': isVerified,
    'verificationType': verificationType,
  };
}

class AudioParticipant {
  final String id;
  final String roomId;
  final String userId;
  final String role; // HOST, CO_HOST, MODERATOR, SPEAKER, LISTENER
  final bool isMuted;
  final bool isHandRaised;
  final String connectionStatus; // ONLINE, DISCONNECTED
  final DateTime joinedAt;
  final AudioRoomUser user;
  final bool isSpeaking;

  const AudioParticipant({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.role,
    this.isMuted = true,
    this.isHandRaised = false,
    this.connectionStatus = 'ONLINE',
    required this.joinedAt,
    required this.user,
    this.isSpeaking = false,
  });

  bool get isHost => role == 'HOST';
  bool get isCoHost => role == 'CO_HOST';
  bool get isModerator => role == 'MODERATOR';
  bool get isSpeaker => role == 'SPEAKER' || isHost || isCoHost || isModerator;
  bool get isListener => role == 'LISTENER';
  bool get canModerate => isHost || isCoHost || isModerator;

  AudioParticipant copyWith({
    String? role,
    bool? isMuted,
    bool? isHandRaised,
    String? connectionStatus,
    bool? isSpeaking,
  }) {
    return AudioParticipant(
      id: id,
      roomId: roomId,
      userId: userId,
      role: role ?? this.role,
      isMuted: isMuted ?? this.isMuted,
      isHandRaised: isHandRaised ?? this.isHandRaised,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      joinedAt: joinedAt,
      user: user,
      isSpeaking: isSpeaking ?? this.isSpeaking,
    );
  }

  factory AudioParticipant.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    final userObj = rawUser is Map<String, dynamic>
        ? AudioRoomUser.fromJson(rawUser)
        : AudioRoomUser(
            id: json['userId'] as String? ?? '',
            username: 'User',
            fullName: 'Participant',
          );

    return AudioParticipant(
      id: json['id'] as String? ?? '',
      roomId: json['roomId'] as String? ?? '',
      userId: json['userId'] as String? ?? userObj.id,
      role: (json['role'] as String? ?? 'LISTENER').toUpperCase(),
      isMuted: json['isMuted'] as bool? ?? true,
      isHandRaised: json['isHandRaised'] as bool? ?? false,
      connectionStatus: json['connectionStatus'] as String? ?? 'ONLINE',
      joinedAt: json['joinedAt'] != null
          ? DateTime.tryParse(json['joinedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      user: userObj,
    );
  }
}

class AudioRoomHostTransferProposal {
  final String transferId;
  final String roomId;
  final String previousHostId;
  final String previousHostName;
  final String? previousHostAvatar;
  final String roomTitle;

  const AudioRoomHostTransferProposal({
    required this.transferId,
    required this.roomId,
    required this.previousHostId,
    required this.previousHostName,
    this.previousHostAvatar,
    required this.roomTitle,
  });

  factory AudioRoomHostTransferProposal.fromJson(Map<String, dynamic> json) {
    final rawPrev = json['previousHost'];
    String prevName = 'Host';
    String? prevAvatar;
    if (rawPrev is Map<String, dynamic>) {
      prevName = rawPrev['fullName'] as String? ?? rawPrev['username'] as String? ?? 'Host';
      prevAvatar = rawPrev['avatarUrl'] as String?;
    }
    return AudioRoomHostTransferProposal(
      transferId: json['transferId'] as String? ?? '',
      roomId: json['roomId'] as String? ?? '',
      previousHostId: json['previousHostId'] as String? ?? '',
      previousHostName: prevName,
      previousHostAvatar: prevAvatar,
      roomTitle: json['roomTitle'] as String? ?? 'Live Space',
    );
  }
}

class AudioSpeakRequest {
  final String id;
  final String roomId;
  final String userId;
  final String status; // PENDING, ACCEPTED, REJECTED
  final DateTime createdAt;
  final AudioRoomUser user;

  const AudioSpeakRequest({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.status,
    required this.createdAt,
    required this.user,
  });

  factory AudioSpeakRequest.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    final userObj = rawUser is Map<String, dynamic>
        ? AudioRoomUser.fromJson(rawUser)
        : AudioRoomUser(
            id: json['userId'] as String? ?? '',
            username: 'User',
            fullName: 'Participant',
          );

    return AudioSpeakRequest(
      id: json['id'] as String? ?? '',
      roomId: json['roomId'] as String? ?? '',
      userId: json['userId'] as String? ?? userObj.id,
      status: json['status'] as String? ?? 'PENDING',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      user: userObj,
    );
  }
}

class AudioRoomMessageItem {
  final String id;
  final String roomId;
  final String userId;
  final String message;
  final DateTime createdAt;
  final AudioRoomUser user;

  const AudioRoomMessageItem({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.message,
    required this.createdAt,
    required this.user,
  });

  factory AudioRoomMessageItem.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    final userObj = rawUser is Map<String, dynamic>
        ? AudioRoomUser.fromJson(rawUser)
        : AudioRoomUser(
            id: json['userId'] as String? ?? '',
            username: 'User',
            fullName: 'Participant',
          );

    return AudioRoomMessageItem(
      id: json['id'] as String? ?? '',
      roomId: json['roomId'] as String? ?? '',
      userId: json['userId'] as String? ?? userObj.id,
      message: json['message'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      user: userObj,
    );
  }
}

class AudioRoom {
  final String id;
  final String hostId;
  final String? currentHostId;
  final String title;
  final String? description;
  final String category; // ACADEMIC, SOCIAL, DEBATE, COMMUNITY
  final String visibility; // PUBLIC, FOLLOWERS, PRIVATE
  final String speakersPermission; // EVERYONE, HOST_APPROVED
  final String status; // SCHEDULED, LIVE, ENDED
  final bool isRecording;
  final bool isChatEnabled;
  final bool isLocked;
  final int maxSpeakers;
  final DateTime? hostGracePeriodEndsAt;
  final DateTime? scheduledAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime createdAt;
  final AudioRoomUser host;
  final List<AudioParticipant> participants;
  final List<AudioSpeakRequest> requests;
  final int totalParticipants;
  final List<String> taggedGroupIds;
  final List<String> taggedUserIds;
  final List<String> tags;

  const AudioRoom({
    required this.id,
    required this.hostId,
    this.currentHostId,
    required this.title,
    this.description,
    this.category = 'ACADEMIC',
    this.visibility = 'PUBLIC',
    this.speakersPermission = 'HOST_APPROVED',
    this.status = 'LIVE',
    this.isRecording = false,
    this.isChatEnabled = true,
    this.isLocked = false,
    this.maxSpeakers = 15,
    this.hostGracePeriodEndsAt,
    this.scheduledAt,
    this.startedAt,
    this.endedAt,
    required this.createdAt,
    required this.host,
    this.participants = const [],
    this.requests = const [],
    this.totalParticipants = 0,
    this.taggedGroupIds = const [],
    this.taggedUserIds = const [],
    this.tags = const [],
  });

  bool get isLive => status == 'LIVE';
  bool get isScheduled => status == 'SCHEDULED';
  bool get isEnded => status == 'ENDED';

  List<AudioParticipant> get speakers =>
      participants.where((p) => p.isSpeaker).toList();

  List<AudioParticipant> get listeners =>
      participants.where((p) => p.isListener).toList();

  AudioRoom copyWith({
    String? hostId,
    String? currentHostId,
    String? title,
    String? description,
    String? category,
    String? visibility,
    String? speakersPermission,
    String? status,
    bool? isRecording,
    bool? isChatEnabled,
    bool? isLocked,
    int? maxSpeakers,
    DateTime? hostGracePeriodEndsAt,
    DateTime? scheduledAt,
    DateTime? startedAt,
    DateTime? endedAt,
    AudioRoomUser? host,
    List<AudioParticipant>? participants,
    List<AudioSpeakRequest>? requests,
    int? totalParticipants,
    List<String>? taggedGroupIds,
    List<String>? taggedUserIds,
    List<String>? tags,
  }) {
    return AudioRoom(
      id: id,
      hostId: hostId ?? this.hostId,
      currentHostId: currentHostId ?? this.currentHostId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      visibility: visibility ?? this.visibility,
      speakersPermission: speakersPermission ?? this.speakersPermission,
      status: status ?? this.status,
      isRecording: isRecording ?? this.isRecording,
      isChatEnabled: isChatEnabled ?? this.isChatEnabled,
      isLocked: isLocked ?? this.isLocked,
      maxSpeakers: maxSpeakers ?? this.maxSpeakers,
      hostGracePeriodEndsAt: hostGracePeriodEndsAt ?? this.hostGracePeriodEndsAt,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      createdAt: createdAt,
      host: host ?? this.host,
      participants: participants ?? this.participants,
      requests: requests ?? this.requests,
      totalParticipants: totalParticipants ?? this.totalParticipants,
      taggedGroupIds: taggedGroupIds ?? this.taggedGroupIds,
      taggedUserIds: taggedUserIds ?? this.taggedUserIds,
      tags: tags ?? this.tags,
    );
  }

  factory AudioRoom.fromJson(Map<String, dynamic> json) {
    final rawHost = json['host'];
    final hostObj = rawHost is Map<String, dynamic>
        ? AudioRoomUser.fromJson(rawHost)
        : AudioRoomUser(
            id: json['hostId'] as String? ?? '',
            username: 'Host',
            fullName: 'Room Host',
          );

    final rawParticipants = json['participants'];
    final parsedParticipants = <AudioParticipant>[];
    if (rawParticipants is List) {
      for (final p in rawParticipants) {
        if (p is Map<String, dynamic>) {
          parsedParticipants.add(AudioParticipant.fromJson(p));
        }
      }
    }

    final rawRequests = json['requests'];
    final parsedRequests = <AudioSpeakRequest>[];
    if (rawRequests is List) {
      for (final r in rawRequests) {
        if (r is Map<String, dynamic>) {
          parsedRequests.add(AudioSpeakRequest.fromJson(r));
        }
      }
    }

    final countMap = json['_count'] as Map<String, dynamic>?;
    final count = countMap?['participants'] as int? ?? parsedParticipants.length;

    List<String> parseStringList(dynamic raw) {
      if (raw is List) return raw.map((e) => e.toString()).toList();
      if (raw is String && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) return decoded.map((e) => e.toString()).toList();
        } catch (_) {}
      }
      return const [];
    }

    return AudioRoom(
      id: json['id'] as String? ?? '',
      hostId: json['hostId'] as String? ?? hostObj.id,
      currentHostId: json['currentHostId'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      category: (json['category'] as String? ?? 'ACADEMIC').toUpperCase(),
      visibility: (json['visibility'] as String? ?? 'PUBLIC').toUpperCase(),
      speakersPermission: (json['speakersPermission'] as String? ?? 'HOST_APPROVED').toUpperCase(),
      status: (json['status'] as String? ?? 'LIVE').toUpperCase(),
      isRecording: json['isRecording'] as bool? ?? false,
      isChatEnabled: json['isChatEnabled'] as bool? ?? true,
      isLocked: json['isLocked'] as bool? ?? false,
      maxSpeakers: json['maxSpeakers'] as int? ?? 15,
      hostGracePeriodEndsAt: json['hostGracePeriodEndsAt'] != null
          ? DateTime.tryParse(json['hostGracePeriodEndsAt'].toString())
          : null,
      scheduledAt: json['scheduledAt'] != null
          ? DateTime.tryParse(json['scheduledAt'].toString())
          : null,
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'].toString())
          : null,
      endedAt: json['endedAt'] != null
          ? DateTime.tryParse(json['endedAt'].toString())
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      host: hostObj,
      participants: parsedParticipants,
      requests: parsedRequests,
      totalParticipants: count,
      taggedGroupIds: parseStringList(json['taggedGroupIds']),
      taggedUserIds: parseStringList(json['taggedUserIds']),
      tags: parseStringList(json['tags']),
    );
  }
}
