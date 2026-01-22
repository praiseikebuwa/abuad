enum MediaType { none, image, video }

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
  final bool isVerified;
  final String channelId;
  final bool isAnonymous;
  final Map<String, dynamic>? pollData;
  final Map<String, dynamic>?
  repostData; // Data of the original post if this is a repost

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
    this.isVerified = false,
    this.channelId = 'general',
    this.isAnonymous = false,
    this.pollData,
    this.repostData,
  });

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorHandle': authorHandle,
      'authorAvatarUrl': authorAvatarUrl,
      'content': content,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType.name,
      'timestamp': timestamp.toIso8601String(),
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'repostCount': repostCount,
      'isVerified': isVerified,
      'channelId': channelId,
      'isAnonymous': isAnonymous,
      'pollData': pollData,
      'repostData': repostData,
    };
  }

  factory Post.fromMap(String id, Map<String, dynamic> map) {
    return Post(
      id: id,
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? 'Unknown',
      authorHandle: map['authorHandle'] ?? '@unknown',
      authorAvatarUrl: map['authorAvatarUrl'],
      content: map['content'] ?? '',
      mediaUrl: map['mediaUrl'] ?? '',
      mediaType: MediaType.values.firstWhere(
        (e) => e.name == (map['mediaType'] ?? 'none'),
        orElse: () => MediaType.none,
      ),
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      likesCount: map['likesCount'] ?? 0,
      commentsCount: map['commentsCount'] ?? 0,
      repostCount: map['repostCount'] ?? 0,
      isVerified: map['isVerified'] ?? false,
      channelId: map['channelId'] ?? 'general',
      isAnonymous: map['isAnonymous'] ?? false,
      pollData: map['pollData'],
      repostData: map['repostData'],
    );
  }
}
