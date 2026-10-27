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

  Stream<List<Resource>> watchResources({String? level, String? courseCode}) async* {
    try {
      String query = '/resources';
      final params = <String>[];
      if (level != null && level != 'All') params.add('level=$level');
      if (courseCode != null && courseCode != 'All') params.add('courseCode=$courseCode');
      if (params.isNotEmpty) query += '?${params.join('&')}';

      final response = await ApiClient.get(query);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          yield (data['data'] as List).map((x) => Resource.fromMap(x)).toList();
          return;
        }
      }
    } catch (e) {
      // Ignored: fallback to empty list on network or parse error
    }
    yield [];
  }

  Stream<List<Resource>> watchResourcesByLevel(String level) async* {
    yield* watchResources(level: level);
  }

  Future<List<Map<String, dynamic>>> fetchCourses() async {
    try {
      final response = await ApiClient.get('/resources/courses');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (_) {}
    return [];
  }

  Future<void> addResource(Resource resource) async {
    await ApiClient.post('/resources', resource.toMap());
  }
}
