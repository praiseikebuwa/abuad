import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/group.dart';

final groupRepositoryProvider = Provider(
  (ref) => GroupRepository(FirebaseFirestore.instance),
);

class GroupRepository {
  final FirebaseFirestore _firestore;

  GroupRepository(this._firestore);

  Stream<List<StudentGroup>> watchGroups() {
    return _firestore
        .collection('groups')
        .orderBy('member_count', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => StudentGroup.fromMap(doc.data()))
              .toList(),
        );
  }

  Future<void> joinGroup(String groupId, String userId) async {
    final batch = _firestore.batch();

    // 1. Join group_members
    batch.set(
      _firestore
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .doc(userId),
      {'joined_at': FieldValue.serverTimestamp()},
    );

    // 2. Increment member count
    batch.update(_firestore.collection('groups').doc(groupId), {
      'member_count': FieldValue.increment(1),
    });

    await batch.commit();
  }

  Future<void> createGroup({
    required String name,
    required String description,
    required String category,
    String? imageUrl,
    bool isPrivate = false,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Must be logged in to create a group');

    final docRef = _firestore.collection('groups').doc();

    final group = StudentGroup(
      id: docRef.id,
      name: name,
      description: description,
      category: category,
      imageUrl:
          imageUrl ??
          'https://via.placeholder.com/300', // Default or handled by UI
      memberCount: 1,
      isPrivate: isPrivate,
      creatorId: uid,
    );

    final batch = _firestore.batch();

    // 1. Create Group
    batch.set(docRef, group.toMap());

    // 2. Add Creator as Member & Admin
    batch.set(docRef.collection('members').doc(uid), {
      'joined_at': FieldValue.serverTimestamp(),
      'role': 'admin',
    });

    await batch.commit();
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
        creatorId: 'admin',
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
        creatorId: 'admin',
      ),
      StudentGroup(
        id: '3',
        name: 'Campus Fellowship',
        description: 'Weekly meetings for prayer and community.',
        category: 'Religious',
        imageUrl:
            'https://images.unsplash.com/photo-1510936111840-65e151ad71bb?auto=format&fit=crop&q=80',
        memberCount: 400,
        creatorId: 'admin',
      ),
      StudentGroup(
        id: '4',
        name: 'Football Team',
        description: 'Official university football team and supporters.',
        category: 'Sports',
        imageUrl:
            'https://images.unsplash.com/photo-1579952363873-27f3bade9f55?auto=format&fit=crop&q=80',
        memberCount: 150,
        creatorId: 'admin',
      ),
    ];

    for (var group in groups) {
      await _firestore.collection('groups').doc(group.id).set(group.toMap());
    }
  }
}
