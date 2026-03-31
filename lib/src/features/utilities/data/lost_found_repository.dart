import 'package:cloud_firestore/cloud_firestore.dart';
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
      'created_at': Timestamp.fromDate(createdAt),
      'status': status,
    };
  }

  factory LostFoundItem.fromMap(Map<String, dynamic> map) {
    return LostFoundItem(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      type: LostFoundType.values.byName(map['type'] ?? 'lost'),
      category: map['category'] ?? 'Others',
      reporterId: map['reporter_id'] ?? '',
      reporterName: map['reporter_name'] ?? 'Unknown',
      imageUrl: map['image_url'],
      createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'open',
    );
  }
}

class LostFoundRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<LostFoundItem>> watchItems() {
    return _firestore
        .collection('lost_found')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => LostFoundItem.fromMap(doc.data()))
              .toList(),
        );
  }

  Future<void> addItem(LostFoundItem item) async {
    final docRef = _firestore.collection('lost_found').doc();
    final itemWithId = LostFoundItem(
      id: docRef.id,
      title: item.title,
      description: item.description,
      type: item.type,
      category: item.category,
      reporterId: item.reporterId,
      reporterName: item.reporterName,
      imageUrl: item.imageUrl,
      createdAt: item.createdAt,
    );
    await docRef.set(itemWithId.toMap());
  }

  Future<void> updateStatus(String id, String status) async {
    await _firestore.collection('lost_found').doc(id).update({
      'status': status,
    });
  }
}

final lostFoundRepositoryProvider = Provider<LostFoundRepository>((ref) {
  return LostFoundRepository();
});

final lostFoundStreamProvider = StreamProvider<List<LostFoundItem>>((ref) {
  return ref.watch(lostFoundRepositoryProvider).watchItems();
});
