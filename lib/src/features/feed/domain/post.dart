import 'package:cloud_firestore/cloud_firestore.dart';

enum MediaType { none, image, video, gif }

class Post {
  final String id;
  final String authorId;
  final String authorName;
  final String authorHandle;
  final String? authorAvatarUrl;
  final String content;
  final String mediaUrl;
  final MediaType mediaType;
  final DateTime timestamp;
  final int likesCount;
  final int commentsCount;
  final int repostCount;
  final int viewsCount;
  final bool isLiked;
  final String channelId;
  final bool isVerified;
  final String verificationType;
  final bool isAnonymous;
  final Map<String, dynamic>? pollData;
  final Map<String, dynamic>? repostData;
  final List<String> hashtags;
  final List<String> mentions;
  final String visibility; // everyone, followers

  Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorHandle,
    this.authorAvatarUrl,
    required this.content,
    this.mediaUrl = '',
    this.mediaType = MediaType.none,
    required this.timestamp,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.repostCount = 0,
    this.viewsCount = 0,
    this.isLiked = false,
    this.channelId = 'general',
    this.isVerified = false,
    this.verificationType = 'none',
    this.isAnonymous = false,
    this.pollData,
    this.repostData,
    this.hashtags = const [],
    this.mentions = const [],
    this.visibility = 'everyone',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'author_id': authorId,
      'author_name': authorName,
      'author_handle': authorHandle,
      'author_avatar_url': authorAvatarUrl,
      'content': content,
      'media_url': mediaUrl,
      'media_type': mediaType.name,
      'channel_id': channelId,
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'repost_count': repostCount,
      'views_count': viewsCount,
      'poll_data': pollData,
      'repost_data': repostData,
      'created_at': Timestamp.fromDate(timestamp),
      'is_verified': isVerified,
      'verification_type': verificationType,
      'is_anonymous': isAnonymous,
      'hashtags': hashtags,
      'mentions': mentions,
      'visibility': visibility,
    };
  }

  factory Post.fromMap(Map<String, dynamic> map) {
    final mUrl = map['media_url'] ?? '';

    MediaType mType = MediaType.none;
    if (mUrl.isNotEmpty) {
      final typeStr = map['media_type'] as String?;
      if (typeStr != null) {
        mType = MediaType.values.firstWhere(
          (e) => e.name == typeStr,
          orElse: () => MediaType.none,
        );
      } else {
        // Fallback logic
        if (mUrl.endsWith('.mp4')) {
          mType = MediaType.video;
        } else if (mUrl.contains('giphy') || mUrl.endsWith('.gif')) {
          mType = MediaType.gif;
        } else {
          mType = MediaType.image;
        }
      }
    }

    return Post(
      id: map['id'] ?? '',
      authorId: map['author_id'] ?? '',
      authorName: map['author_name'] ?? 'Anonymous',
      authorHandle: map['author_handle'] ?? '@anon',
      authorAvatarUrl: map['author_avatar_url'],
      isVerified: map['is_verified'] ?? map['isVerified'] ?? false,
      verificationType:
          map['verification_type'] ??
          map['verificationType'] ??
          ((map['is_verified'] == true || map['isVerified'] == true)
              ? 'blue'
              : 'none'),
      isAnonymous: map['is_anonymous'] ?? false,
      content: map['content'] ?? '',
      mediaUrl: mUrl,
      mediaType: mType,
      timestamp: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likesCount: map['likes_count'] ?? 0,
      commentsCount: map['comments_count'] ?? 0,
      repostCount: map['repost_count'] ?? 0,
      viewsCount: map['views_count'] ?? 0,
      channelId: (map['channel_id'] == 'public')
          ? 'general'
          : (map['channel_id'] ?? 'general'),
      pollData: map['poll_data'],
      repostData: map['repost_data'],
      hashtags: List<String>.from(map['hashtags'] ?? []),
      mentions: List<String>.from(map['mentions'] ?? []),
      visibility: map['visibility'] ?? 'everyone',
    );
  }
}
