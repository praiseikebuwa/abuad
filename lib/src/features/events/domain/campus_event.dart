class CampusEvent {
  final String id;
  final String title;
  final String description;
  final String location;
  final DateTime date;
  final String imageUrl;
  final bool isOnline;

  CampusEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.date,
    this.imageUrl = '',
    this.isOnline = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'location': location,
      'date': date.toIso8601String(),
      'image_url': imageUrl,
      'is_online': isOnline,
    };
  }

  factory CampusEvent.fromMap(Map<String, dynamic> map) {
    DateTime parseTime(dynamic raw) {
      if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
      return DateTime.now();
    }

    return CampusEvent(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      location: map['location'] ?? '',
      date: parseTime(map['date'] ?? map['createdAt']),
      imageUrl: map['image_url'] ?? map['imageUrl'] ?? '',
      isOnline: map['is_online'] ?? map['isOnline'] ?? false,
    );
  }
}
