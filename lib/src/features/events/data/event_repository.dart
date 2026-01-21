import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/event.dart';

final eventRepositoryProvider = Provider((ref) => EventRepository());

class EventRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<AppEvent>> watchUpcomingEvents() {
    return _firestore
        .collection('events')
        .where('date', isGreaterThan: DateTime.now().millisecondsSinceEpoch)
        .orderBy('date')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => AppEvent.fromMap(doc.id, doc.data()))
              .toList();
        });
  }

  Future<void> rsvpToEvent(String eventId, String userId) async {
    // Implement RSVP logic (subcollection or array)
    // For now, just increment count for demo
    await _firestore.collection('events').doc(eventId).update({
      'attendeesCount': FieldValue.increment(1),
    });
  }

  // Dummy data generator
  Future<void> generateDummyEvents() async {
    final events = [
      AppEvent(
        id: '1',
        title: 'Engineering Tech Expo',
        description: 'Showcasing the latest innovations from the college.',
        date: DateTime.now().add(const Duration(days: 2)),
        location: 'Engineering Hall',
        organizer: 'College of Engineering',
        imageUrl:
            'https://images.unsplash.com/photo-1581092921461-eab62e97a78,3?auto=format&fit=crop&q=80',
        attendeesCount: 45,
      ),
      AppEvent(
        id: '2',
        title: 'Law Dinner 2026',
        description: 'Annual dinner for Law students and faculty.',
        date: DateTime.now().add(const Duration(days: 5)),
        location: 'Alfa Belgore Hall',
        organizer: 'Law Student Society',
        imageUrl:
            'https://images.unsplash.com/photo-1519671482538-518b5c2eb061?auto=format&fit=crop&q=80',
        attendeesCount: 120,
      ),
      AppEvent(
        id: '3',
        title: 'Campus Marathon',
        description: 'Run for health! 5km around the beautiful campus.',
        date: DateTime.now().add(const Duration(days: 10)),
        location: 'Sports Complex',
        organizer: 'Sports Unit',
        imageUrl:
            'https://images.unsplash.com/photo-1552674605-46945596e949?auto=format&fit=crop&q=80',
        attendeesCount: 80,
      ),
    ];

    final batch = _firestore.batch();
    for (var event in events) {
      final docRef = _firestore.collection('events').doc(event.id);
      final doc = await docRef.get();
      if (!doc.exists) {
        batch.set(docRef, event.toMap());
      }
    }
    await batch.commit();
  }
}
