enum MediaType { none, image, video }

class Post {
  final String id;
  final String authorId;
  final String authorName;
  final String authorHandle;
  final String content;
  final String mediaUrl;
  final MediaType mediaType;
  final DateTime timestamp;
  final int likesCount;
  final int commentsCount;
  final bool isVerified;

  Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorHandle,
    required this.content,
    this.mediaUrl = '',
    this.mediaType = MediaType.none,
    required this.timestamp,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.isVerified = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorHandle': authorHandle,
      'content': content,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType.name,
      'timestamp': timestamp.toIso8601String(),
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'isVerified': isVerified,
    };
  }

  factory Post.fromMap(String id, Map<String, dynamic> map) {
    return Post(
      id: id,
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? 'Unknown',
      authorHandle: map['authorHandle'] ?? '@unknown',
      content: map['content'] ?? '',
      mediaUrl: map['mediaUrl'] ?? '',
      mediaType: MediaType.values.firstWhere(
        (e) => e.name == (map['mediaType'] ?? 'none'),
        orElse: () => MediaType.none,
      ),
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      likesCount: map['likesCount'] ?? 0,
      commentsCount: map['commentsCount'] ?? 0,
      isVerified: map['isVerified'] ?? false,
    );
  }
}
