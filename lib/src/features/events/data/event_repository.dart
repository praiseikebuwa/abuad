import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/campus_event.dart';

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository(Supabase.instance.client);
});

class EventRepository {
  final SupabaseClient _supabase;

  EventRepository(this._supabase);

  Stream<List<CampusEvent>> watchUpcomingEvents() {
    return _supabase
        .from('events')
        .stream(primaryKey: ['id'])
        .order('date', ascending: true)
        .map((data) {
          final now = DateTime.now().millisecondsSinceEpoch;
          return data
              .map((map) => CampusEvent.fromMap(map))
              .where((event) => event.date.millisecondsSinceEpoch > now)
              .toList();
        });
  }

  Future<void> addEvent(CampusEvent event) async {
    await _supabase.from('events').insert(event.toMap());
  }
}
