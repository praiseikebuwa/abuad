class ChatMessage {
  final String id;
  final String senderId;
  final String content;
  final String type; // 'text', 'image'
  final DateTime timestamp;
  final bool isRead;
  final List<String> readBy; // List of user IDs who have read this message
  final String? imageUrl; // For image messages
  final double? imageWidth; // For proper aspect ratio
  final double? imageHeight;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.content,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.readBy = const [],
    this.imageUrl,
    this.imageWidth,
    this.imageHeight,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'content': content,
      'type': type,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isRead': isRead,
      'readBy': readBy,
      'imageUrl': imageUrl,
      'imageWidth': imageWidth,
      'imageHeight': imageHeight,
    };
  }

  factory ChatMessage.fromMap(String id, Map<String, dynamic> map) {
    return ChatMessage(
      id: id,
      senderId: map['senderId'] ?? '',
      content: map['content'] ?? '',
      type: map['type'] ?? 'text',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        map['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
      isRead: map['isRead'] ?? false,
      readBy: List<String>.from(map['readBy'] ?? []),
      imageUrl: map['imageUrl'],
      imageWidth: map['imageWidth']?.toDouble(),
      imageHeight: map['imageHeight']?.toDouble(),
    );
  }
}
