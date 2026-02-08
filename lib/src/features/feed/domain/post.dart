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
  final bool isLiked; // UI state, not in DB usually, but we might join
  final String channelId;
  final bool isVerified;
  final bool isAnonymous;
  final Map<String, dynamic>? pollData;
  final Map<String, dynamic>? repostData;

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
    this.isLiked = false,
    this.channelId = 'public',
    this.isVerified = false,
    this.isAnonymous = false,
    this.pollData,
    this.repostData,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'author_id': authorId,

      // We might not store author details in 'posts' table if we normalize, but schema had references.
      // Schema: author_id references profiles.
      // We assume we might join profiles to get name/handle, or store duplicates.
      // For now, let's assume we relying on joins or the schema I defined has author_id only.
      // Schema: author_id uuid references public.profiles(id).
      // It DOES NOT store name/handle/avatar in posts table.
      // So we must fetch them via join.
      'content': content,
      // Schema has media_urls text[], so we should probably adapt.
      // But let's stick to single media_url for now if possible or map.
      'media_urls': mediaUrl.isNotEmpty ? [mediaUrl] : [],

      'channel_id': channelId,
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'repost_count': repostCount,
      'poll_data': pollData,
      'repost_data': repostData,
      'created_at': timestamp.millisecondsSinceEpoch,
    };
  }

  factory Post.fromMap(Map<String, dynamic> map) {
    // Handle joins from Supabase: profiles(...)
    final authorProfile = map['profiles'] as Map<String, dynamic>?;

    // Map media_urls (List) to single mediaUrl (String) for compatibility
    String mUrl = '';
    if (map['media_urls'] != null && (map['media_urls'] as List).isNotEmpty) {
      mUrl = (map['media_urls'] as List).first;
    }

    // Determine MediaType (simple logic based on extension or metadata if available)
    // For now defaulting to image if url exists
    MediaType mType = MediaType.none;
    if (mUrl.isNotEmpty) {
      if (mUrl.endsWith('.mp4')) {
        mType = MediaType.video;
      } else if (mUrl.contains('giphy') || mUrl.endsWith('.gif')) {
        mType = MediaType.gif;
      } else {
        mType = MediaType.image;
      }
    }

    return Post(
      id: map['id'] ?? '',
      authorId: map['author_id'] ?? '',
      authorName: authorProfile?['display_name'] ?? 'Anonymous',
      authorHandle: authorProfile?['handle'] ?? '@anon',
      authorAvatarUrl: authorProfile?['avatar_url'],
      isVerified: authorProfile?['is_verified'] ?? false,

      content: map['content'] ?? '',
      mediaUrl: mUrl,
      mediaType: mType,
      timestamp: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'])
          : DateTime.now(),
      likesCount: map['likes_count'] ?? 0,
      commentsCount: map['comments_count'] ?? 0,
      repostCount: map['repost_count'] ?? 0,
      channelId: map['channel_id'] ?? 'public',
      pollData: map['poll_data'],
      repostData: map['repost_data'],
      // isLiked handling usually requires a separate check or join
    );
  }
}
