import 'dart:convert';

class ChatMessage {
  final String id;
  final String senderId;
  final String content;
  final String type; // 'text', 'image', 'location', 'voice', 'giphy'
  final DateTime timestamp;
  final bool isRead;
  final List<String> readBy;
  final String? imageUrl;
  final double? imageWidth;
  final double? imageHeight;
  final String? audioUrl;
  final int? duration;
  final double? latitude;
  final double? longitude;
  final String? replyToId;
  final String? replyToContent;
  final String? replyToSenderId;
  final Map<String, String> reactions;
  final List<String> mentions;
  final bool isSnap;
  final bool isEdited;
  final bool isDeleted;
  final bool isPinned;
  final List<String> savedBy;
  final String? forwardedFrom;
  final String? sharedPostId;

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
    this.isPinned = false,
    this.savedBy = const [],
    this.forwardedFrom,
    this.sharedPostId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender_id': senderId,
      'content': content,
      'type': type,
      'created_at': timestamp.toIso8601String(),
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
      'is_pinned': isPinned,
      'saved_by': savedBy,
      if (forwardedFrom != null) 'forwarded_from': forwardedFrom,
      if (sharedPostId != null) 'shared_post_id': sharedPostId,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    DateTime ts = DateTime.now();
    final rawTs = map['created_at'] ?? map['createdAt'];
    if (rawTs is String) {
      ts = DateTime.tryParse(rawTs) ?? DateTime.now();
    }

    final readByRaw = map['read_by'] ?? map['readBy'];
    List<String> readByList = [];
    if (readByRaw is List) {
      readByList = List<String>.from(readByRaw.map((e) => e.toString()));
    } else if (readByRaw is String) {
      try {
        final decoded = jsonDecode(readByRaw);
        if (decoded is List) {
          readByList = List<String>.from(decoded.map((e) => e.toString()));
        }
      } catch (_) {}
    }

    final isReadVal = map['is_read'] == true ||
        map['isRead'] == true ||
        readByList.length > 1;

    final savedByRaw = map['saved_by'] ?? map['savedBy'];
    List<String> savedByList = [];
    if (savedByRaw is List) {
      savedByList = List<String>.from(savedByRaw.map((e) => e.toString()));
    } else if (savedByRaw is String) {
      try {
        final decoded = jsonDecode(savedByRaw);
        if (decoded is List) {
          savedByList = List<String>.from(decoded.map((e) => e.toString()));
        }
      } catch (_) {}
    }

    final isSnapVal = map['is_snap'] == true ||
        map['isSnap'] == true ||
        map['type'] == 'snap';

    return ChatMessage(
      id: map['id'] ?? '',
      senderId: map['sender_id'] ?? map['senderId'] ?? '',
      content: map['content'] ?? map['text'] ?? '',
      type: map['type'] ?? 'text',
      timestamp: ts,
      isRead: isReadVal,
      readBy: readByList,
      imageUrl: map['image_url'] ?? map['mediaUrl'],
      imageWidth: (map['image_width'] as num?)?.toDouble(),
      imageHeight: (map['image_height'] as num?)?.toDouble(),
      audioUrl: map['audio_url'],
      duration: map['duration'],
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      replyToId: map['reply_to_id'],
      replyToContent: map['reply_to_content'],
      replyToSenderId: map['reply_to_sender_id'],
      reactions: Map<String, String>.from(map['reactions'] ?? {}),
      mentions: List<String>.from(map['mentions'] ?? []),
      isSnap: isSnapVal,
      isEdited: map['is_edited'] ?? false,
      isDeleted: map['is_deleted'] ?? false,
      isPinned: map['is_pinned'] ?? false,
      savedBy: savedByList,
      forwardedFrom: map['forwarded_from'],
      sharedPostId: map['shared_post_id'] ??
          map['sharedPostId'] ??
          (map['mediaUrl'] != null && map['mediaUrl'].toString().startsWith('post:')
              ? map['mediaUrl'].toString().replaceFirst('post:', '')
              : null),
    );
  }
}
