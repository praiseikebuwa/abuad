import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';
import '../../../core/utils/url_validator.dart';
import '../../feed/domain/post.dart';
export '../../auth/data/auth_repository.dart' show currentUserProvider, currentUserIdProvider;

class AppUser {
  final String uid;
  final String displayName;
  final String email;
  final String handle;
  final String? avatarUrl;
  final String? bannerUrl;
  final bool isVerified;
  final String verificationType;
  final String? bio;
  final int followersCount;
  final int followingCount;
  final String? department;
  final String? college;
  final String? phoneNumber;
  final String? websiteUrl;
  final String? twitterUrl;
  final String? instagramUrl;
  final String? facebookUrl;
  final String? linkedinUrl;
  final String? whatsappUrl;
  final String? tiktokUrl;
  final String? youtubeUrl;
  final String? snapchatUrl;
  final String? githubUrl;
  final String? twitchUrl;
  final bool isFollowingVisible;
  final int streakCount;
  final DateTime? createdAt;
  final bool isAdmin;
  final bool isBanned;
  final String? status;
  final double? latitude;
  final double? longitude;

  String get username => handle;

  AppUser({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.handle,
    this.avatarUrl,
    this.bannerUrl,
    this.bio,
    this.isVerified = false,
    this.verificationType = 'none',
    this.followersCount = 0,
    this.followingCount = 0,
    this.department,
    this.college,
    this.phoneNumber,
    this.websiteUrl,
    this.twitterUrl,
    this.instagramUrl,
    this.facebookUrl,
    this.linkedinUrl,
    this.whatsappUrl,
    this.tiktokUrl,
    this.youtubeUrl,
    this.snapchatUrl,
    this.githubUrl,
    this.twitchUrl,
    this.isFollowingVisible = true,
    this.streakCount = 0,
    this.createdAt,
    this.isAdmin = false,
    this.isBanned = false,
    this.status = 'online',
    this.latitude,
    this.longitude,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic d) {
      if (d is String) return DateTime.tryParse(d);
      return null;
    }

    return AppUser(
      uid: map['id'] ?? map['uid'] ?? '',
      displayName: map['fullName'] ?? map['displayName'] ?? 'User',
      email: map['email'] ?? '',
      handle: map['username'] ?? map['handle'] ?? 'user',
      avatarUrl: (() {
        final raw = map['avatarUrl'] ?? map['avatar_url'] ?? map['photoUrl'] ?? map['photo_url'] ?? map['profilePicture'];
        final formatted = UrlValidator.formatImageUrl(raw);
        return formatted.isNotEmpty ? formatted : null;
      })(),
      bannerUrl: (() {
        final raw = map['bannerUrl'] ?? map['banner_url'] ?? map['coverUrl'] ?? map['cover_url'];
        final formatted = UrlValidator.formatImageUrl(raw);
        return formatted.isNotEmpty ? formatted : null;
      })(),
      bio: map['bio'],
      isVerified: map['isVerified'] ?? map['is_verified'] ?? false,
      verificationType: map['verificationType'] ?? map['verification_type'] ?? 'none',
      followersCount: map['followersCount'] ?? map['followers_count'] ?? map['_count']?['followers'] ?? 0,
      followingCount: map['followingCount'] ?? map['following_count'] ?? map['_count']?['following'] ?? 0,
      department: map['department'],
      college: map['college'],
      phoneNumber: map['phoneNumber'] ?? map['phone_number'],
      websiteUrl: map['websiteUrl'] ?? map['website_url'],
      twitterUrl: map['twitterUrl'] ?? map['twitter_url'],
      instagramUrl: map['instagramUrl'] ?? map['instagram_url'],
      facebookUrl: map['facebookUrl'] ?? map['facebook_url'],
      linkedinUrl: map['linkedinUrl'] ?? map['linkedin_url'],
      whatsappUrl: map['whatsappUrl'] ?? map['whatsapp_url'],
      tiktokUrl: map['tiktokUrl'] ?? map['tiktok_url'],
      youtubeUrl: map['youtubeUrl'] ?? map['youtube_url'],
      snapchatUrl: map['snapchatUrl'] ?? map['snapchat_url'],
      githubUrl: map['githubUrl'] ?? map['github_url'],
      twitchUrl: map['twitchUrl'] ?? map['twitch_url'],
      isFollowingVisible: map['isFollowingVisible'] ?? true,
      streakCount: map['streakCount'] ?? map['streak_count'] ?? 0,
      createdAt: parseDate(map['createdAt'] ?? map['created_at']),
      isAdmin: map['role'] == 'ADMIN',
      isBanned: map['isBlocked'] ?? false,
      status: map['status'] ?? 'online',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }

  AppUser copyWith({
    String? uid,
    String? displayName,
    String? email,
    String? handle,
    String? avatarUrl,
    String? bannerUrl,
    String? bio,
    bool? isVerified,
    String? verificationType,
    int? followersCount,
    int? followingCount,
    String? department,
    String? college,
    String? phoneNumber,
    String? websiteUrl,
    String? twitterUrl,
    String? instagramUrl,
    String? facebookUrl,
    String? linkedinUrl,
    String? tiktokUrl,
    String? youtubeUrl,
    String? snapchatUrl,
    String? githubUrl,
    String? twitchUrl,
    bool? isFollowingVisible,
    int? streakCount,
    DateTime? createdAt,
    bool? isAdmin,
    bool? isBanned,
    String? status,
    double? latitude,
    double? longitude,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      handle: handle ?? this.handle,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      bio: bio ?? this.bio,
      isVerified: isVerified ?? this.isVerified,
      verificationType: verificationType ?? this.verificationType,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      department: department ?? this.department,
      college: college ?? this.college,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      twitterUrl: twitterUrl ?? this.twitterUrl,
      instagramUrl: instagramUrl ?? this.instagramUrl,
      facebookUrl: facebookUrl ?? this.facebookUrl,
      linkedinUrl: linkedinUrl ?? this.linkedinUrl,
      tiktokUrl: tiktokUrl ?? this.tiktokUrl,
      youtubeUrl: youtubeUrl ?? this.youtubeUrl,
      snapchatUrl: snapchatUrl ?? this.snapchatUrl,
      githubUrl: githubUrl ?? this.githubUrl,
      twitchUrl: twitchUrl ?? this.twitchUrl,
      isFollowingVisible: isFollowingVisible ?? this.isFollowingVisible,
      streakCount: streakCount ?? this.streakCount,
      createdAt: createdAt ?? this.createdAt,
      isAdmin: isAdmin ?? this.isAdmin,
      isBanned: isBanned ?? this.isBanned,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': uid,
      'fullName': displayName,
      'email': email,
      'username': handle,
      'avatarUrl': avatarUrl,
      'bannerUrl': bannerUrl,
      'bio': bio,
      'isVerified': isVerified,
      'verificationType': verificationType,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'department': department,
      'college': college,
      'phoneNumber': phoneNumber,
      'websiteUrl': websiteUrl,
      'twitterUrl': twitterUrl,
      'instagramUrl': instagramUrl,
      'facebookUrl': facebookUrl,
      'linkedinUrl': linkedinUrl,
      'whatsappUrl': whatsappUrl,
      'tiktokUrl': tiktokUrl,
      'youtubeUrl': youtubeUrl,
      'snapchatUrl': snapchatUrl,
      'githubUrl': githubUrl,
      'twitchUrl': twitchUrl,
      'isFollowingVisible': isFollowingVisible,
      'streakCount': streakCount,
      'createdAt': createdAt?.toIso8601String(),
      'role': isAdmin ? 'ADMIN' : 'STUDENT',
      'isBlocked': isBanned,
      'status': status,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class SuggestedUser {
  final AppUser user;
  final String reason;
  final int mutualCount;
  final int score;

  const SuggestedUser({
    required this.user,
    this.reason = 'Suggested for you',
    this.mutualCount = 0,
    this.score = 0,
  });

  factory SuggestedUser.fromMap(Map<String, dynamic> map) {
    return SuggestedUser(
      user: AppUser.fromMap(map),
      reason: map['reason'] ?? 'Suggested for you',
      mutualCount: map['mutualCount'] ?? 0,
      score: map['score'] ?? 0,
    );
  }
}

class PeopleYouMayKnowNotifier extends AsyncNotifier<List<SuggestedUser>> {
  @override
  Future<List<SuggestedUser>> build() async {
    final repo = ref.watch(userRepositoryProvider);
    return repo.getPeopleYouMayKnow();
  }

  void dismissUser(String userId) {
    state = state.whenData(
      (users) => users.where((u) => u.user.uid != userId).toList(),
    );
  }

  void removeUser(String userId) => dismissUser(userId);

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(userRepositoryProvider);
      return repo.getPeopleYouMayKnow();
    });
  }
}

final peopleYouMayKnowProvider =
    AsyncNotifierProvider<PeopleYouMayKnowNotifier, List<SuggestedUser>>(
  PeopleYouMayKnowNotifier.new,
);

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

final userProvider = StreamProvider.family<AppUser?, String>((ref, userId) {
  return ref.watch(userRepositoryProvider).watchUser(userId);
});

final isFollowingProvider = StreamProvider.family<bool, String>((ref, userId) {
  return UserRepository.watchIsFollowing(userId);
});

final isBlockedProvider = FutureProvider.family<bool, String>((ref, userId) async {
  return false;
});

final followingProvider = FutureProvider.family<List<AppUser>, String>((ref, userId) async {
  final repo = ref.watch(userRepositoryProvider);
  return repo.getFollowing(userId);
});

final followersProvider = FutureProvider.family<List<AppUser>, String>((ref, userId) async {
  final repo = ref.watch(userRepositoryProvider);
  return repo.getFollowers(userId);
});

final blockedUsersProvider = FutureProvider.family<List<AppUser>, String>((ref, userId) async {
  return [];
});

final usersLocationsProvider = StreamProvider<List<AppUser>>((ref) async* {
  yield [];
});

class UserRepository {
  UserRepository();

  static final Map<String, bool> _followingMap = {};
  static final StreamController<Map<String, bool>> _followingController =
      StreamController<Map<String, bool>>.broadcast();

  static final Map<String, AppUser> _userCache = {};
  static final StreamController<Map<String, AppUser>> _userController =
      StreamController<Map<String, AppUser>>.broadcast();
  static final Map<String, Future<AppUser?>> _inFlightUserRequests = {};
  static final Map<String, DateTime> _negativeCache = {};

  static Stream<bool> watchIsFollowing(String userId) async* {
    if (userId.isEmpty) {
      yield false;
      return;
    }
    if (!_followingMap.containsKey(userId)) {
      try {
        final response = await ApiClient.get('/users/$userId/is-following');
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true && data['isFollowing'] != null) {
            _followingMap[userId] = data['isFollowing'] == true;
          }
        }
      } catch (e) {
        debugPrint('Error checking isFollowing status: $e');
      }
    }
    yield _followingMap[userId] ?? false;
    await for (final map in _followingController.stream) {
      yield map[userId] ?? false;
    }
  }

  Future<AppUser?> getCurrentUser() async {
    try {
      final response = await ApiClient.get('/users/me');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final user = AppUser.fromMap(data['data']);
          _userCache[user.uid] = user;
          _userCache['me'] = user;
          if (user.handle.isNotEmpty) _userCache[user.handle] = user;
          if (user.username.isNotEmpty) _userCache[user.username] = user;
          return user;
        }
      }
      final response2 = await ApiClient.get('/auth/me');
      if (response2.statusCode == 200) {
        final data = jsonDecode(response2.body);
        if (data['success'] == true && data['data'] != null) {
          final user = AppUser.fromMap(data['data']);
          _userCache[user.uid] = user;
          _userCache['me'] = user;
          if (user.handle.isNotEmpty) _userCache[user.handle] = user;
          if (user.username.isNotEmpty) _userCache[user.username] = user;
          return user;
        }
      }
    } catch (e) {
      debugPrint('Error fetching current user profile: $e');
    }
    return null;
  }

  Future<AppUser?> getUserById(String uid, {bool forceRefresh = false}) async {
    if (uid == 'me' || uid.isEmpty) {
      return getCurrentUser();
    }
    if (uid == 'edit') {
      return null;
    }
    // Return cached user immediately if available and not forcing refresh
    if (!forceRefresh && _userCache.containsKey(uid) && _userCache[uid] != null) {
      return _userCache[uid];
    }
    // Check negative cache (not found in last 30s) to prevent spamming
    final lastFailed = _negativeCache[uid];
    if (!forceRefresh && lastFailed != null && DateTime.now().difference(lastFailed).inSeconds < 15) {
      return _userCache[uid];
    }
    // Deduplicate in-flight requests so 20 widgets don't send 20 requests
    if (_inFlightUserRequests.containsKey(uid)) {
      return _inFlightUserRequests[uid];
    }

    final future = _fetchUserByIdInternal(uid);
    _inFlightUserRequests[uid] = future;
    try {
      final result = await future;
      return result;
    } finally {
      _inFlightUserRequests.remove(uid);
    }
  }

  Future<AppUser?> _fetchUserByIdInternal(String uid) async {
    try {
      final response = await ApiClient.get('/users/profile/$uid');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final user = AppUser.fromMap(data['data']);
          _userCache[uid] = user;
          _userCache[user.uid] = user;
          if (user.handle.isNotEmpty) _userCache[user.handle] = user;
          if (user.username.isNotEmpty) _userCache[user.username] = user;
          _negativeCache.remove(uid);
          _negativeCache.remove(user.uid);
          if (data['data']['isFollowing'] != null) {
            _followingMap[uid] = data['data']['isFollowing'] == true;
            _followingMap[user.uid] = data['data']['isFollowing'] == true;
            _followingController.add(Map<String, bool>.from(_followingMap));
          }
          _userController.add(Map<String, AppUser>.from(_userCache));
          return user;
        }
      }
      final response2 = await ApiClient.get('/users/$uid');
      if (response2.statusCode == 200) {
        final data = jsonDecode(response2.body);
        if (data['success'] == true && data['data'] != null) {
          final user = AppUser.fromMap(data['data']);
          _userCache[uid] = user;
          _userCache[user.uid] = user;
          if (user.handle.isNotEmpty) _userCache[user.handle] = user;
          if (user.username.isNotEmpty) _userCache[user.username] = user;
          _negativeCache.remove(uid);
          _negativeCache.remove(user.uid);
          _userController.add(Map<String, AppUser>.from(_userCache));
          return user;
        }
      }
      _negativeCache[uid] = DateTime.now();
    } catch (e) {
      debugPrint('Error fetching user by id: $e');
      _negativeCache[uid] = DateTime.now();
    }
    return _userCache[uid];
  }

  Future<AppUser?> getUser(String uid) => getUserById(uid);

  Future<AppUser?> getUserByHandle(String handle) async {
    final clean = handle.toLowerCase().replaceAll('@', '').trim();
    if (clean == 'ai' || clean == 'abuad_ai' || clean == 'ai_bot') {
      return getUserById('abuad_ai');
    }
    final users = await searchUsers(clean);
    if (users.isNotEmpty) {
      final exactMatch = users.firstWhere(
        (u) => u.handle.toLowerCase() == clean,
        orElse: () => users.first,
      );
      return exactMatch;
    }
    return null;
  }

  Stream<AppUser?> watchUser(String uid) async* {
    if (_userCache.containsKey(uid) && _userCache[uid] != null) {
      yield _userCache[uid];
    } else {
      final user = await getUserById(uid);
      yield _userCache[uid] ?? user;
    }

    await for (final map in _userController.stream) {
      if (map.containsKey(uid)) {
        yield map[uid];
      }
    }
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    final res = await ApiClient.post('/users/profile', data);
    Map<String, dynamic>? updatedUserMap;
    if (res.statusCode == 200) {
      final json = jsonDecode(res.body);
      if (json['success'] == true && json['data'] != null) {
        updatedUserMap = json['data'];
      }
    } else {
      final res2 = await ApiClient.put('/users/me', data);
      if (res2.statusCode == 200) {
        final json2 = jsonDecode(res2.body);
        if (json2['success'] == true && json2['data'] != null) {
          updatedUserMap = json2['data'];
        }
      }
    }

    if (updatedUserMap != null) {
      final updatedUser = AppUser.fromMap(updatedUserMap);
      _userCache[uid] = updatedUser;
      _userController.add(Map<String, AppUser>.from(_userCache));
    } else {
      await getUserById(uid);
    }
  }

  Future<void> createOrUpdateUser(String uid, Map<String, dynamic> data) async {
    final res = await ApiClient.post('/users/profile', data);
    if (res.statusCode != 200) {
      await ApiClient.put('/users/me', data);
    }
  }

  Future<String> generateHandle(String name) async {
    final base = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return '${base.isEmpty ? 'user' : base}${DateTime.now().millisecondsSinceEpoch % 10000}';
  }

  Future<List<AppUser>> searchUsers(String query) async {
    try {
      final response = await ApiClient.get('/users/search?q=$query');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          return (data['data'] as List).map((x) => AppUser.fromMap(x)).toList();
        }
      }
    } catch (e) {
      debugPrint('Error searching users: $e');
    }
    return [];
  }

  Future<List<AppUser>> getFollowers(String userId) async {
    if (userId.isEmpty) return [];
    final targetId = userId == 'me' ? 'me' : userId;
    try {
      final response = await ApiClient.get('/users/$targetId/followers');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          return (data['data'] as List).map((x) => AppUser.fromMap(x)).toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching followers: $e');
    }
    return [];
  }

  Future<List<AppUser>> getFollowing(String userId) async {
    final targetId = (userId.isEmpty || userId == 'me') ? 'me' : userId;
    try {
      final response = await ApiClient.get('/users/$targetId/following');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          return (data['data'] as List).map((x) => AppUser.fromMap(x)).toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching following: $e');
    }
    return [];
  }

  Future<void> followUser(String targetUserId) async {
    if (targetUserId.isEmpty) return;

    _followingMap[targetUserId] = true;
    _followingController.add(Map<String, bool>.from(_followingMap));

    if (_userCache.containsKey(targetUserId)) {
      final u = _userCache[targetUserId]!;
      _userCache[targetUserId] = u.copyWith(
        followersCount: u.followersCount + 1,
      );
      _userController.add(Map<String, AppUser>.from(_userCache));
    }

    try {
      final res = await ApiClient.post('/users/$targetUserId/follow', {});
      if (res.statusCode != 200 && res.statusCode != 201) {
        debugPrint('Follow endpoint status: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('Error following user: $e');
    }
  }

  Future<void> unfollowUser(String targetUserId) async {
    if (targetUserId.isEmpty) return;

    _followingMap[targetUserId] = false;
    _followingController.add(Map<String, bool>.from(_followingMap));

    if (_userCache.containsKey(targetUserId)) {
      final u = _userCache[targetUserId]!;
      _userCache[targetUserId] = u.copyWith(
        followersCount: (u.followersCount - 1).clamp(0, 999999),
      );
      _userController.add(Map<String, AppUser>.from(_userCache));
    }

    try {
      final res = await ApiClient.delete('/users/$targetUserId/follow');
      if (res.statusCode != 200 && res.statusCode != 204) {
        debugPrint('Unfollow endpoint status: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('Error unfollowing user: $e');
    }
  }

  Future<void> blockUser(String targetUserId) async {}
  Future<void> unblockUser(String targetUserId) async {}

  Future<List<SuggestedUser>> getPeopleYouMayKnow() async {
    try {
      final response = await ApiClient.get('/users/people-you-may-know');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          final list = (data['data'] as List)
              .map((x) => SuggestedUser.fromMap(x))
              .toList();
          for (final su in list) {
            _userCache[su.user.uid] = su.user;
          }
          return list;
        }
      }
    } catch (e) {
      debugPrint('Error fetching people you may know: $e');
    }
    return [];
  }
  Future<void> togglePostSave(String postId) async {
    await ApiClient.post('/posts/$postId/save', {});
  }
  Future<void> muteUser(String targetUserId) async {}
  Future<void> updateUserLocation(double lat, double lng) async {}
  Stream<List<AppUser>> watchPopularUsers() async* {
    try {
      final suggestions = await getPeopleYouMayKnow();
      if (suggestions.isNotEmpty) {
        yield suggestions.map((s) => s.user).toList();
        return;
      }
      final response = await ApiClient.get('/users');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          final users = (data['data'] as List)
              .map((x) => AppUser.fromMap(x))
              .toList();
          for (final u in users) {
            _userCache[u.uid] = u;
          }
          yield users;
          return;
        }
      }
    } catch (e) {
      debugPrint('Error watching popular users: $e');
    }
    if (_userCache.isNotEmpty) {
      yield _userCache.values.toList();
    } else {
      yield [];
    }
  }

  Stream<List<Post>> watchUserPosts(String userId) async* {
    try {
      final response = await ApiClient.get('/posts/user/$userId');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          final posts = (data['data'] as List).map((x) => Post.fromMap(x)).toList();
          yield posts;
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching user posts: $e');
    }
    yield [];
  }
}
