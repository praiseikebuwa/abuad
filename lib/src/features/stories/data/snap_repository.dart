import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:image_picker/image_picker.dart';
import '../../../core/services/firebase_storage_service.dart';
import '../../../core/services/notification_service.dart';
import '../../notifications/domain/notification.dart';
import '../domain/snap_model.dart';

final snapRepositoryProvider = Provider<SnapRepository>((ref) {
  return SnapRepository(FirebaseFirestore.instance, FirebaseStorageService());
});

class SnapRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorageService _storage;

  SnapRepository(this._firestore, this._storage);

  String? get currentUserId => auth.FirebaseAuth.instance.currentUser?.uid;

  Future<void> postSnap({
    required XFile imageFile,
    String? caption,
    required String userName,
    required String userAvatar,
  }) async {
    final uid = currentUserId;
    if (uid == null) return;

    final url = await _storage.uploadImage(imageFile, path: 'snaps/$uid/');

    final id = _firestore.collection('snaps').doc().id;
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(hours: 24));

    final snap = Snap(
      id: id,
      userId: uid,
      userName: userName,
      userAvatar: userAvatar,
      imageUrl: url,
      caption: caption,
      createdAt: now,
      expiresAt: expiresAt,
    );

    await _firestore.collection('snaps').doc(id).set(snap.toMap());

    // Update Streak logic
    await _updateStreak(uid);

    // Notify Followers
    try {
      final followersSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('followers')
          .get();

      for (final doc in followersSnapshot.docs) {
        final followerId = doc.id;
        await NotificationService().sendInAppNotification(
          recipientId: followerId,
          title: 'New Story',
          body: '$userName posted a new story!',
          type: NotificationType.storyUpdate,
          senderId: uid,
          senderName: userName,
          senderAvatarUrl: userAvatar,
          data: {'id': uid, 'type': 'story'},
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error notifying followers of new story: $e');
    }
  }

  Stream<List<Snap>> watchActiveSnaps() {
    final now = DateTime.now();
    return _firestore
        .collection('snaps')
        .where('expires_at', isGreaterThan: Timestamp.fromDate(now))
        .orderBy('expires_at')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => Snap(
                  id: doc['id'],
                  userId: doc['user_id'],
                  userName: doc['user_name'],
                  userAvatar: doc['user_avatar'],
                  imageUrl: doc['image_url'],
                  caption: doc['caption'], // can be null
                  createdAt: (doc['created_at'] as Timestamp).toDate(),
                  expiresAt: (doc['expires_at'] as Timestamp).toDate(),
                  viewers: List<String>.from(doc['viewers'] ?? []),
                ),
              )
              .toList(),
        );
  }

  Future<void> markSnapAsViewed(String snapId) async {
    final uid = currentUserId;
    if (uid == null) return;

    await _firestore.collection('snaps').doc(snapId).update({
      'viewers': FieldValue.arrayUnion([uid]),
    });
  }

  Future<void> _updateStreak(String userId) async {
    final userRef = _firestore.collection('users').doc(userId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final lastSnapTime = (data['last_snap_at'] as Timestamp?)?.toDate();
      int currentStreak = data['streak_count'] ?? 0;
      final now = DateTime.now();

      if (lastSnapTime == null) {
        currentStreak = 1;
      } else {
        final lastDate = DateTime(
          lastSnapTime.year,
          lastSnapTime.month,
          lastSnapTime.day,
        );
        final today = DateTime(now.year, now.month, now.day);
        final diff = today.difference(lastDate).inDays;

        if (diff == 1) {
          currentStreak += 1;
        } else if (diff > 1) {
          currentStreak = 1; // Reset if missed more than a day
        } else if (diff == 0) {
          // Already snapped today, no streak change
        }
      }

      transaction.update(userRef, {
        'streak_count': currentStreak,
        'last_snap_at': Timestamp.fromDate(now),
      });
    });
  }
}

final activeSnapsProvider = StreamProvider<List<Snap>>((ref) {
  return ref.watch(snapRepositoryProvider).watchActiveSnaps();
});

final allSnapsGroupedProvider = StreamProvider<Map<String, List<Snap>>>((ref) {
  final snapsAsync = ref.watch(activeSnapsProvider);
  return snapsAsync.when(
    data: (snaps) {
      final groups = <String, List<Snap>>{};
      for (final snap in snaps) {
        if (!groups.containsKey(snap.userId)) {
          groups[snap.userId] = [];
        }
        groups[snap.userId]!.add(snap);
      }
      return Stream.value(groups);
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});
