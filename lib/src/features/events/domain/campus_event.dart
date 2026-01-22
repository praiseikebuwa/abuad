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
      'title': title,
      'description': description,
      'location': location,
      'date': date.millisecondsSinceEpoch,
      'imageUrl': imageUrl,
      'isOnline': isOnline,
    };
  }

  factory CampusEvent.fromMap(String id, Map<String, dynamic> map) {
    return CampusEvent(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      location: map['location'] ?? '',
      date: map['date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['date'])
          : DateTime.now(),
      imageUrl: map['imageUrl'] ?? '',
      isOnline: map['isOnline'] ?? false,
    );
  }
}
