import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/group.dart';

final groupRepositoryProvider = Provider((ref) => GroupRepository());

class GroupRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<StudentGroup>> watchGroups() {
    return _firestore
        .collection('groups')
        .orderBy('memberCount', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => StudentGroup.fromMap(doc.id, doc.data()))
              .toList();
        });
  }

  Future<void> joinGroup(String groupId, String userId) async {
    // Implement join logic
    await _firestore.collection('groups').doc(groupId).update({
      'memberCount': FieldValue.increment(1),
    });
  }

  Future<void> generateDummyGroups() async {
    final groups = [
      StudentGroup(
        id: '1',
        name: 'ABUAD Tech Club',
        description:
            'For students interested in coding, robotics, and innovation.',
        category: 'Academic',
        imageUrl:
            'https://images.unsplash.com/photo-1531482615713-2afd69097998?auto=format&fit=crop&q=80',
        memberCount: 250,
      ),
      StudentGroup(
        id: '2',
        name: 'Debate Society',
        description:
            'Sharpen your public speaking and critical thinking skills.',
        category: 'Social',
        imageUrl:
            'https://images.unsplash.com/photo-1524178232363-1fb2b075b655?auto=format&fit=crop&q=80',
        memberCount: 85,
      ),
      StudentGroup(
        id: '3',
        name: 'Campus Fellowship',
        description: 'Weekly meetings for prayer and community.',
        category: 'Religious',
        imageUrl:
            'https://images.unsplash.com/photo-1510936111840-65e151ad71bb?auto=format&fit=crop&q=80',
        memberCount: 400,
      ),
      StudentGroup(
        id: '4',
        name: 'Football Team',
        description: 'Official university football team and supporters.',
        category: 'Sports',
        imageUrl:
            'https://images.unsplash.com/photo-1579952363873-27f3bade9f55?auto=format&fit=crop&q=80',
        memberCount: 150,
      ),
    ];

    final batch = _firestore.batch();
    for (var group in groups) {
      final docRef = _firestore.collection('groups').doc(group.id);
      final doc = await docRef.get();
      if (!doc.exists) {
        batch.set(docRef, group.toMap());
      }
    }
    await batch.commit();
  }
}
