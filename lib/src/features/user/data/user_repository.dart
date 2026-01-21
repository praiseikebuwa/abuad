import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppUser {
  final String uid;
  final String displayName;
  final String email;
  final String handle;
  final String? avatarUrl;
  final bool isVerified;

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
  });

  final String? bannerUrl;
  final String? bio;
  final int followersCount;
  final int followingCount;
  final String status;
  final DateTime? lastSeen;
  final String? college;
  final String? department;
  final String? phoneNumber;

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'email': email,
      'handle': handle,
      'avatarUrl': avatarUrl,
      'bannerUrl': bannerUrl,
      'bio': bio,
      'isVerified': isVerified,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'status': status,
      'lastSeen': lastSeen?.millisecondsSinceEpoch,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'college': college,
      'department': department,
      'phoneNumber': phoneNumber,
    };
  }

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    return AppUser(
      uid: uid,
      displayName: map['displayName'] ?? '',
      email: map['email'] ?? '',
      handle: map['handle'] ?? '',
      avatarUrl: map['avatarUrl'],
      bannerUrl: map['bannerUrl'],
      bio: map['bio'],
      isVerified: map['isVerified'] ?? false,
      followersCount: map['followersCount'] ?? 0,
      followingCount: map['followingCount'] ?? 0,
      status: map['status'] ?? 'offline',
      lastSeen: map['lastSeen'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastSeen'])
          : null,
      college: map['college'],
      department: map['department'],
      phoneNumber: map['phoneNumber'],
    );
  }
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(
    FirebaseFirestore.instance,
    ref.read(firebaseAuthProvider),
  );
});

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

class UserRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  UserRepository(this._firestore, this._auth);

  String? get currentUserId => _auth.currentUser?.uid;

  // Get user by ID
  Future<AppUser?> getUserById(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromMap(doc.id, doc.data()!);
  }

  // Search users by name or email
  Stream<List<AppUser>> searchUsers(String query) {
    if (query.isEmpty) {
      return _firestore.collection('users').limit(20).snapshots().map((
        snapshot,
      ) {
        return snapshot.docs.map((doc) {
          return AppUser.fromMap(doc.id, doc.data());
        }).toList();
      });
    }

    // Simple search - in production, use Algolia or similar
    return _firestore
        .collection('users')
        .where('displayName', isGreaterThanOrEqualTo: query)
        .where('displayName', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(20)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return AppUser.fromMap(doc.id, doc.data());
          }).toList();
        });
  }

  // Create or update user profile
  Future<void> createOrUpdateUser(AppUser user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toMap());
  }

  // Get all users (for testing)
  Stream<List<AppUser>> getAllUsers() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return AppUser.fromMap(doc.id, doc.data());
      }).toList();
    });
  }

  // Follow a user
  Future<void> followUser(String targetUid) async {
    final uid = currentUserId;
    if (uid == null || uid == targetUid) return;

    final batch = _firestore.batch();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Add to my following
    final followingRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('following')
        .doc(targetUid);
    batch.set(followingRef, {'timestamp': timestamp});

    // Add to their followers
    final followersRef = _firestore
        .collection('users')
        .doc(targetUid)
        .collection('followers')
        .doc(uid);
    batch.set(followersRef, {'timestamp': timestamp});

    // Increment my following count
    final myRef = _firestore.collection('users').doc(uid);
    batch.update(myRef, {'followingCount': FieldValue.increment(1)});

    // Increment their followers count
    final targetRef = _firestore.collection('users').doc(targetUid);
    batch.update(targetRef, {'followersCount': FieldValue.increment(1)});

    await batch.commit();
  }

  // Unfollow a user
  Future<void> unfollowUser(String targetUid) async {
    final uid = currentUserId;
    if (uid == null || uid == targetUid) return;

    final batch = _firestore.batch();

    // Remove from my following
    final followingRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('following')
        .doc(targetUid);
    batch.delete(followingRef);

    // Remove from their followers
    final followersRef = _firestore
        .collection('users')
        .doc(targetUid)
        .collection('followers')
        .doc(uid);
    batch.delete(followersRef);

    // Decrement my following count
    final myRef = _firestore.collection('users').doc(uid);
    batch.update(myRef, {'followingCount': FieldValue.increment(-1)});

    // Decrement their followers count
    final targetRef = _firestore.collection('users').doc(targetUid);
    batch.update(targetRef, {'followersCount': FieldValue.increment(-1)});

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

  // Get users I follow (IDs)
  Future<List<String>> getFollowingIds() async {
    final uid = currentUserId;
    if (uid == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('following')
        .get();

    return snapshot.docs.map((doc) => doc.id).toList();
  }
}
