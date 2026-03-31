import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String content;
  final String type; // 'text', 'image', 'location', 'voice', 'giphy'
  final DateTime timestamp;
  final bool isRead;
  final List<String> readBy; // List of user IDs who have read this message
  final String? imageUrl; // For image and giphy messages
  final double? imageWidth; // For proper aspect ratio
  final double? imageHeight;
  final String? audioUrl; // For voice messages
  final int? duration; // Duration in seconds
  final double? latitude; // For location messages
  final double? longitude;
  final String? replyToId;
  final String? replyToContent;
  final String? replyToSenderId;
  final Map<String, String> reactions; // userId -> emoji
  final List<String> mentions; // List of user IDs mentioned in the message
  final bool isSnap; // Whether it disappears after viewing
  final bool isEdited;
  final bool isDeleted;

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
    this.audioUrl,
    this.duration,
    this.latitude,
    this.longitude,
    this.replyToId,
    this.replyToContent,
    this.replyToSenderId,
    this.reactions = const {},
    this.mentions = const [],
    this.isSnap = false,
    this.isEdited = false,
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender_id': senderId,
      'content': content,
      'type': type,
      'created_at': Timestamp.fromDate(timestamp),
      'read_by': readBy,
      if (imageUrl != null) 'image_url': imageUrl,
      if (imageWidth != null) 'image_width': imageWidth,
      if (imageHeight != null) 'image_height': imageHeight,
      if (audioUrl != null) 'audio_url': audioUrl,
      if (duration != null) 'duration': duration,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (replyToId != null) 'reply_to_id': replyToId,
      if (replyToContent != null) 'reply_to_content': replyToContent,
      if (replyToSenderId != null) 'reply_to_sender_id': replyToSenderId,
      'reactions': reactions,
      'mentions': mentions,
      'is_snap': isSnap,
      'is_edited': isEdited,
      'is_deleted': isDeleted,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] ?? '',
      senderId: map['sender_id'] ?? '',
      content: map['content'] ?? '',
      type: map['type'] ?? 'text',
      timestamp: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: false,
      readBy: List<String>.from(map['read_by'] ?? []),
      imageUrl: map['image_url'],
      imageWidth: map['image_width']?.toDouble(),
      imageHeight: map['image_height']?.toDouble(),
      audioUrl: map['audio_url'],
      duration: map['duration'],
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      replyToId: map['reply_to_id'],
      replyToContent: map['reply_to_content'],
      replyToSenderId: map['reply_to_sender_id'],
      reactions: Map<String, String>.from(map['reactions'] ?? {}),
      mentions: List<String>.from(map['mentions'] ?? []),
      isSnap: map['is_snap'] ?? false,
      isEdited: map['is_edited'] ?? false,
      isDeleted: map['is_deleted'] ?? false,
    );
  }
}
