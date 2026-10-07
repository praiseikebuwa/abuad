import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';
import '../domain/resource.dart';

final resourceRepositoryProvider = Provider<ResourceRepository>((ref) {
  return ResourceRepository();
});

class ResourceRepository {
  ResourceRepository([dynamic _]);

  Stream<List<Resource>> watchResources() async* {
    try {
      final response = await ApiClient.get('/resources');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          yield (data['data'] as List).map((x) => Resource.fromMap(x)).toList();
          return;
        }
      }
    } catch (e) {}
    yield [];
  }

  Stream<List<Resource>> watchResourcesByLevel(String level) async* {
    yield* watchResources();
  }

  Future<void> addResource(Resource resource) async {
    await ApiClient.post('/resources', resource.toMap());
  }
}
