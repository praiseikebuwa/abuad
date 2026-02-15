import 'package:cloud_firestore/cloud_firestore.dart';

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
      'date': Timestamp.fromDate(date),
      'image_url': imageUrl,
      'is_online': isOnline,
    };
  }

  factory CampusEvent.fromMap(Map<String, dynamic> map) {
    return CampusEvent(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      location: map['location'] ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      imageUrl: map['image_url'] ?? '',
      isOnline: map['is_online'] ?? false,
    );
  }
}
