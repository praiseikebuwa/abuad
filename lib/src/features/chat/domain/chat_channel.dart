class ChatChannel {
  final String id;
  final List<String> memberIds;
  final Map<String, dynamic> lastMessage; // copy of the last message
  final DateTime lastMessageTime;
  final Map<String, int> unreadCounts;
  final Map<String, bool> typingUsers; // userId -> isTyping
  final Map<String, String> memberNames; // userId -> displayName
  final Map<String, String?> memberAvatars; // userId -> avatarUrl

  ChatChannel({
    required this.id,
    required this.memberIds,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCounts = const {},
    this.typingUsers = const {},
    this.memberNames = const {},
    this.memberAvatars = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      // 'memberIds': memberIds, // Handled via join table
      'last_message': lastMessage,
      'last_message_time': lastMessageTime.millisecondsSinceEpoch,
      // 'unreadCounts': unreadCounts, // Computed or separate
      // 'typingUsers': typingUsers, // Use Realtime Presence
      // 'memberNames': memberNames, // Derived
      // 'memberAvatars': memberAvatars, // Derived
    };
  }

  factory ChatChannel.fromMap(
    Map<String, dynamic> map, {
    String? currentUserId,
  }) {
    // Handling joins.
    // Map expects 'channel_members' list of { user_id, profiles: { ... } }
    final membersData = map['channel_members'] as List<dynamic>? ?? [];

    final memberIds = <String>[];
    final memberNames = <String, String>{};
    final memberAvatars = <String, String?>{};

    for (final m in membersData) {
      final uid = m['user_id'] as String;
      final profile = m['profiles'] as Map<String, dynamic>?;

      memberIds.add(uid);
      if (profile != null) {
        memberNames[uid] = profile['display_name'] ?? 'Unknown';
        memberAvatars[uid] = profile['avatar_url'];
      }
    }

    return ChatChannel(
      id: map['id'] ?? '',
      memberIds: memberIds,
      lastMessage: Map<String, dynamic>.from(map['last_message'] ?? {}),
      lastMessageTime: map['last_message_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_message_time'])
          : DateTime.now(),
      unreadCounts: {}, // Fetch separate or compute
      typingUsers: {}, // Realtime
      memberNames: memberNames,
      memberAvatars: memberAvatars,
    );
  }
}
