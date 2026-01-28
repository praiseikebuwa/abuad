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
      'memberIds': memberIds,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime.millisecondsSinceEpoch,
      'unreadCounts': unreadCounts,
      'typingUsers': typingUsers,
      'memberNames': memberNames,
      'memberAvatars': memberAvatars,
    };
  }

  factory ChatChannel.fromMap(String id, Map<String, dynamic> map) {
    return ChatChannel(
      id: id,
      memberIds: List<String>.from(map['memberIds'] ?? []),
      lastMessage: Map<String, dynamic>.from(map['lastMessage'] ?? {}),
      lastMessageTime: DateTime.fromMillisecondsSinceEpoch(
        map['lastMessageTime'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
      unreadCounts: Map<String, int>.from(map['unreadCounts'] ?? {}),
      typingUsers: Map<String, bool>.from(map['typingUsers'] ?? {}),
      memberNames: Map<String, String>.from(map['memberNames'] ?? {}),
      memberAvatars: Map<String, String?>.from(map['memberAvatars'] ?? {}),
    );
  }
}
