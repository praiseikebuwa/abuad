import 'package:cloud_firestore/cloud_firestore.dart';

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
      'created_at': Timestamp.fromDate(createdAt),
      'expires_at': Timestamp.fromDate(expiresAt),
      'viewers': viewers,
    };
  }

  factory Snap.fromMap(Map<String, dynamic> map) {
    return Snap(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      userName: map['user_name'] ?? '',
      userAvatar: map['user_avatar'] ?? '',
      imageUrl: map['image_url'] ?? '',
      caption: map['caption'],
      createdAt: (map['created_at'] as Timestamp).toDate(),
      expiresAt: (map['expires_at'] as Timestamp).toDate(),
      viewers: List<String>.from(map['viewers'] ?? []),
    );
  }

  bool hasViewed(String uid) => viewers.contains(uid);
}
