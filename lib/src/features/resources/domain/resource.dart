class Resource {
  final String id;
  final String title;
  final String url;
  final String courseCode;
  final String level; // e.g., "100", "200"
  final DateTime timestamp;

  Resource({
    required this.id,
    required this.title,
    required this.url,
    required this.courseCode,
    required this.level,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'url': url,
      'courseCode': courseCode,
      'level': level,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory Resource.fromMap(String id, Map<String, dynamic> map) {
    return Resource(
      id: id,
      title: map['title'] ?? '',
      url: map['url'] ?? '',
      courseCode: map['courseCode'] ?? '',
      level: map['level'] ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'])
          : DateTime.now(),
    );
  }
}
