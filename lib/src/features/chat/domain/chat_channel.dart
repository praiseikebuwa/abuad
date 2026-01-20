class ChatChannel {
  final String id;
  final List<String> memberIds;
  final Map<String, dynamic> lastMessage; // copy of the last message
  final DateTime lastMessageTime;
  final Map<String, int> unreadCounts;

  ChatChannel({
    required this.id,
    required this.memberIds,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCounts = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'memberIds': memberIds,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime.millisecondsSinceEpoch,
      'unreadCounts': unreadCounts,
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
    );
  }
}
