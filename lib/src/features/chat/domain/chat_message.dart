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
    // For inserting into Supabase
    return {
      // 'id': id, // Let DB generate ID or use provided
      'sender_id': senderId,
      'content': content,
      'type': type,
      'created_at': timestamp
          .millisecondsSinceEpoch, // or ISO string if column is timestamptz
      'read_by': readBy,
      'image_url': imageUrl,
      'image_width': imageWidth,
      'image_height': imageHeight,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] ?? '',
      senderId: map['sender_id'] ?? '',
      content: map['content'] ?? '',
      type: map['type'] ?? 'text',
      timestamp: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'])
          : DateTime.now(),
      isRead: false, // Computed from readBy usually
      readBy: List<String>.from(map['read_by'] ?? []),
      imageUrl: map['image_url'],
      imageWidth: map['image_width']?.toDouble(),
      imageHeight: map['image_height']?.toDouble(),
    );
  }
}
