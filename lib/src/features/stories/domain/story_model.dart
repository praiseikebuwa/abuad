/// Story Model - Represents a 24-hour story similar to Snapchat/Instagram
class Story {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  final String mediaUrl;
  final String mediaType; // 'image' or 'video'
  final String? caption;
  final String? backgroundColor; // Hex color for text-only stories
  final DateTime createdAt;
  final DateTime expiresAt;
  final int viewCount;
  final List<String> viewers; // IDs of users who have viewed (if loaded)
  final bool isViewedByCurrentUser; // Helper for UI state

  Story({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.mediaUrl,
    required this.mediaType,
    this.caption,
    this.backgroundColor,
    required this.createdAt,
    required this.expiresAt,
    required this.viewCount,
    this.viewers = const [],
    this.isViewedByCurrentUser = false,
  });

  /// Check if the story has expired (24 hours passed)
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Check if a specific user has viewed this story
  bool hasViewed(String userId) =>
      viewers.contains(userId) || isViewedByCurrentUser;

  /// Get time ago string (e.g., "2h ago")
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  factory Story.fromMap(Map<String, dynamic> map, {String? currentUserId}) {
    // Handle joins from Supabase: profiles(...)
    final authorProfile = map['profiles'] as Map<String, dynamic>?;

    // Check if current user viewed
    // Supabase can return joined `story_views` filtered by viewer_id
    // If `my_views` exists and is not empty, then viewed.
    bool viewed = false;
    if (map['my_views'] != null && (map['my_views'] as List).isNotEmpty) {
      viewed = true;
    }

    return Story(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      userName: authorProfile?['display_name'] ?? 'Unknown',
      userAvatar: authorProfile?['avatar_url'] ?? '',
      mediaUrl: map['media_url'] ?? '',
      mediaType: map['media_type'] ?? 'image',
      caption: map['caption'],
      backgroundColor: map['background_color'],
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'])
          : DateTime.now(),
      expiresAt: map['expires_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['expires_at'])
          : DateTime.now().add(const Duration(hours: 24)),
      viewCount: map['view_count'] ?? 0,
      viewers: [], // We don't load all viewers list by default for performance
      isViewedByCurrentUser: viewed,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'media_url': mediaUrl,
      'media_type': mediaType,
      'caption': caption,
      'background_color': backgroundColor,
      'view_count': viewCount,
      'created_at': createdAt.millisecondsSinceEpoch,
      'expires_at': expiresAt.millisecondsSinceEpoch,
    };
  }

  /// Create a copy with updated fields
  Story copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userAvatar,
    String? mediaUrl,
    String? mediaType,
    String? caption,
    String? backgroundColor,
    DateTime? createdAt,
    DateTime? expiresAt,
    int? viewCount,
    List<String>? viewers,
    bool? isViewedByCurrentUser,
  }) {
    return Story(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      caption: caption ?? this.caption,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      viewCount: viewCount ?? this.viewCount,
      viewers: viewers ?? this.viewers,
      isViewedByCurrentUser:
          isViewedByCurrentUser ?? this.isViewedByCurrentUser,
    );
  }
}
