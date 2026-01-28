import 'package:cloud_firestore/cloud_firestore.dart';

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
  final List<String> viewers; // User IDs who have viewed

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
    required this.viewers,
  });

  /// Check if the story has expired (24 hours passed)
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Check if a specific user has viewed this story
  bool hasViewed(String userId) => viewers.contains(userId);

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

  /// Create Story from Firestore document
  factory Story.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Story(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Unknown',
      userAvatar: data['userAvatar'] ?? '',
      mediaUrl: data['mediaUrl'] ?? '',
      mediaType: data['mediaType'] ?? 'image',
      caption: data['caption'],
      backgroundColor: data['backgroundColor'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      viewCount: data['viewCount'] ?? 0,
      viewers: List<String>.from(data['viewers'] ?? []),
    );
  }

  /// Convert Story to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'caption': caption,
      'backgroundColor': backgroundColor,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'viewCount': viewCount,
      'viewers': viewers,
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
    );
  }
}
