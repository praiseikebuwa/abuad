import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/campus_event.dart';

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository();
});

class EventRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<CampusEvent>> watchUpcomingEvents() {
    return _firestore
        .collection('events')
        .where('date', isGreaterThan: DateTime.now().millisecondsSinceEpoch)
        .orderBy('date')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return CampusEvent.fromMap(doc.id, doc.data());
          }).toList();
        });
  }

  Future<void> addEvent(CampusEvent event) async {
    await _firestore.collection('events').doc(event.id).set(event.toMap());
  }
}
