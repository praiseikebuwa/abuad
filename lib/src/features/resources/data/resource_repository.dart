import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/resource.dart';

final resourceRepositoryProvider = Provider<ResourceRepository>((ref) {
  return ResourceRepository(Supabase.instance.client);
});

class ResourceRepository {
  final SupabaseClient _supabase;

  ResourceRepository(this._supabase);

  // Stream all resources, ordered by timestamp
  Stream<List<Resource>> watchResources() {
    return _supabase
        .from('resources')
        .stream(primaryKey: ['id'])
        .order('timestamp', ascending: false)
        .map((data) {
          return data.map((map) {
            return Resource.fromMap(map);
          }).toList();
        });
  }

  // Filter resources by course code or level
  Stream<List<Resource>> watchResourcesByLevel(String level) {
    return _supabase
        .from('resources')
        .stream(primaryKey: ['id'])
        .order('timestamp', ascending: false)
        .map((data) {
          return data
              .map((map) => Resource.fromMap(map))
              .where((res) => res.level == level)
              .toList();
        });
  }

  // Add a new resource
  Future<void> addResource(Resource resource) async {
    await _supabase.from('resources').insert(resource.toMap());
  }
}
