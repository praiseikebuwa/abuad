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
  final String userName;
  final String userAvatar;

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
    this.userName = '',
    this.userAvatar = '',
  });

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
      'user_name': userName,
      'user_avatar': userAvatar,
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
      userName: map['user_name'] ?? '',
      userAvatar: map['user_avatar'] ?? '',
    );
  }
}
