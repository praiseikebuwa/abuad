import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum LostFoundType { lost, found }

class LostFoundItem {
  final String id;
  final String title;
  final String description;
  final LostFoundType type;
  final String category;
  final String reporterId;
  final String reporterName;
  final String? imageUrl;
  final DateTime createdAt;
  final String status;

  LostFoundItem({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.category,
    required this.reporterId,
    required this.reporterName,
    this.imageUrl,
    required this.createdAt,
    this.status = 'open',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.name,
      'category': category,
      'reporter_id': reporterId,
      'reporter_name': reporterName,
      'image_url': imageUrl,
      'created_at': createdAt.toIso8601String(),
      'status': status,
    };
  }

  factory LostFoundItem.fromMap(Map<String, dynamic> map) {
    DateTime parseTime(dynamic raw) {
      if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
      return DateTime.now();
    }

    return LostFoundItem(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      type: LostFoundType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => LostFoundType.lost,
      ),
      category: map['category'] ?? 'Others',
      reporterId: map['reporter_id'] ?? '',
      reporterName: map['reporter_name'] ?? 'Unknown',
      imageUrl: map['image_url'],
      createdAt: parseTime(map['created_at'] ?? map['createdAt']),
      status: map['status'] ?? 'open',
    );
  }
}

class LostFoundRepository {
  Stream<List<LostFoundItem>> watchItems() async* {
    yield [];
  }

  Future<void> addItem(LostFoundItem item) async {}

  Future<void> updateStatus(String id, String status) async {}
}

final lostFoundRepositoryProvider = Provider<LostFoundRepository>((ref) {
  return LostFoundRepository();
});

final lostFoundStreamProvider = StreamProvider<List<LostFoundItem>>((ref) {
  return ref.watch(lostFoundRepositoryProvider).watchItems();
});
