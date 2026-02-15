import 'package:cloud_firestore/cloud_firestore.dart';

class Resource {
  final String id;
  final String title;
  final String url;
  final String courseCode;
  final String level; // e.g., "100", "200"
  final DateTime timestamp;
  final String uploaderId;

  Resource({
    required this.id,
    required this.title,
    required this.url,
    required this.courseCode,
    required this.level,
    required this.timestamp,
    required this.uploaderId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'course_code': courseCode,
      'level': level,
      'timestamp': Timestamp.fromDate(timestamp),
      'uploader_id': uploaderId,
    };
  }

  factory Resource.fromMap(Map<String, dynamic> map) {
    return Resource(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      url: map['url'] ?? '',
      courseCode: map['course_code'] ?? '',
      level: map['level'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      uploaderId: map['uploader_id'] ?? '',
    );
  }
}
