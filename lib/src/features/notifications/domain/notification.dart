import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  follow,
  like,
  comment,
  mention,
  repost,
  system,
  chat,
  sos,
}

class AppNotification {
  final String id;
  final String recipientId;
  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final NotificationType type;
  final String title;
  final String body;
  final String? relatedId; // Post ID, Comment ID, etc.
  final DateTime timestamp;
  final bool isRead;

  AppNotification({
    required this.id,
    required this.recipientId,
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    required this.type,
    required this.title,
    required this.body,
    this.relatedId,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recipient_id': recipientId,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_avatar_url': senderAvatarUrl,
      'type': type.name,
      'title': title,
      'body': body,
      'related_id': relatedId,
      'timestamp': Timestamp.fromDate(timestamp),
      'is_read': isRead,
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] ?? '',
      recipientId: map['recipient_id'] ?? '',
      senderId: map['sender_id'] ?? '',
      senderName: map['sender_name'] ?? '',
      senderAvatarUrl: map['sender_avatar_url'],
      type: NotificationType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => NotificationType.system,
      ),
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      relatedId: map['related_id'],
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: map['is_read'] ?? false,
    );
  }
}
