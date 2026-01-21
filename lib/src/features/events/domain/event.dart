class AppEvent {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  final String location;
  final String organizer;
  final String imageUrl;
  final int attendeesCount;

  AppEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.location,
    required this.organizer,
    required this.imageUrl,
    this.attendeesCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'date': date.millisecondsSinceEpoch,
      'location': location,
      'organizer': organizer,
      'imageUrl': imageUrl,
      'attendeesCount': attendeesCount,
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
      imageUrl: map['imageUrl'] ?? '',
      attendeesCount: map['attendeesCount'] ?? 0,
    );
  }
}
