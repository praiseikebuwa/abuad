import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';
import '../domain/snap_model.dart';

final snapRepositoryProvider = Provider<SnapRepository>((ref) {
  return SnapRepository();
});

class SnapRepository {
  SnapRepository([dynamic firestore, dynamic storage]);

  Future<void> createSnap(Snap snap) async {
    await ApiClient.post('/stories', snap.toMap());
  }

  Stream<List<Snap>> watchActiveSnaps() async* {
    try {
      final response = await ApiClient.get('/stories');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          yield (data['data'] as List).map((x) => Snap.fromMap(x)).toList();
          return;
        }
      }
    } catch (e) {}
    yield [];
  }

  Future<void> markSnapAsViewed(String snapId, [String? uid]) async {}
}
