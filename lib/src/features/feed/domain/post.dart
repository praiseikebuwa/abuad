import 'dart:convert';
import '../../../core/utils/url_validator.dart';

enum MediaType { none, image, video, gif, document }

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
  final bool isSaved;
  final String channelId;
  final bool isVerified;
  final String verificationType;
  final bool isAnonymous;
  final Map<String, dynamic>? pollData;
  final Map<String, dynamic>? repostData;
  final List<String> hashtags;
  final List<String> mentions;
  final String visibility;
  final String status;
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final String replyPermission;
  final DateTime? scheduledAt;
  final String? mediaAltText;
  final String? linkUrl;
  final List<String> mediaUrls;

  Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorHandle,
    this.authorAvatarUrl,
    required this.content,
    this.mediaUrl = '',
    this.mediaType = MediaType.none,
    this.mediaUrls = const [],
    required this.timestamp,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.repostCount = 0,
    this.viewsCount = 0,
    this.sharesCount = 0,
    this.savesCount = 0,
    this.isLiked = false,
    this.isSaved = false,
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
    this.locationName,
    this.replyPermission = 'everyone',
    this.scheduledAt,
    this.mediaAltText,
    this.linkUrl,
  });

  List<String> get allMediaUrls {
    if (mediaUrls.isNotEmpty) return mediaUrls;
    if (mediaUrl.isNotEmpty) return [mediaUrl];
    return const [];
  }

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
      'media_urls': mediaUrls.isNotEmpty ? mediaUrls : (mediaUrl.isNotEmpty ? [mediaUrl] : []),
      'mediaUrls': mediaUrls.isNotEmpty ? mediaUrls : (mediaUrl.isNotEmpty ? [mediaUrl] : []),
      'channel_id': channelId,
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'repost_count': repostCount,
      'views_count': viewsCount,
      'shares_count': sharesCount,
      'saves_count': savesCount,
      'is_liked': isLiked,
      'is_saved': isSaved,
      'poll_data': pollData,
      'repost_data': repostData,
      'created_at': timestamp.toIso8601String(),
      'is_verified': isVerified,
      'verification_type': verificationType,
      'is_anonymous': isAnonymous,
      'hashtags': hashtags,
      'mentions': mentions,
      'visibility': visibility,
      'status': status,
      'latitude': latitude,
      'longitude': longitude,
      'location_name': locationName,
      'reply_permission': replyPermission,
      'scheduled_at': scheduledAt?.toIso8601String(),
      'media_alt_text': mediaAltText,
      'link_url': linkUrl,
    };
  }

  factory Post.fromMap(Map<String, dynamic> map) {
    final mUrl = map['media_url'] ?? map['mediaUrl'] ?? '';

    MediaType mType = MediaType.none;
    final typeStr = map['media_type'] ?? map['mediaType'];
    if (typeStr != null && typeStr is String && typeStr.isNotEmpty) {
      mType = MediaType.values.firstWhere(
        (e) => e.name == typeStr,
        orElse: () => MediaType.none,
      );
    }
    if (mUrl.isNotEmpty) {
      final lower = mUrl.toLowerCase();
      if (lower.contains('.mp4') ||
          lower.contains('.mov') ||
          lower.contains('.webm') ||
          lower.contains('.m3u8') ||
          lower.contains('/videos/')) {
        mType = MediaType.video;
      } else if (lower.contains('giphy') || lower.endsWith('.gif')) {
        mType = MediaType.gif;
      } else if (lower.endsWith('.pdf') ||
          lower.endsWith('.doc') ||
          lower.endsWith('.docx') ||
          lower.endsWith('.ppt') ||
          lower.endsWith('.pptx') ||
          lower.endsWith('.xls') ||
          lower.endsWith('.xlsx') ||
          lower.endsWith('.txt')) {
        mType = MediaType.document;
      } else if (mType == MediaType.none) {
        mType = MediaType.image;
      }
    }

    final String postId = map['id'] ?? map['post_id'] ?? '';

    DateTime parseTime(dynamic raw) {
      if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
      return DateTime.now();
    }

    int parseInt(dynamic raw) {
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw) ?? 0;
      return 0;
    }

    List<String> parseStringList(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      if (raw is String && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) return decoded.map((e) => e.toString()).toList();
        } catch (_) {}
      }
      return [];
    }

    Map<String, dynamic>? parseMap(dynamic raw) {
      if (raw == null) return null;
      if (raw is Map<String, dynamic>) return raw;
      if (raw is String && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) return decoded;
        } catch (_) {}
      }
      return null;
    }

    final String rawHandle = map['author_handle'] ?? map['author']?['username'] ?? 'anon';
    final String handle = rawHandle.startsWith('@') ? rawHandle : '@$rawHandle';

    final formattedMUrl = UrlValidator.formatImageUrl(mUrl);
    List<String> mUrls = parseStringList(map['media_urls'] ?? map['mediaUrls'])
        .map((u) => UrlValidator.formatImageUrl(u))
        .where((u) => u.isNotEmpty)
        .toList();
    if (mUrls.isEmpty && formattedMUrl.isNotEmpty) {
      mUrls = [formattedMUrl];
    }
    final rawAvatar = map['author_avatar_url'] ?? map['author']?['avatarUrl'];
    final formattedAvatarUrl = UrlValidator.formatImageUrl(rawAvatar);

    return Post(
      id: postId,
      authorId: map['author_id'] ?? map['authorId'] ?? map['author']?['id'] ?? '',
      authorName: map['author_name'] ?? map['author']?['fullName'] ?? map['author']?['username'] ?? 'Anonymous',
      authorHandle: handle,
      authorAvatarUrl: formattedAvatarUrl.isNotEmpty ? formattedAvatarUrl : null,
      isVerified: map['is_verified'] ?? map['isVerified'] ?? map['author']?['isVerified'] ?? false,
      verificationType: (map['verification_type'] ??
              map['verificationType'] ??
              map['author']?['verificationType'] ??
              ((map['is_verified'] == true || map['isVerified'] == true || map['author']?['isVerified'] == true)
                  ? 'blue'
                  : 'none'))
          .toString()
          .toLowerCase(),
      isAnonymous: map['is_anonymous'] ?? map['isAnonymous'] ?? false,
      content: map['content'] ?? '',
      mediaUrl: formattedMUrl.isNotEmpty ? formattedMUrl : (mUrls.isNotEmpty ? mUrls.first : ''),
      mediaUrls: mUrls,
      mediaType: mType,
      timestamp: parseTime(map['created_at'] ?? map['createdAt']),
      likesCount: parseInt(map['likes_count'] ?? map['likesCount'] ?? map['_count']?['likes']),
      commentsCount: parseInt(map['comments_count'] ?? map['commentsCount'] ?? map['_count']?['comments']),
      repostCount: parseInt(map['repost_count'] ?? map['repostCount']),
      viewsCount: parseInt(map['views_count'] ?? map['viewsCount']),
      sharesCount: parseInt(map['shares_count'] ?? map['sharesCount']),
      savesCount: parseInt(map['saves_count'] ?? map['savesCount']),
      isLiked: map['is_liked'] ?? map['isLiked'] ?? false,
      isSaved: map['is_saved'] ?? map['isSaved'] ?? false,
      channelId: (map['channel_id'] == 'public' || map['channelId'] == 'public')
          ? 'general'
          : (map['channel_id'] ?? map['channelId'] ?? 'general'),
      pollData: parseMap(map['poll_data'] ?? map['pollData']),
      repostData: parseMap(map['repost_data'] ?? map['repostData']),
      hashtags: parseStringList(map['hashtags']),
      mentions: parseStringList(map['mentions']),
      visibility: map['visibility'] ?? 'everyone',
      status: map['status'] ?? 'active',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      locationName: map['location_name'] ?? map['locationName'] ?? map['location'],
      replyPermission: map['reply_permission'] ?? map['replyPermission'] ?? 'everyone',
      scheduledAt: map['scheduled_at'] != null ? parseTime(map['scheduled_at']) : (map['scheduledAt'] != null ? parseTime(map['scheduledAt']) : null),
      mediaAltText: map['media_alt_text'] ?? map['mediaAltText'],
      linkUrl: map['link_url'] ?? map['linkUrl'],
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
    List<String>? mediaUrls,
    MediaType? mediaType,
    DateTime? timestamp,
    int? likesCount,
    int? commentsCount,
    int? repostCount,
    int? viewsCount,
    int? sharesCount,
    int? savesCount,
    bool? isLiked,
    bool? isSaved,
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
      mediaUrls: mediaUrls ?? this.mediaUrls,
      mediaType: mediaType ?? this.mediaType,
      timestamp: timestamp ?? this.timestamp,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      repostCount: repostCount ?? this.repostCount,
      viewsCount: viewsCount ?? this.viewsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      savesCount: savesCount ?? this.savesCount,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
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
