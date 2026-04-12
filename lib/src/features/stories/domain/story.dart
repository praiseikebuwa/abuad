import 'package:cloud_firestore/cloud_firestore.dart';

class Story {
  final String id;
  final String authorId;
  final String content; // URL for image/video or text
  final String type; // 'image', 'video', 'text'
  final String? caption;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<String> viewers;
  final List<String> likes;
  final List<String> mentions;
  final String? linkUrl;
  final String visibility; // 'everyone', 'followers', 'close_friends'
  final int? backgroundColor;
  final int? textColor;
  final String? fontFamily;
  final String? textAlign;
  final String status; // 'active', 'flagged', 'deleted'
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
      'type': type,
      'caption': caption,
      'created_at': Timestamp.fromDate(createdAt),
      'expires_at': Timestamp.fromDate(expiresAt),
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
    return Story(
      id: map['id'] ?? '',
      authorId: map['author_id'] ?? '',
      content: map['content'] ?? '',
      type: map['type'] ?? 'image',
      caption: map['caption'],
      createdAt: (map['created_at'] as Timestamp).toDate(),
      expiresAt: (map['expires_at'] as Timestamp).toDate(),
      viewers: List<String>.from(map['viewers'] ?? []),
      likes: List<String>.from(map['likes'] ?? []),
      mentions: List<String>.from(map['mentions'] ?? []),
      linkUrl: map['link_url'],
      visibility: map['visibility'] ?? 'everyone',
      backgroundColor: map['background_color'],
      textColor: map['text_color'],
      fontFamily: map['font_family'],
      textAlign: map['text_align'],
      status: map['status'] ?? 'active',
      userName: map['user_name'] ?? '',
      userAvatar: map['user_avatar'] ?? '',
      reshareAuthorId: map['reshare_author_id'],
      reshareAuthorName: map['reshare_author_name'],
      reshareStoryId: map['reshare_story_id'],
    );
  }
}
