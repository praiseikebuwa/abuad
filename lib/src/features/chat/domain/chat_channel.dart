import 'package:cloud_firestore/cloud_firestore.dart';

class ChatChannel {
  final String id;
  final String type; // 'direct' or 'group'
  final String? displayName; // Nullable for direct chats
  final String? displayAvatarUrl; // Nullable for direct chats
  final String? createdBy; // userId of group creator
  final List<String> memberIds;
  final Map<String, dynamic> lastMessage; // copy of the last message
  final DateTime lastMessageTime;
  final Map<String, int> unreadCounts;
  final Map<String, bool> typingUsers; // userId -> isTyping
  final Map<String, String> memberNames; // userId -> displayName
  final Map<String, String?> memberAvatars; // userId -> avatarUrl
  final Map<String, String> verificationTypes; // userId -> verificationType
  final List<String> adminIds;
  final bool restrictInfoUpdates;
  final bool restrictMessaging;
  final int streakCount;
  final Map<String, DateTime> lastSnapTime;
  final DateTime? streakExpiry;

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
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'display_name': displayName,
      'display_avatar_url': displayAvatarUrl,
      'created_by': createdBy,
      'member_ids': memberIds,
      'last_message': lastMessage,
      'last_message_time': Timestamp.fromDate(lastMessageTime),
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
        (key, value) => MapEntry(key, Timestamp.fromDate(value)),
      ),
      'streak_expiry': streakExpiry != null
          ? Timestamp.fromDate(streakExpiry!)
          : null,
    };
  }

  factory ChatChannel.fromMap(Map<String, dynamic> map) {
    return ChatChannel(
      id: map['id'] ?? '',
      type: map['type'] ?? 'direct',
      displayName: map['display_name'],
      displayAvatarUrl: map['display_avatar_url'],
      createdBy: map['created_by'],
      memberIds: List<String>.from(map['member_ids'] ?? []),
      lastMessage: Map<String, dynamic>.from(map['last_message'] ?? {}),
      lastMessageTime:
          (map['last_message_time'] as Timestamp?)?.toDate() ?? DateTime.now(),
      unreadCounts: Map<String, int>.from(map['unread_counts'] ?? {}),
      typingUsers: Map<String, bool>.from(map['typing_users'] ?? {}),
      memberNames: Map<String, String>.from(map['member_names'] ?? {}),
      memberAvatars: Map<String, String?>.from(map['member_avatars'] ?? {}),
      verificationTypes: Map<String, String>.from(
        map['verification_types'] ?? {},
      ),
      adminIds: List<String>.from(map['admin_ids'] ?? []),
      restrictInfoUpdates: map['restrict_info_updates'] ?? false,
      restrictMessaging: map['restrict_messaging'] ?? false,
      streakCount: map['streak_count'] ?? 0,
      lastSnapTime:
          (map['last_snap_time'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, (value as Timestamp).toDate()),
          ) ??
          {},
      streakExpiry: (map['streak_expiry'] as Timestamp?)?.toDate(),
    );
  }
}
