import 'dart:convert';

class Story {
  final String id;
  final String authorId;
  final String content;
  final String type;
  final String? caption;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<String> viewers;
  final List<String> likes;
  final List<String> mentions;
  final String? linkUrl;
  final String visibility;
  final int? backgroundColor;
  final int? textColor;
  final String? fontFamily;
  final String? textAlign;
  final String status;
  final String userName;
  final String userAvatar;
  final String? reshareAuthorId;
  final String? reshareAuthorName;
  final String? reshareStoryId;

  Story({
    required this.id,
    required this.authorId,
    required this.content,
    this.type = 'image',
    this.caption,
    required this.createdAt,
    required this.expiresAt,
    this.viewers = const [],
    this.likes = const [],
    this.mentions = const [],
    this.linkUrl,
    this.visibility = 'everyone',
    this.backgroundColor,
    this.textColor,
    this.fontFamily,
    this.textAlign,
    this.status = 'active',
    this.userName = '',
    this.userAvatar = '',
    this.reshareAuthorId,
    this.reshareAuthorName,
    this.reshareStoryId,
  });

  Story copyWith({
    String? id,
    String? authorId,
    String? content,
    String? type,
    String? caption,
    DateTime? createdAt,
    DateTime? expiresAt,
    List<String>? viewers,
    List<String>? likes,
    List<String>? mentions,
    String? linkUrl,
    String? visibility,
    int? backgroundColor,
    int? textColor,
    String? fontFamily,
    String? textAlign,
    String? status,
    String? userName,
    String? userAvatar,
    String? reshareAuthorId,
    String? reshareAuthorName,
    String? reshareStoryId,
  }) {
    return Story(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      content: content ?? this.content,
      type: type ?? this.type,
      caption: caption ?? this.caption,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      viewers: viewers ?? this.viewers,
      likes: likes ?? this.likes,
      mentions: mentions ?? this.mentions,
      linkUrl: linkUrl ?? this.linkUrl,
      visibility: visibility ?? this.visibility,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      fontFamily: fontFamily ?? this.fontFamily,
      textAlign: textAlign ?? this.textAlign,
      status: status ?? this.status,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      reshareAuthorId: reshareAuthorId ?? this.reshareAuthorId,
      reshareAuthorName: reshareAuthorName ?? this.reshareAuthorName,
      reshareStoryId: reshareStoryId ?? this.reshareStoryId,
    );
  }

  bool hasViewed(String userId) => viewers.contains(userId);
  bool hasLiked(String userId) => likes.contains(userId);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'author_id': authorId,
      'content': content,
      'mediaUrl': content,
      'media_url': content,
      'mediaType': type,
      'type': type,
      'caption': caption,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'viewers': viewers,
      'likes': likes,
      'mentions': mentions,
      'link_url': linkUrl,
      'visibility': visibility,
      'background_color': backgroundColor,
      'text_color': textColor,
      'font_family': fontFamily,
      'text_align': textAlign,
      'status': status,
      'user_name': userName,
      'user_avatar': userAvatar,
      'reshare_author_id': reshareAuthorId,
      'reshare_author_name': reshareAuthorName,
      'reshare_story_id': reshareStoryId,
    };
  }

  factory Story.fromMap(Map<String, dynamic> map) {
    DateTime parseTime(dynamic raw) {
      if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
      return DateTime.now();
    }

    List<String> parseStringList(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      if (raw is String && raw.isNotEmpty) {
        try {
          final decoded = json.decode(raw);
          if (decoded is List) {
            return decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {}
      }
      return [];
    }

    final authorMap = map['author'] is Map<String, dynamic>
        ? map['author'] as Map<String, dynamic>
        : null;

    return Story(
      id: map['id'] ?? map['_id'] ?? '',
      authorId: map['author_id'] ??
          map['authorId'] ??
          authorMap?['id'] ??
          authorMap?['_id'] ??
          '',
      content: map['content'] ?? map['mediaUrl'] ?? map['media_url'] ?? '',
      type: map['type'] ?? map['mediaType'] ?? 'image',
      caption: map['caption'],
      createdAt: parseTime(map['created_at'] ?? map['createdAt']),
      expiresAt: parseTime(map['expires_at'] ?? map['expiresAt']),
      viewers: parseStringList(map['viewers'] ?? map['viewers_list']),
      likes: parseStringList(map['likes'] ?? map['likes_list']),
      mentions: parseStringList(map['mentions']),
      linkUrl: map['link_url'] ?? map['linkUrl'],
      visibility: map['visibility'] ?? 'everyone',
      backgroundColor: map['background_color'] ?? map['backgroundColor'],
      textColor: map['text_color'] ?? map['textColor'],
      fontFamily: map['font_family'] ?? map['fontFamily'],
      textAlign: map['text_align'] ?? map['textAlign'],
      status: map['status'] ?? 'active',
      userName: map['user_name'] ??
          map['userName'] ??
          authorMap?['fullName'] ??
          authorMap?['username'] ??
          '',
      userAvatar: map['user_avatar'] ??
          map['userAvatar'] ??
          authorMap?['avatarUrl'] ??
          '',
      reshareAuthorId: map['reshare_author_id'] ?? map['reshareAuthorId'],
      reshareAuthorName: map['reshare_author_name'] ?? map['reshareAuthorName'],
      reshareStoryId: map['reshare_story_id'] ?? map['reshareStoryId'],
    );
  }
}
