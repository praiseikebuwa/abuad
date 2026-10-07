class Snap {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  final String imageUrl;
  final String? caption;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<String> viewers;

  Snap({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.imageUrl,
    this.caption,
    required this.createdAt,
    required this.expiresAt,
    this.viewers = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'user_avatar': userAvatar,
      'image_url': imageUrl,
      'caption': caption,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'viewers': viewers,
    };
  }

  factory Snap.fromMap(Map<String, dynamic> map) {
    DateTime parseTime(dynamic raw) {
      if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
      return DateTime.now();
    }

    return Snap(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? map['userId'] ?? '',
      userName: map['user_name'] ?? map['userName'] ?? '',
      userAvatar: map['user_avatar'] ?? map['userAvatar'] ?? '',
      imageUrl: map['image_url'] ?? map['imageUrl'] ?? '',
      caption: map['caption'],
      createdAt: parseTime(map['created_at'] ?? map['createdAt']),
      expiresAt: parseTime(map['expires_at'] ?? map['expiresAt']),
      viewers: List<String>.from(map['viewers'] ?? []),
    );
  }

  bool hasViewed(String uid) => viewers.contains(uid);
}
