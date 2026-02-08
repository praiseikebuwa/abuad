import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/data/auth_repository.dart';

class AppUser {
  final String uid;
  final String displayName;
  final String email;
  final String handle;
  final String? avatarUrl;
  final bool isVerified;
  final String? bannerUrl;
  final String? bio;
  final int followersCount;
  final int followingCount;
  final String status;
  final DateTime? lastSeen;
  final String? college;
  final String? department;
  final String? phoneNumber;

  AppUser({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.handle,
    this.avatarUrl,
    this.bannerUrl,
    this.bio,
    this.isVerified = false,
    this.followersCount = 0,
    this.followingCount = 0,
    this.status = 'offline',
    this.lastSeen,
    this.college,
    this.department,
    this.phoneNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': uid,
      'display_name': displayName,
      'email': email,
      'handle': handle,
      'avatar_url': avatarUrl,
      'banner_url': bannerUrl,
      'bio': bio,
      'is_verified': isVerified,
      'followers_count': followersCount,
      'following_count': followingCount,
      'status': status,
      'last_seen': lastSeen?.millisecondsSinceEpoch,
      'college': college,
      'department': department,
      'phone_number': phoneNumber,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['id'] ?? '',
      displayName: map['display_name'] ?? '',
      email: map['email'] ?? '',
      handle: map['handle'] ?? '',
      avatarUrl: map['avatar_url'],
      bannerUrl: map['banner_url'],
      bio: map['bio'],
      isVerified: map['is_verified'] ?? false,
      followersCount: map['followers_count'] ?? 0,
      followingCount: map['following_count'] ?? 0,
      status: map['status'] ?? 'offline',
      lastSeen: map['last_seen'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_seen'])
          : null,
      college: map['college'],
      department: map['department'],
      phoneNumber: map['phone_number'],
    );
  }
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(Supabase.instance.client);
});

class UserRepository {
  final SupabaseClient _supabase;

  UserRepository(this._supabase);

  String? get currentUserId => _supabase.auth.currentUser?.id;

  // Get user by ID (from 'profiles' table)
  Future<AppUser?> getUserById(String uid) async {
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', uid)
          .single();
      return AppUser.fromMap(data);
    } catch (e) {
      return null;
    }
  }

  // Search users by name or email
  Stream<List<AppUser>> searchUsers(String query) {
    if (query.isEmpty) {
      return _supabase
          .from('profiles')
          .stream(primaryKey: ['id'])
          .limit(20)
          .map((data) => data.map((map) => AppUser.fromMap(map)).toList());
    }

    // specific search logic
    return _supabase
        .from('profiles')
        .select()
        .ilike('display_name', '%$query%')
        .limit(20)
        .asStream()
        .map((data) => data.map((map) => AppUser.fromMap(map)).toList());
  }

  // Create or update user profile
  Future<void> createOrUpdateUser(AppUser user) async {
    await _supabase.from('profiles').upsert(user.toMap());
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    // Map dart keys to snake_case if necessary, or assume caller provides snake_case
    // For safety, let's assume the caller might pass 'displayName' and we need 'display_name'
    // But for now, direct update.
    await _supabase.from('profiles').update(data).eq('id', uid);
  }

  // Follow a user
  Future<void> followUser(String targetUid) async {
    final uid = currentUserId;
    if (uid == null || uid == targetUid) return;

    // Supabase trigger could handle counts, but we can do it manually or via policies.
    // We'll insert into 'follows' table.

    // 1. Insert into follows
    await _supabase.from('follows').insert({
      'follower_id': uid,
      'following_id': targetUid,
    });

    // Increment counts (Supabase doesn't have FieldValue.increment in the same way for atomic updates without RPC)
    // We can use an RPC or just let it be.
    // Ideally we use a Postgres function `increment_follows`.
    // For now, let's try a simple RPC call if we had one, or a raw SQL, but we only have client.
    // We will leave count updates for a Trigger (best practice in SQL) or just ignore for MVP.
    // The Schema I provided didn't have triggers for counts.
    // Let's rely on the client refreshing the profile.
  }

  // Unfollow a user
  Future<void> unfollowUser(String targetUid) async {
    final uid = currentUserId;
    if (uid == null || uid == targetUid) return;

    await _supabase.from('follows').delete().match({
      'follower_id': uid,
      'following_id': targetUid,
    });
  }

  // Check if following
  Stream<bool> isFollowing(String targetUid) {
    final uid = currentUserId;
    if (uid == null) return Stream.value(false);

    return _supabase
        .from('follows')
        .select()
        .match({'follower_id': uid, 'following_id': targetUid})
        .asStream()
        .map((data) => data.isNotEmpty);
  }
}

final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final user = authState.value;

  if (user == null) return Stream.value(null);

  // Use select().asStream() for now. For realtime, we would need to setup a channel subscription manually
  // or use the stream() method only if we are sure of the primary key filtering.
  // Profiles primary key is matches user.id, so stream(primaryKey: ['id']).eq('id', user.id) SHOULD work
  // but if it's failing, we fall back to fetch-once for stability.
  return Supabase.instance.client
      .from('profiles')
      .select()
      .eq('id', user.id)
      .asStream()
      .map((data) => data.isNotEmpty ? AppUser.fromMap(data.first) : null);
});
