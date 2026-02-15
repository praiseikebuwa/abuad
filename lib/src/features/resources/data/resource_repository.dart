import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/resource.dart';

final resourceRepositoryProvider = Provider<ResourceRepository>((ref) {
  return ResourceRepository(FirebaseFirestore.instance);
});

class ResourceRepository {
  final FirebaseFirestore _firestore;

  ResourceRepository(this._firestore);

  // Stream all resources, ordered by timestamp
  Stream<List<Resource>> watchResources() {
    return _firestore
        .collection('resources')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Resource.fromMap(doc.data())).toList(),
        );
  }

  // Filter resources by course code or level
  Stream<List<Resource>> watchResourcesByLevel(String level) {
    return _firestore
        .collection('resources')
        .where('level', isEqualTo: level)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Resource.fromMap(doc.data())).toList(),
        );
  }

  // Add a new resource
  Future<void> addResource(Resource resource) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User must be logged in to upload a resource');
    }

    final resourceId = _firestore.collection('resources').doc().id;
    final resourceWithId = Resource(
      id: resourceId,
      title: resource.title,
      url: resource.url,
      courseCode: resource.courseCode,
      level: resource.level,
      timestamp: resource.timestamp,
      uploaderId: user.uid,
    );
    await _firestore
        .collection('resources')
        .doc(resourceId)
        .set(resourceWithId.toMap());
  }
}
