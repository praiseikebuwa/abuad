import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';
import '../../../core/utils/profanity_filter.dart';
import '../domain/snap_model.dart';

final snapRepositoryProvider = Provider<SnapRepository>((ref) {
  return SnapRepository();
});

class SnapRepository {
  SnapRepository([dynamic firestore, dynamic storage]);

  Future<void> createSnap(Snap snap) async {
    // 1. Moderate snap text and caption with backend AI
    if (snap.caption != null && snap.caption!.trim().isNotEmpty) {
      final isTextSafe = await ProfanityFilter.isTextSafe(snap.caption!);
      if (!isTextSafe) {
        throw Exception('Snap caption violates community guidelines.');
      }
    }

    // 2. Moderate snap image / video with backend AI Vision
    if (snap.imageUrl.trim().isNotEmpty) {
      final isMediaSafe = await ProfanityFilter.isMediaSafe(snap.imageUrl, mediaType: 'image');
      if (!isMediaSafe) {
        throw Exception('Snap image violates community safety guidelines.');
      }
    }

    final res = await ApiClient.post('/stories', snap.toMap());
    if (res.statusCode != 200 && res.statusCode != 201) {
      try {
        final err = jsonDecode(res.body);
        if (err is Map && err['error'] != null) {
          throw Exception(err['error']);
        }
      } catch (e) {
        if (e is Exception && !e.toString().contains('Failed to create snap')) rethrow;
      }
      throw Exception('Failed to create snap: ${res.body}');
    }
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
    } catch (_) {
      // Fallback to empty list on network or parse failure
    }
    yield [];
  }

  Future<void> markSnapAsViewed(String snapId, [String? uid]) async {}
}
