import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/event.dart';

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository(FirebaseFirestore.instance);
});

class EventRepository {
  final FirebaseFirestore _firestore;

  EventRepository(this._firestore);

  Stream<List<AppEvent>> watchUpcomingEvents() {
    final now = DateTime.now();
    return _firestore
        .collection('events')
        .where('date', isGreaterThan: Timestamp.fromDate(now))
        .orderBy('date', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AppEvent.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> addEvent(AppEvent event) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User must be logged in to create an event');
    }

    final eventId = _firestore.collection('events').doc().id;
    final eventWithId = AppEvent(
      id: eventId,
      title: event.title,
      description: event.description,
      location: event.location,
      date: event.date,
      organizer: event.organizer,
      organizerId: user.uid,
      imageUrl: event.imageUrl,
      attendeesCount: 0,
      isOnline: event.isOnline,
    );
    await _firestore.collection('events').doc(eventId).set(eventWithId.toMap());
  }
}
