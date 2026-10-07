import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';
import '../domain/event.dart';

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository();
});

class EventRepository {
  EventRepository([dynamic _]);

  Stream<List<AppEvent>> watchUpcomingEvents() async* {
    try {
      final response = await ApiClient.get('/events');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          yield (data['data'] as List).map((x) => AppEvent.fromMap(x['id'] ?? '', x)).toList();
          return;
        }
      }
    } catch (e) {}
    yield [];
  }

  Future<void> createEvent(AppEvent event) async {
    await ApiClient.post('/events', event.toMap());
  }
}
