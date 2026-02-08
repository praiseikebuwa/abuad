import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/group.dart';

final groupRepositoryProvider = Provider(
  (ref) => GroupRepository(Supabase.instance.client),
);

class GroupRepository {
  final SupabaseClient _supabase;

  GroupRepository(this._supabase);

  Stream<List<StudentGroup>> watchGroups() {
    return _supabase
        .from('groups')
        .stream(primaryKey: ['id'])
        .order('member_count', ascending: false)
        .map((data) {
          return data.map((map) => StudentGroup.fromMap(map)).toList();
        });
  }

  Future<void> joinGroup(String groupId, String userId) async {
    // 1. Join group_members
    await _supabase.from('group_members').insert({
      'group_id': groupId,
      'user_id': userId,
    });

    // 2. Increment member count (should be a trigger or RPC)
    // For now, we'll try a simple update if possible, or ignore if managed by trigger.
    // Ideally: await _supabase.rpc('increment_group_members', params: {'g_id': groupId});
  }

  Future<void> generateDummyGroups() async {
    final groups = [
      StudentGroup(
        id: '1',
        name: 'ABUAD Tech Club',
        description:
            'For students interested in coding, robotics, and innovation.',
        category: 'Academic',
        imageUrl:
            'https://images.unsplash.com/photo-1531482615713-2afd69097998?auto=format&fit=crop&q=80',
        memberCount: 250,
      ),
      StudentGroup(
        id: '2',
        name: 'Debate Society',
        description:
            'Sharpen your public speaking and critical thinking skills.',
        category: 'Social',
        imageUrl:
            'https://images.unsplash.com/photo-1524178232363-1fb2b075b655?auto=format&fit=crop&q=80',
        memberCount: 85,
      ),
      StudentGroup(
        id: '3',
        name: 'Campus Fellowship',
        description: 'Weekly meetings for prayer and community.',
        category: 'Religious',
        imageUrl:
            'https://images.unsplash.com/photo-1510936111840-65e151ad71bb?auto=format&fit=crop&q=80',
        memberCount: 400,
      ),
      StudentGroup(
        id: '4',
        name: 'Football Team',
        description: 'Official university football team and supporters.',
        category: 'Sports',
        imageUrl:
            'https://images.unsplash.com/photo-1579952363873-27f3bade9f55?auto=format&fit=crop&q=80',
        memberCount: 150,
      ),
    ];

    for (var group in groups) {
      await _supabase.from('groups').upsert(group.toMap());
    }
  }
}
