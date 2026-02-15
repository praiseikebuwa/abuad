import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'dart:math';
import '../../auth/data/auth_repository.dart';

class AppUser {
  final String uid;
  final String displayName;
  final String email;
  final String handle;
  final String? avatarUrl;
  final bool isVerified;
  final String verificationType; // none, blue, gold
  final String? bannerUrl;
  final String? bio;
  final int followersCount;
  final int followingCount;
  final String status;
  final DateTime? lastSeen;
  final String? college;
  final String? department;
  final String? phoneNumber;
  final int streakCount;
  final DateTime? lastSnapAt;
  final double? latitude;
  final double? longitude;
  final String? websiteUrl;
  final String? facebookUrl;
  final String? twitterUrl;
  final String? instagramUrl;
  final String? linkedinUrl;
  final String? tiktokUrl;
  final String? youtubeUrl;
  final String? snapchatUrl;
  final String? githubUrl;
  final String? twitchUrl;

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
    this.status = 'offline',
    this.lastSeen,
    this.college,
    this.department,
    this.phoneNumber,
    this.streakCount = 0,
    this.lastSnapAt,
    this.latitude,
    this.longitude,
    this.websiteUrl,
    this.facebookUrl,
    this.twitterUrl,
    this.instagramUrl,
    this.linkedinUrl,
    this.tiktokUrl,
    this.youtubeUrl,
    this.snapchatUrl,
    this.githubUrl,
    this.twitchUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'display_name': displayName,
      'email': email,
      'handle': handle,
      'avatar_url': avatarUrl,
      'banner_url': bannerUrl,
      'bio': bio,
      'is_verified': isVerified,
      'verification_type': verificationType,
      'followers_count': followersCount,
      'following_count': followingCount,
      'status': status,
      'last_seen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
      'college': college,
      'department': department,
      'phone_number': phoneNumber,
      'streak_count': streakCount,
      'last_snap_at': lastSnapAt != null
          ? Timestamp.fromDate(lastSnapAt!)
          : null,
      'latitude': latitude,
      'longitude': longitude,
      'website_url': websiteUrl,
      'facebook_url': facebookUrl,
      'twitter_url': twitterUrl,
      'instagram_url': instagramUrl,
      'linkedin_url': linkedinUrl,
      'tiktok_url': tiktokUrl,
      'youtube_url': youtubeUrl,
      'snapchat_url': snapchatUrl,
      'github_url': githubUrl,
      'twitch_url': twitchUrl,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      displayName: map['display_name'] ?? '',
      email: map['email'] ?? '',
      handle: map['handle'] ?? '',
      avatarUrl: map['avatar_url'],
      bannerUrl: map['banner_url'],
      bio: map['bio'],
      isVerified: map['is_verified'] ?? map['isVerified'] ?? false,
      verificationType:
          map['verification_type'] ??
          map['verificationType'] ??
          ((map['is_verified'] == true || map['isVerified'] == true)
              ? 'blue'
              : 'none'),
      followersCount: map['followers_count'] ?? 0,
      followingCount: map['following_count'] ?? 0,
      status: map['status'] ?? 'offline',
      lastSeen: (map['last_seen'] as Timestamp?)?.toDate(),
      college: map['college'],
      department: map['department'],
      phoneNumber: map['phone_number'],
      streakCount: map['streak_count'] ?? 0,
      lastSnapAt: (map['last_snap_at'] as Timestamp?)?.toDate(),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      websiteUrl: map['website_url'],
      facebookUrl: map['facebook_url'],
      twitterUrl: map['twitter_url'],
      instagramUrl: map['instagram_url'],
      linkedinUrl: map['linkedin_url'],
      tiktokUrl: map['tiktok_url'],
      youtubeUrl: map['youtube_url'],
      snapchatUrl: map['snapchat_url'],
      githubUrl: map['github_url'],
      twitchUrl: map['twitch_url'],
    );
  }
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(FirebaseFirestore.instance);
});

class UserRepository {
  final FirebaseFirestore _firestore;

  UserRepository(this._firestore);

  String? get currentUserId => auth.FirebaseAuth.instance.currentUser?.uid;

  // Get user by ID (from 'users' collection)
  Future<AppUser?> getUserById(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      data['uid'] = doc.id;
      return AppUser.fromMap(data);
    } catch (e) {
      return null;
    }
  }

  // Watch user by ID
  Stream<AppUser?> watchUser(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data()!;
      data['uid'] = doc.id;
      return AppUser.fromMap(data);
    });
  }

  // Get user by Handle
  Future<AppUser?> getUserByHandle(String handle) async {
    try {
      // Remove @ if present
      final cleanHandle = handle.startsWith('@') ? handle.substring(1) : handle;

      final query = await _firestore
          .collection('users')
          .where('handle', isEqualTo: cleanHandle)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;
      final doc = query.docs.first;
      final data = doc.data();
      data['uid'] = doc.id;
      return AppUser.fromMap(data);
    } catch (e) {
      return null;
    }
  }

  // Generate unique handle
  Future<String> generateHandle(String displayName) async {
    // Basic sanitization
    String baseHandle = displayName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .replaceAll(' ', '_');

    if (baseHandle.isEmpty) baseHandle = 'user';

    // Use HandleService to ensure uniqueness with randomuffix if needed
    // We import HandleService lazily or use a static/mixin approach,
    // but here we can just implement the logic directly or call the service if we inject it.
    // Since I created the service file, let's use the logic directly here
    // to avoid injection complexity if we don't want to change the constructor too much.
    // Use the logic from HandleService:

    // 1. Check if base handle is available
    if (await _isHandleAvailable(baseHandle)) {
      return baseHandle;
    }

    // 2. If taken, append random suffixes
    final random = Random();
    while (true) {
      final suffix = (1000 + random.nextInt(9000)).toString();
      final candidateHandle = '$baseHandle$suffix';
      if (await _isHandleAvailable(candidateHandle)) {
        return candidateHandle;
      }
    }
  }

  Future<bool> _isHandleAvailable(String handle) async {
    final snapshot = await _firestore
        .collection('users')
        .where('handle', isEqualTo: handle)
        .limit(1)
        .get();
    return snapshot.docs.isEmpty;
  }

  // Search users by name
  Stream<List<AppUser>> searchUsers(String query) {
    if (query.isEmpty) {
      return _firestore
          .collection('users')
          .limit(20)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['uid'] = doc.id;
              return AppUser.fromMap(data);
            }).toList(),
          );
    }

    return _firestore
        .collection('users')
        .where('display_name', isGreaterThanOrEqualTo: query)
        .where('display_name', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(20)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            data['uid'] = doc.id;
            return AppUser.fromMap(data);
          }).toList(),
        );
  }

  // Create or update user profile
  Future<void> createOrUpdateUser(AppUser user) async {
    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(user.toMap(), SetOptions(merge: true));
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }

  // Follow a user
  Future<void> followUser(String targetUid) async {
    final uid = currentUserId;
    if (uid == null || uid == targetUid) return;

    final batch = _firestore.batch();

    // 1. Add to followers sub-collection
    batch.set(
      _firestore
          .collection('users')
          .doc(targetUid)
          .collection('followers')
          .doc(uid),
      {'uid': uid, 'timestamp': FieldValue.serverTimestamp()},
    );

    // 2. Add to following sub-collection
    batch.set(
      _firestore
          .collection('users')
          .doc(uid)
          .collection('following')
          .doc(targetUid),
      {'uid': targetUid, 'timestamp': FieldValue.serverTimestamp()},
    );

    // 3. Increment counts
    batch.update(_firestore.collection('users').doc(targetUid), {
      'followers_count': FieldValue.increment(1),
    });
    batch.update(_firestore.collection('users').doc(uid), {
      'following_count': FieldValue.increment(1),
    });

    await batch.commit();
  }

  // Unfollow a user
  Future<void> unfollowUser(String targetUid) async {
    final uid = currentUserId;
    if (uid == null || uid == targetUid) return;

    final batch = _firestore.batch();

    batch.delete(
      _firestore
          .collection('users')
          .doc(targetUid)
          .collection('followers')
          .doc(uid),
    );
    batch.delete(
      _firestore
          .collection('users')
          .doc(uid)
          .collection('following')
          .doc(targetUid),
    );

    batch.update(_firestore.collection('users').doc(targetUid), {
      'followers_count': FieldValue.increment(-1),
    });
    batch.update(_firestore.collection('users').doc(uid), {
      'following_count': FieldValue.increment(-1),
    });

    await batch.commit();
  }

  // Check if following
  Stream<bool> isFollowing(String targetUid) {
    final uid = currentUserId;
    if (uid == null) return Stream.value(false);

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('following')
        .doc(targetUid)
        .snapshots()
        .map((doc) => doc.exists);
  }

  // Check if target user follows current user
  Stream<bool> isFollowedBy(String targetUid) {
    final uid = currentUserId;
    if (uid == null) return Stream.value(false);

    return _firestore
        .collection('users')
        .doc(targetUid)
        .collection('following')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists);
  }

  // Update real-time location
  Future<void> updateUserLocation(double lat, double lng) async {
    final uid = currentUserId;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).update({
      'latitude': lat,
      'longitude': lng,
      'last_seen': FieldValue.serverTimestamp(),
    });
  }

  // Watch all active users' locations (limited to last hour for performance/privacy)
  Stream<List<AppUser>> watchUsersLocations() {
    final hourAgo = DateTime.now().subtract(const Duration(hours: 1));
    return _firestore
        .collection('users')
        .where('last_seen', isGreaterThan: Timestamp.fromDate(hourAgo))
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['uid'] = doc.id;
            return AppUser.fromMap(data);
          }).toList();
        });
  }
}

final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final user = authState.value;

  if (user == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) {
        if (!doc.exists) return null;
        final data = doc.data()!;
        data['uid'] = doc.id;
        return AppUser.fromMap(data);
      });
});

final userProvider = StreamProvider.family<AppUser?, String>((ref, uid) {
  return ref.watch(userRepositoryProvider).watchUser(uid);
});

final isFollowingProvider = StreamProvider.family<bool, String>((
  ref,
  targetUid,
) {
  return ref.watch(userRepositoryProvider).isFollowing(targetUid);
});

final isFollowedByProvider = StreamProvider.family<bool, String>((
  ref,
  targetUid,
) {
  return ref.watch(userRepositoryProvider).isFollowedBy(targetUid);
});

final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateChangesProvider).value?.uid;
});

final usersLocationsProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.watch(userRepositoryProvider).watchUsersLocations();
});
