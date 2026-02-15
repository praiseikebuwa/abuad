class AppEvent {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final String location;
  final String organizer;
  final String organizerId;
  final String imageUrl;
  final int attendeesCount;
  final bool isOnline;

  AppEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.location,
    required this.organizer,
    required this.organizerId,
    required this.imageUrl,
    this.attendeesCount = 0,
    this.isOnline = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'date': date.millisecondsSinceEpoch,
      'location': location,
      'organizer': organizer,
      'organizer_id': organizerId,
      'imageUrl': imageUrl,
      'attendeesCount': attendeesCount,
      'is_online': isOnline,
    };
  }

  factory AppEvent.fromMap(String id, Map<String, dynamic> map) {
    return AppEvent(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] ?? 0),
      location: map['location'] ?? '',
      organizer: map['organizer'] ?? '',
      organizerId: map['organizer_id'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      attendeesCount: map['attendeesCount'] ?? 0,
      isOnline: map['is_online'] ?? false,
    );
  }
}
