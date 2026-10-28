class Resource {
  final String id;
  final String title;
  final String url;
  final String courseCode;
  final String level;
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
      'fileUrl': url,
      'category': courseCode,
      'level': level,
      'created_at': timestamp.toIso8601String(),
      'uploaderId': uploaderId,
    };
  }

  String get fileExtension {
    final clean = url.split('?').first.toLowerCase();
    if (clean.contains('.')) {
      return clean.split('.').last;
    }
    final titleClean = title.split('?').first.toLowerCase();
    if (titleClean.contains('.')) {
      return titleClean.split('.').last;
    }
    return 'pdf';
  }

  String get fileType => fileExtension.toUpperCase();

  factory Resource.fromMap(Map<String, dynamic> map) {
    DateTime parseTime(dynamic raw) {
      if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
      return DateTime.now();
    }

    return Resource(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      url: map['fileUrl'] ?? map['url'] ?? '',
      courseCode: map['category'] ?? map['course_code'] ?? '',
      level: map['level'] ?? '100',
      timestamp: parseTime(map['created_at'] ?? map['timestamp']),
      uploaderId: map['uploaderId'] ?? map['uploader_id'] ?? '',
    );
  }
}
