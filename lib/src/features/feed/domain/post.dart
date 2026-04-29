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
  final int sharesCount;
  final int savesCount;
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
  final String status; // active, flagged, removed
  final double? latitude;
  final double? longitude;
  final String replyPermission; // everyone, following, mentioned
  final DateTime? scheduledAt;
  final String? mediaAltText;
  final String? linkUrl;

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
    this.sharesCount = 0,
    this.savesCount = 0,
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
    this.status = 'active',
    this.latitude,
    this.longitude,
    this.replyPermission = 'everyone',
    this.scheduledAt,
    this.mediaAltText,
    this.linkUrl,
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
      'shares_count': sharesCount,
      'saves_count': savesCount,
      'poll_data': pollData,
      'repost_data': repostData,
      'created_at': Timestamp.fromDate(timestamp),
      'is_verified': isVerified,
      'verification_type': verificationType,
      'is_anonymous': isAnonymous,
      'hashtags': hashtags,
      'mentions': mentions,
      'visibility': visibility,
      'status': status,
      'latitude': latitude,
      'longitude': longitude,
      'reply_permission': replyPermission,
      'scheduled_at': scheduledAt != null
          ? Timestamp.fromDate(scheduledAt!)
          : null,
      'media_alt_text': mediaAltText,
      'link_url': linkUrl,
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

    final String postId = map['id'] ?? map['post_id'] ?? '';

    DateTime ts;
    final dynamic rawTs = map['created_at'] ?? map['timestamp'];
    if (rawTs is Timestamp) {
      ts = rawTs.toDate();
    } else if (rawTs is String) {
      ts = DateTime.tryParse(rawTs) ?? DateTime.now();
    } else {
      ts = DateTime.now();
    }

    return Post(
      id: postId,
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
      timestamp: ts,
      likesCount: map['likes_count'] ?? 0,
      commentsCount: map['comments_count'] ?? 0,
      repostCount: map['repost_count'] ?? 0,
      viewsCount: map['views_count'] ?? 0,
      sharesCount: map['shares_count'] ?? 0,
      savesCount: map['saves_count'] ?? 0,
      channelId: (map['channel_id'] == 'public')
          ? 'general'
          : (map['channel_id'] ?? 'general'),
      pollData: map['poll_data'],
      repostData: map['repost_data'],
      hashtags: List<String>.from(map['hashtags'] ?? []),
      mentions: List<String>.from(map['mentions'] ?? []),
      visibility: map['visibility'] ?? 'everyone',
      status: map['status'] ?? 'active',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      replyPermission: map['reply_permission'] ?? 'everyone',
      scheduledAt: (map['scheduled_at'] as Timestamp?)?.toDate(),
      mediaAltText: map['media_alt_text'],
      linkUrl: map['link_url'],
    );
  }

  Post copyWith({
    String? id,
    String? authorId,
    String? authorName,
    String? authorHandle,
    String? authorAvatarUrl,
    String? content,
    String? mediaUrl,
    MediaType? mediaType,
    DateTime? timestamp,
    int? likesCount,
    int? commentsCount,
    int? repostCount,
    int? viewsCount,
    int? sharesCount,
    int? savesCount,
    bool? isLiked,
    String? channelId,
    bool? isVerified,
    String? verificationType,
    bool? isAnonymous,
    Map<String, dynamic>? pollData,
    Map<String, dynamic>? repostData,
    List<String>? hashtags,
    List<String>? mentions,
    String? visibility,
    String? status,
    double? latitude,
    double? longitude,
    String? replyPermission,
    DateTime? scheduledAt,
    String? mediaAltText,
    String? linkUrl,
  }) {
    return Post(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorHandle: authorHandle ?? this.authorHandle,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      timestamp: timestamp ?? this.timestamp,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      repostCount: repostCount ?? this.repostCount,
      viewsCount: viewsCount ?? this.viewsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      savesCount: savesCount ?? this.savesCount,
      isLiked: isLiked ?? this.isLiked,
      channelId: channelId ?? this.channelId,
      isVerified: isVerified ?? this.isVerified,
      verificationType: verificationType ?? this.verificationType,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      pollData: pollData ?? this.pollData,
      repostData: repostData ?? this.repostData,
      hashtags: hashtags ?? this.hashtags,
      mentions: mentions ?? this.mentions,
      visibility: visibility ?? this.visibility,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      replyPermission: replyPermission ?? this.replyPermission,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      mediaAltText: mediaAltText ?? this.mediaAltText,
      linkUrl: linkUrl ?? this.linkUrl,
    );
  }
}
