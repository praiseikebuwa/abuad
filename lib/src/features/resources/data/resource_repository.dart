import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/resource.dart';

final resourceRepositoryProvider = Provider<ResourceRepository>((ref) {
  return ResourceRepository();
});

class ResourceRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream all resources, ordered by timestamp
  Stream<List<Resource>> watchResources() {
    return _firestore
        .collection('resources')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return Resource.fromMap(doc.id, doc.data());
          }).toList();
        });
  }

  // Filter resources by course code or level (simple client-side filter logic usually follows,
  // but here's a query based one if needed)
  Stream<List<Resource>> watchResourcesByLevel(String level) {
    return _firestore
        .collection('resources')
        .where('level', isEqualTo: level)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return Resource.fromMap(doc.id, doc.data());
          }).toList();
        });
  }

  // Add a new resource (Admin only usually, but open for MVP if needed)
  Future<void> addResource(Resource resource) async {
    await _firestore
        .collection('resources')
        .doc(resource.id)
        .set(resource.toMap());
  }
}
