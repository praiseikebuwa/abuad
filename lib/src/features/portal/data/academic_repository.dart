import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AcademicRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  Future<void> saveGPAResult({
    required String semester,
    required double gpa,
    required List<Map<String, dynamic>> courses,
  }) async {
    if (currentUserId == null) return;

    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('academic_results')
        .add({
          'semester': semester,
          'gpa': gpa,
          'courses': courses,
          'timestamp': FieldValue.serverTimestamp(),
        });
  }

  Stream<List<Map<String, dynamic>>> watchResults() {
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('academic_results')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  Future<void> deleteResult(String resultId) async {
    if (currentUserId == null) return;

    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('academic_results')
        .doc(resultId)
        .delete();
  }
}

final academicRepositoryProvider = Provider<AcademicRepository>((ref) {
  return AcademicRepository();
});

final resultsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(academicRepositoryProvider).watchResults();
});
