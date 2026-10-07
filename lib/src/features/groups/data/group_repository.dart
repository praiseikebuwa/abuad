import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';
import '../domain/group.dart';

final groupRepositoryProvider = Provider(
  (ref) => GroupRepository(),
);

class GroupRepository {
  GroupRepository([dynamic _]);

  Stream<List<StudentGroup>> watchGroups() async* {
    try {
      final response = await ApiClient.get('/groups');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          yield (data['data'] as List).map((x) => StudentGroup.fromMap(x)).toList();
          return;
        }
      }
    } catch (e) {}
    yield [];
  }

  Future<void> joinGroup(String groupId, String userId) async {}

  Future<void> createGroup({
    required String name,
    required String description,
    required String category,
    String? imageUrl,
    bool isPrivate = false,
  }) async {
    await ApiClient.post('/events', {
      'title': name,
      'description': description,
      'category': category,
      'imageUrl': imageUrl,
      'isPrivate': isPrivate,
    });
  }

  Future<void> generateDummyGroups() async {}
}
