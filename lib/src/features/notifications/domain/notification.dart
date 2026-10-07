enum NotificationType {
  follow,
  unfollow,
  followingPost,
  like,
  comment,
  mention,
  repost,
  system,
  chat,
  sos,
  streakExpiring,
  streakMissed,
  storyUpdate,
}

class AppNotification {
  final String id;
  final String recipientId;
  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final String? senderHandle;
  final bool senderIsVerified;
  final String senderVerificationType;
  final NotificationType type;
  final String title;
  final String body;
  final String? relatedId;
  final DateTime timestamp;
  final bool isRead;

  AppNotification({
    required this.id,
    required this.recipientId,
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    this.senderHandle,
    this.senderIsVerified = false,
    this.senderVerificationType = 'NONE',
    required this.type,
    required this.title,
    required this.body,
    this.relatedId,
    required this.timestamp,
    this.isRead = false,
  });

  AppNotification copyWith({
    String? id,
    String? recipientId,
    String? senderId,
    String? senderName,
    String? senderAvatarUrl,
    String? senderHandle,
    bool? senderIsVerified,
    String? senderVerificationType,
    NotificationType? type,
    String? title,
    String? body,
    String? relatedId,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return AppNotification(
      id: id ?? this.id,
      recipientId: recipientId ?? this.recipientId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
      senderHandle: senderHandle ?? this.senderHandle,
      senderIsVerified: senderIsVerified ?? this.senderIsVerified,
      senderVerificationType: senderVerificationType ?? this.senderVerificationType,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      relatedId: relatedId ?? this.relatedId,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recipient_id': recipientId,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_avatar_url': senderAvatarUrl,
      'sender_handle': senderHandle,
      'sender_is_verified': senderIsVerified,
      'sender_verification_type': senderVerificationType,
      'type': type.name,
      'title': title,
      'body': body,
      'related_id': relatedId,
      'timestamp': timestamp.toIso8601String(),
      'is_read': isRead,
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    DateTime parseTime(dynamic raw) {
      if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
      if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
      return DateTime.now();
    }

    final rawType = (map['type'] ?? 'system').toString().toLowerCase();

    return AppNotification(
      id: (map['id'] ?? '').toString(),
      recipientId: (map['recipient_id'] ?? map['userId'] ?? map['recipientId'] ?? '').toString(),
      senderId: (map['sender_id'] ?? map['senderId'] ?? '').toString(),
      senderName: (map['sender_name'] ?? map['senderName'] ?? map['sender']?['fullName'] ?? map['sender']?['username'] ?? 'User').toString(),
      senderAvatarUrl: map['sender_avatar_url'] ?? map['senderAvatarUrl'] ?? map['sender']?['avatarUrl'],
      senderHandle: map['sender_handle'] ?? map['senderHandle'] ?? map['sender']?['username'],
      senderIsVerified: map['sender_is_verified'] == true || map['senderIsVerified'] == true || map['sender']?['isVerified'] == true,
      senderVerificationType: (map['sender_verification_type'] ?? map['senderVerificationType'] ?? map['sender']?['verificationType'] ?? 'NONE').toString(),
      type: NotificationType.values.firstWhere(
        (e) => e.name.toLowerCase() == rawType,
        orElse: () => NotificationType.system,
      ),
      title: (map['title'] ?? 'Notification').toString(),
      body: (map['body'] ?? '').toString(),
      relatedId: map['related_id'] ?? map['relatedId'],
      timestamp: parseTime(map['timestamp'] ?? map['createdAt']),
      isRead: map['is_read'] == true || map['isRead'] == true,
    );
  }
}
