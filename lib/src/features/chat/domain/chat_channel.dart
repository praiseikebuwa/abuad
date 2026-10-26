import 'dart:convert';

class ChatChannel {
  final String id;
  final String type; // 'direct' or 'group'
  final String? displayName;
  final String? displayAvatarUrl;
  final String? createdBy;
  final List<String> memberIds;
  final Map<String, dynamic> lastMessage;
  final DateTime lastMessageTime;
  final Map<String, int> unreadCounts;
  final Map<String, bool> typingUsers;
  final Map<String, String> memberNames;
  final Map<String, String?> memberAvatars;
  final Map<String, String> verificationTypes;
  final List<String> adminIds;
  final bool restrictInfoUpdates;
  final bool restrictMessaging;
  final int streakCount;
  final Map<String, DateTime> lastSnapTime;
  final DateTime? streakExpiry;
  final List<String> pinnedBy;
  final List<String> archivedBy;

  ChatChannel({
    required this.id,
    this.type = 'direct',
    this.displayName,
    this.displayAvatarUrl,
    this.createdBy,
    required this.memberIds,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCounts = const {},
    this.typingUsers = const {},
    this.memberNames = const {},
    this.memberAvatars = const {},
    this.verificationTypes = const {},
    this.adminIds = const [],
    this.restrictInfoUpdates = false,
    this.restrictMessaging = false,
    this.streakCount = 0,
    this.lastSnapTime = const {},
    this.streakExpiry,
    this.pinnedBy = const [],
    this.archivedBy = const [],
  });

  bool get isGroup => type == 'group' || memberIds.length > 2 || id.startsWith('group_');

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'display_name': displayName,
      'display_avatar_url': displayAvatarUrl,
      'created_by': createdBy,
      'member_ids': memberIds,
      'last_message': lastMessage,
      'last_message_time': lastMessageTime.toIso8601String(),
      'member_names': memberNames,
      'member_avatars': memberAvatars,
      'verification_types': verificationTypes,
      'admin_ids': adminIds,
      'restrict_info_updates': restrictInfoUpdates,
      'restrict_messaging': restrictMessaging,
      'unread_counts': unreadCounts,
      'typing_users': typingUsers,
      'streak_count': streakCount,
      'last_snap_time': lastSnapTime.map(
        (key, value) => MapEntry(key, value.toIso8601String()),
      ),
      'streak_expiry': streakExpiry?.toIso8601String(),
      'pinned_by': pinnedBy,
      'archived_by': archivedBy,
    };
  }

  factory ChatChannel.fromMap(Map<String, dynamic> map) {
    DateTime parseTime(dynamic raw) {
      if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
      return DateTime.now();
    }

    List<String> parseList(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      if (raw is String && raw.isNotEmpty) {
        try {
          final decoded = json.decode(raw);
          if (decoded is List) return decoded.map((e) => e.toString()).toList();
        } catch (_) {}
      }
      return [];
    }

    Map<String, String> parseStringMap(dynamic raw) {
      if (raw == null) return {};
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
      }
      if (raw is String && raw.isNotEmpty) {
        try {
          final decoded = json.decode(raw);
          if (decoded is Map) {
            return decoded.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
          }
        } catch (_) {}
      }
      return {};
    }

    Map<String, String?> parseNullableStringMap(dynamic raw) {
      if (raw == null) return {};
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(k.toString(), v?.toString()));
      }
      if (raw is String && raw.isNotEmpty) {
        try {
          final decoded = json.decode(raw);
          if (decoded is Map) {
            return decoded.map((k, v) => MapEntry(k.toString(), v?.toString()));
          }
        } catch (_) {}
      }
      return {};
    }

    Map<String, dynamic> parseLastMessage(dynamic raw) {
      if (raw is Map) return Map<String, dynamic>.from(raw);
      if (raw is String && raw.isNotEmpty) {
        try {
          final decoded = json.decode(raw);
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        } catch (_) {}
        return {'content': raw, 'text': raw};
      }
      return {};
    }

    return ChatChannel(
      id: map['id'] ?? '',
      type: map['type'] ?? 'direct',
      displayName: map['display_name'] ?? map['displayName'] ?? map['name'],
      displayAvatarUrl: map['display_avatar_url'] ?? map['displayAvatarUrl'],
      createdBy: map['created_by'] ?? map['createdBy'],
      memberIds: parseList(map['member_ids'] ?? map['memberIds']),
      lastMessage: parseLastMessage(map['last_message'] ?? map['lastMessage']),
      lastMessageTime: parseTime(map['last_message_time'] ?? map['lastMessageTime'] ?? map['createdAt']),
      unreadCounts: Map<String, int>.from(map['unread_counts'] ?? map['unreadCounts'] ?? {}),
      typingUsers: Map<String, bool>.from(map['typing_users'] ?? map['typingUsers'] ?? {}),
      memberNames: parseStringMap(map['member_names'] ?? map['memberNames']),
      memberAvatars: parseNullableStringMap(map['member_avatars'] ?? map['memberAvatars']),
      verificationTypes: parseStringMap(map['verification_types'] ?? map['verificationTypes']),
      adminIds: parseList(map['admin_ids'] ?? map['adminIds']),
      restrictInfoUpdates: map['restrict_info_updates'] ?? map['restrictInfoUpdates'] ?? false,
      restrictMessaging: map['restrict_messaging'] ?? map['restrictMessaging'] ?? false,
      streakCount: map['streak_count'] ?? map['streakCount'] ?? 0,
      lastSnapTime: (map['last_snap_time'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, parseTime(value)),
          ) ?? {},
      streakExpiry: map['streak_expiry'] != null ? parseTime(map['streak_expiry']) : null,
      pinnedBy: parseList(map['pinned_by'] ?? map['pinnedBy']),
      archivedBy: parseList(map['archived_by'] ?? map['archivedBy']),
    );
  }

  ChatChannel copyWith({
    String? id,
    String? type,
    String? displayName,
    String? displayAvatarUrl,
    String? createdBy,
    List<String>? memberIds,
    Map<String, dynamic>? lastMessage,
    DateTime? lastMessageTime,
    Map<String, int>? unreadCounts,
    Map<String, bool>? typingUsers,
    Map<String, String>? memberNames,
    Map<String, String?>? memberAvatars,
    Map<String, String>? verificationTypes,
    List<String>? adminIds,
    bool? restrictInfoUpdates,
    bool? restrictMessaging,
    int? streakCount,
    Map<String, DateTime>? lastSnapTime,
    DateTime? streakExpiry,
    List<String>? pinnedBy,
    List<String>? archivedBy,
  }) {
    return ChatChannel(
      id: id ?? this.id,
      type: type ?? this.type,
      displayName: displayName ?? this.displayName,
      displayAvatarUrl: displayAvatarUrl ?? this.displayAvatarUrl,
      createdBy: createdBy ?? this.createdBy,
      memberIds: memberIds ?? this.memberIds,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCounts: unreadCounts ?? this.unreadCounts,
      typingUsers: typingUsers ?? this.typingUsers,
      memberNames: memberNames ?? this.memberNames,
      memberAvatars: memberAvatars ?? this.memberAvatars,
      verificationTypes: verificationTypes ?? this.verificationTypes,
      adminIds: adminIds ?? this.adminIds,
      restrictInfoUpdates: restrictInfoUpdates ?? this.restrictInfoUpdates,
      restrictMessaging: restrictMessaging ?? this.restrictMessaging,
      streakCount: streakCount ?? this.streakCount,
      lastSnapTime: lastSnapTime ?? this.lastSnapTime,
      streakExpiry: streakExpiry ?? this.streakExpiry,
      pinnedBy: pinnedBy ?? this.pinnedBy,
      archivedBy: archivedBy ?? this.archivedBy,
    );
  }
}
