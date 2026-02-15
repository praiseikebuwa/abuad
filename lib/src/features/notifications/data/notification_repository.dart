import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/notification.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(FirebaseFirestore.instance);
});

final userNotificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.watchNotifications();
});

class NotificationRepository {
  final FirebaseFirestore _firestore;

  NotificationRepository(this._firestore);

  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  // Watch notifications for current user
  Stream<List<AppNotification>> watchNotifications() {
    final uid = currentUserId;
    if (uid == null) return Stream.value([]);

    return _firestore
        .collection(
          'notifications',
        ) // Using root collection for notifications (option 1)
        // OR using subcollection users/{uid}/notifications (option 2 - preferred for scalability)
        .where('recipient_id', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AppNotification.fromMap(doc.data()))
              .toList(),
        );
  }

  // Use subcollection approach for potentially better write rules scaling?
  // Let's stick to root collection 'notifications' with recipient_id index for simplicity
  // unless we want strict sharding.
  // Actually, better to query root collection so we have one global place,
  // as long as we index recipient_id.

  // UPDATE: User requested "add all this... update firestore rules"
  // so let's use a root collection 'notifications'
  // where document ID is auto-generated and contains recipient_id field.

  Future<void> sendNotification({
    required String recipientId,
    required String senderId,
    required String senderName,
    String? senderAvatarUrl,
    required NotificationType type,
    required String title,
    required String body,
    String? relatedId,
  }) async {
    final docRef = _firestore.collection('notifications').doc();

    final notification = AppNotification(
      id: docRef.id,
      recipientId: recipientId,
      senderId: senderId,
      senderName: senderName,
      senderAvatarUrl: senderAvatarUrl,
      type: type,
      title: title,
      body: body,
      relatedId: relatedId,
      timestamp: DateTime.now(),
      isRead: false,
    );

    await docRef.set(notification.toMap());
  }

  Future<void> markAsRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'is_read': true,
    });
  }
}
