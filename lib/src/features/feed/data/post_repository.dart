import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

import '../domain/post.dart';
import '../../notifications/data/notification_repository.dart';
import '../../notifications/domain/notification.dart';
import '../../user/data/user_repository.dart';
import '../../../core/utils/profanity_filter.dart';
import '../../../core/services/moderation_service.dart';

final postRepositoryProvider = Provider<PostRepository>((ref) {
  return PostRepository(
    FirebaseFirestore.instance,
    ref.read(notificationRepositoryProvider),
    ref.read(userRepositoryProvider),
  );
});

final isPostLikedProvider = StreamProvider.family<bool, String>((ref, postId) {
  final repo = ref.watch(postRepositoryProvider);
  return repo.isPostLiked(postId);
});

final trendingTagsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final repo = ref.watch(postRepositoryProvider);
  return repo.watchTrendingTags();
});

final postProvider = StreamProvider.family<Post?, String>((ref, postId) {
  return ref.watch(postRepositoryProvider).watchPost(postId);
});

class PostRepository {
  final FirebaseFirestore _firestore;
  final NotificationRepository _notificationRepository;
  final UserRepository _userRepository;

  PostRepository(
    this._firestore,
    this._notificationRepository,
    this._userRepository,
  );

  String? get currentUserId => auth.FirebaseAuth.instance.currentUser?.uid;

  Future<void> addPost(Post post) async {
    // Stage 1: Local Moderation (Fast)
    bool isSafe = !ProfanityFilter.hasProfanity(post.content);

    // Stage 2: AI Moderation (Robust)
    if (isSafe && post.content.isNotEmpty) {
      isSafe = await ModerationService.isContentSafe(post.content);
    }

    final status = isSafe ? post.status : 'flagged';

    await _firestore
        .collection('posts')
        .doc(post.id)
        .set(post.copyWith(status: status).toMap());

    _processMentions(post);
  }

  Future<void> _processMentions(Post post) async {
    final content = post.content;
    final regExp = RegExp(r"\@(\w+)");
    final matches = regExp.allMatches(content);

    final processedHandles = <String>{};

    for (final match in matches) {
      final handle = match.group(1);
      if (handle != null && !processedHandles.contains(handle)) {
        processedHandles.add(handle);
        final user = await _userRepository.getUserByHandle(handle);

        if (user != null && user.uid != post.authorId) {
          await _notificationRepository.sendNotification(
            recipientId: user.uid,
            senderId: post.authorId,
            senderName: post.authorName,
            senderAvatarUrl: post.authorAvatarUrl,
            type: NotificationType.mention,
            title: 'You were mentioned',
            body: '${post.authorName} mentioned you in a post',
            relatedId: post.id,
          );
        }
      }
    }
  }

  Stream<List<Post>> watchPosts({
    List<String> blockedUserIds = const [],
    int limit = 50,
  }) {
    return _firestore
        .collection('posts')
        .where('status', isEqualTo: 'active')
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Post.fromMap(doc.data()))
              .where((p) => !blockedUserIds.contains(p.authorId))
              .toList(),
        );
  }

  // New: Watch posts from users you follow
  Stream<List<Post>> watchFollowingPosts(
    String userId, {
    List<String> blockedUserIds = const [],
    int limit = 50,
  }) {
    late StreamController<List<Post>> controller;
    StreamSubscription? followingSub;
    StreamSubscription? postsSub;

    controller = StreamController<List<Post>>.broadcast(
      onListen: () {
        followingSub = _firestore
            .collection('users')
            .doc(userId)
            .collection('following')
            .orderBy('timestamp', descending: true)
            .limit(30)
            .snapshots()
            .listen((snapshot) {
          final followingUids = snapshot.docs
              .map((doc) => doc.id)
              .take(30)
              .toList();

          postsSub?.cancel();

          if (followingUids.isEmpty) {
            controller.add([]);
            return;
          }

          postsSub = _firestore
              .collection('posts')
              .where('author_id', whereIn: followingUids)
              .where('status', isEqualTo: 'active')
              .orderBy('created_at', descending: true)
              .limit(limit)
              .snapshots()
              .listen((postSnapshot) {
            final posts = postSnapshot.docs
                .map((doc) => Post.fromMap(doc.data()))
                .where((p) => !blockedUserIds.contains(p.authorId))
                .toList();
            controller.add(posts);
          }, onError: (e) {
            if (!controller.isClosed) controller.addError(e);
          });
        }, onError: (e) {
          if (!controller.isClosed) controller.addError(e);
        });
      },
      onCancel: () {
        followingSub?.cancel();
        postsSub?.cancel();
        controller.close();
      },
    );

    return controller.stream;
  }
  // New: Watch user specific posts (for Profile)
  Stream<List<Post>> watchUserPosts(String userId, {int limit = 20}) {
    return _firestore
        .collection('posts')
        .where('author_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Post.fromMap(doc.data())).toList(),
        );
  }

  // New: Watch channel specific posts
  Stream<List<Post>> watchChannelPosts(
    String channelId, {
    List<String> blockedUserIds = const [],
    int limit = 50,
  }) {
    Query query = _firestore.collection('posts');

    if (channelId == 'general') {
      query = query.where('channel_id', whereIn: ['general', 'public']);
    } else {
      query = query.where('channel_id', isEqualTo: channelId);
    }

    return query
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Post.fromMap(doc.data() as Map<String, dynamic>))
              .where((p) => !blockedUserIds.contains(p.authorId))
              .toList(),
        );
  }

  // New: Watch posts by hashtag
  Stream<List<Post>> watchPostsByTag(
    String tag, {
    List<String> blockedUserIds = const [],
    int limit = 50,
  }) {
    return _firestore
        .collection('posts')
        .where('hashtags', arrayContains: tag.toLowerCase())
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Post.fromMap(doc.data()))
              .where((p) => !blockedUserIds.contains(p.authorId))
              .toList(),
        );
  }

  // New: Watch comments made by user
  Stream<List<Map<String, dynamic>>> watchUserReplies(String userId) {
    return _firestore
        .collectionGroup('comments')
        .where('user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            // We might want to fetch parent post here too if we want to show context
            // For now just returning comment data + postId (from reference)
            return {
              'id': data['id'],
              'postId': doc.reference.parent.parent!.id,
              'content': data['content'],
              'timestamp':
                  (data['created_at'] as Timestamp?)?.millisecondsSinceEpoch,
            };
          }).toList();
        });
  }

  // New: Watch posts liked by user
  Stream<List<Post>> watchUserLikes(String userId) {
    late StreamController<List<Post>> controller;
    StreamSubscription? likesSub;
    final Map<String, StreamSubscription> postSubs = {};
    final Map<String, Post> cachedPosts = {};

    controller = StreamController<List<Post>>.broadcast(
      onListen: () {
        likesSub = _firestore
            .collectionGroup('likes')
            .where('uid', isEqualTo: userId)
            .orderBy('timestamp', descending: true)
            .limit(20)
            .snapshots()
            .listen((snapshot) {
          final postIds = snapshot.docs
              .map((doc) => doc.reference.parent.parent!.id)
              .toList();
          
          if (postIds.isEmpty) {
            controller.add([]);
            return;
          }

          final idsToRemove = postSubs.keys.where((id) => !postIds.contains(id)).toList();
          for (final id in idsToRemove) {
            postSubs[id]?.cancel();
            postSubs.remove(id);
            cachedPosts.remove(id);
          }

          for (final id in postIds) {
            if (!postSubs.containsKey(id)) {
              postSubs[id] = _firestore
                  .collection('posts')
                  .doc(id)
                  .snapshots()
                  .listen((doc) {
                if (doc.exists) {
                  cachedPosts[id] = Post.fromMap(doc.data()!);
                } else {
                  cachedPosts.remove(id);
                }
                
                final results = postIds.map((pid) => cachedPosts[pid]).whereType<Post>().toList();
                controller.add(results);
              }, onError: (e) {
              });
            }
          }
        }, onError: (e) {
          if (!controller.isClosed) controller.addError(e);
        });
      },
      onCancel: () {
        likesSub?.cancel();
        for (final sub in postSubs.values) {
          sub.cancel();
        }
        controller.close();
      },
    );

    return controller.stream;
  }
  Stream<Post?> watchPost(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .snapshots()
        .map((doc) => doc.exists ? Post.fromMap(doc.data()!) : null);
  }

  // New: Watch user media (images/videos)
  Stream<List<Post>> watchUserMedia(String userId, {int limit = 20}) {
    return _firestore
        .collection('posts')
        .where('author_id', isEqualTo: userId)
        .where('media_type', whereIn: ['image', 'video', 'gif'])
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Post.fromMap(doc.data())).toList(),
        );
  }

  // New: Watch suggested posts (popular/recent)
  Stream<List<Post>> watchSuggestedPosts() {
    return _firestore
        .collection('posts')
        .orderBy('likes_count', descending: true)
        .orderBy('created_at', descending: true)
        .limit(20)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Post.fromMap(doc.data())).toList(),
        );
  }

  Future<void> toggleLike(String postId) async {
    final userId = currentUserId;
    if (userId == null) return;

    final postRef = _firestore.collection('posts').doc(postId);
    final likeRef = postRef.collection('likes').doc(userId);

    await _firestore.runTransaction((transaction) async {
      final likeSnapshot = await transaction.get(likeRef);

      if (likeSnapshot.exists) {
        transaction.delete(likeRef);
        transaction.update(postRef, {'likes_count': FieldValue.increment(-1)});
      } else {
        transaction.set(likeRef, {
          'uid': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        transaction.update(postRef, {'likes_count': FieldValue.increment(1)});
      }
    });
  }

  Stream<bool> isPostLiked(String postId) {
    final userId = currentUserId;
    if (userId == null) return Stream.value(false);

    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Future<void> addComment(
    String postId,
    String content, {
    String? parentId,
    String? imageUrl,
    String? mediaType,
    Map<String, dynamic>? pollData,
    double? latitude,
    double? longitude,
  }) async {
    final userId = currentUserId;
    if (userId == null) return;

    // Stage 1: Local Moderation (Fast)
    bool isSafe = !ProfanityFilter.hasProfanity(content);

    // Stage 2: AI Moderation (Robust)
    if (isSafe && content.isNotEmpty) {
      isSafe = await ModerationService.isContentSafe(content);
    }

    final status = isSafe ? 'active' : 'flagged';

    final parentPath = parentId != null
        ? 'posts/$postId/comments/$parentId/replies'
        : 'posts/$postId/comments';

    final commentId = _firestore.collection(parentPath).doc().id;

    final user = await _userRepository.getUserById(userId);
    final userName = user?.displayName ?? 'Student';
    final userAvatar = user?.avatarUrl;

    await _firestore.runTransaction((transaction) async {
      final postRef = _firestore.collection('posts').doc(postId);
      final commentRef = _firestore.collection(parentPath).doc(commentId);

      transaction.set(commentRef, {
        'id': commentId,
        'user_id': userId,
        'user_name': userName,
        'user_avatar': userAvatar,
        'author_is_verified': user?.isVerified ?? false,
        'author_verification_type': user?.verificationType ?? 'none',
        'content': content,
        'status': status,
        'created_at': FieldValue.serverTimestamp(),
        'parent_id': ?parentId,
        'image_url': ?imageUrl,
        'media_type': ?mediaType,
        'poll': ?pollData,
        'latitude': ?latitude,
        'longitude': ?longitude,
      });

      // Increment total comment count on post
      transaction.update(postRef, {'comments_count': FieldValue.increment(1)});

      // If it's a reply, we might want to increment a reply count on the parent comment as well
      if (parentId != null) {
        final parentCommentRef = _firestore
            .collection('posts')
            .doc(postId)
            .collection('comments')
            .doc(parentId);
        transaction.update(parentCommentRef, {
          'reply_count': FieldValue.increment(1),
        });
      }
    });

    // Send Notification to post author or parent comment author
    try {
      if (parentId != null) {
        final parentCommentDoc = await _firestore
            .collection('posts')
            .doc(postId)
            .collection('comments')
            .doc(parentId)
            .get();
        final recipientId = parentCommentDoc.data()?['user_id'];
        if (recipientId != null && recipientId != userId) {
          await _notificationRepository.sendNotification(
            recipientId: recipientId,
            senderId: userId,
            senderName: userName,
            senderAvatarUrl: userAvatar,
            type: NotificationType.comment,
            title: 'New Reply',
            body: '$userName replied to your comment',
            relatedId: postId,
          );
        }
      } else {
        final postDoc = await _firestore.collection('posts').doc(postId).get();
        final recipientId = postDoc.data()?['author_id'];
        if (recipientId != null && recipientId != userId) {
          await _notificationRepository.sendNotification(
            recipientId: recipientId,
            senderId: userId,
            senderName: userName,
            senderAvatarUrl: userAvatar,
            type: NotificationType.comment,
            title: 'New Comment',
            body: '$userName commented on your post',
            relatedId: postId,
          );
        }
      }
    } catch (e) {
      print('Error sending comment notification: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> watchComments(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .where('status', isEqualTo: 'active')
        .orderBy('created_at', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': data['id'] ?? doc.id,
              'userId': data['user_id'],
              'userName': data['user_name'] ?? 'Student',
              'userAvatar': data['user_avatar'],
              'content': data['content'],
              'timestamp':
                  (data['created_at'] as Timestamp?)?.millisecondsSinceEpoch,
              'imageUrl': data['image_url'],
              'mediaType': data['media_type'],
              'poll': data['poll'],
              'latitude': data['latitude'],
              'longitude': data['longitude'],
              'replyCount': data['reply_count'] ?? 0,
              'authorIsVerified': data['author_is_verified'] ?? false,
              'authorVerificationType':
                  data['author_verification_type'] ?? 'none',
            };
          }).toList();
        });
  }

  Stream<List<Map<String, dynamic>>> watchReplies(
    String postId,
    String commentId,
  ) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .where('status', isEqualTo: 'active')
        .orderBy('created_at', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': data['id'] ?? doc.id,
              'userId': data['user_id'],
              'userName': data['user_name'] ?? 'Student',
              'userAvatar': data['user_avatar'],
              'content': data['content'],
              'timestamp':
                  (data['created_at'] as Timestamp?)?.millisecondsSinceEpoch,
              'imageUrl': data['image_url'],
              'mediaType': data['media_type'],
              'poll': data['poll'],
              'latitude': data['latitude'],
              'longitude': data['longitude'],
              'parent_id': commentId,
              'authorIsVerified': data['author_is_verified'] ?? false,
              'authorVerificationType':
                  data['author_verification_type'] ?? 'none',
            };
          }).toList();
        });
  }

  Future<void> deleteComment(String postId, String commentId) async {
    final userId = currentUserId;
    if (userId == null) return;

    final postRef = _firestore.collection('posts').doc(postId);
    final commentRef = postRef.collection('comments').doc(commentId);

    final commentDoc = await commentRef.get();
    if (commentDoc['user_id'] != userId) {
      // Allow post author to delete any comment? For now only comment author.
      // Check if post author
      final postDoc = await postRef.get();
      if (postDoc['author_id'] != userId) {
        throw Exception("Cannot delete others' comments");
      }
    }

    final batch = _firestore.batch();
    batch.delete(commentRef);
    batch.update(postRef, {'comments_count': FieldValue.increment(-1)});
    await batch.commit();
  }

  Future<void> repost(Post targetPost, String commentary) async {
    final userId = currentUserId;
    if (userId == null) return;

    final user = await _userRepository.getUserById(userId);
    if (user == null) return;

    // Stage 1: Local Moderation
    bool isSafe = !ProfanityFilter.hasProfanity(commentary);

    // Stage 2: AI Moderation (Robust)
    if (isSafe && commentary.isNotEmpty) {
      isSafe = await ModerationService.isContentSafe(commentary);
    }

    final status = isSafe ? 'active' : 'flagged';

    final newPostId = _firestore.collection('posts').doc().id;
    final now = DateTime.now();

    // Determine the TRUE original post data to avoid deep nesting
    // If targetPost is already a Pure Repost (no commentary), we repost its repostData (original).
    // If targetPost is a Quote Repost (has commentary), we quote that specific post.

    Map<String, dynamic> finalRepostData;
    String originalPostIdToIncrement;

    if (targetPost.repostData != null && targetPost.content.trim().isEmpty) {
      // It's a Pure Repost, so we quote/repost the ORIGINAL post directly.
      finalRepostData = Map<String, dynamic>.from(targetPost.repostData!);
      originalPostIdToIncrement = targetPost.repostData!['id'];
    } else {
      // It's a regular post or a Quote Repost, so we quote THIS target post.
      finalRepostData = {
        'id': targetPost.id,
        'author_id': targetPost.authorId,
        'author_name': targetPost.authorName,
        'author_handle': targetPost.authorHandle,
        'author_avatar_url': targetPost.authorAvatarUrl,
        'content': targetPost.content,
        'media_url': targetPost.mediaUrl,
        'media_type': targetPost.mediaType.name,
        'created_at': Timestamp.fromDate(targetPost.timestamp),
        'is_verified': targetPost.isVerified,
        'verification_type': targetPost.verificationType,
        'is_anonymous': targetPost.isAnonymous,
      };
      originalPostIdToIncrement = targetPost.id;
    }

    final newPost = Post(
      id: newPostId,
      authorId: userId,
      authorName: user.displayName,
      authorHandle: user.handle,
      authorAvatarUrl: user.avatarUrl,
      content: commentary,
      timestamp: now,
      repostData: finalRepostData,
      isVerified: user.isVerified,
      verificationType: user.verificationType,
      status: status,
    );

    // Run transaction
    await _firestore.runTransaction((transaction) async {
      // 1. Create the new post
      transaction.set(
        _firestore.collection('posts').doc(newPostId),
        newPost.toMap(),
      );

      // 2. Increment repost count on the original post reference
      final originalPostRef = _firestore
          .collection('posts')
          .doc(originalPostIdToIncrement);
      transaction.update(originalPostRef, {
        'repost_count': FieldValue.increment(1),
      });

      // 3. Increment repost count on the target post if it's different (optional but standard)
      if (originalPostIdToIncrement != targetPost.id) {
        transaction.update(_firestore.collection('posts').doc(targetPost.id), {
          'repost_count': FieldValue.increment(1),
        });
      }
    });

    // 4. Process mentions in commentary
    if (commentary.isNotEmpty) {
      _processMentions(newPost);
    }

    // 5. Send Notification
    if (targetPost.authorId != userId) {
      await _notificationRepository.sendNotification(
        recipientId: targetPost.authorId,
        senderId: userId,
        senderName: user.displayName,
        senderAvatarUrl: user.avatarUrl,
        type: NotificationType.repost,
        title: 'New Repost',
        body: commentary.isEmpty
            ? '${user.displayName} reposted your post'
            : '${user.displayName} quoted your post',
        relatedId: newPostId,
      );
    }
  }

  Future<void> votePoll(String postId, int optionIndex) async {
    final userId = currentUserId;
    if (userId == null) return;

    final postRef = _firestore.collection('posts').doc(postId);
    final postSnapshot = await postRef.get();

    if (!postSnapshot.exists) return;

    final data = postSnapshot.data()!;
    final Map<String, dynamic> pollData = Map<String, dynamic>.from(
      data['poll_data'] ?? {},
    );
    if (pollData.isEmpty) return;

    final voters = Map<String, dynamic>.from(pollData['voters'] ?? {});
    if (voters.containsKey(userId)) {
      throw Exception("You have already voted on this poll");
    }

    final options = List<dynamic>.from(pollData['options'] ?? []);
    if (optionIndex >= options.length) return;

    final List<int> currentVotes = List<int>.generate(options.length, (i) {
      final List<dynamic> votesRaw = pollData['votes'] ?? [];
      if (i < votesRaw.length) {
        return (votesRaw[i] as num?)?.toInt() ?? 0;
      }
      return 0;
    });

    currentVotes[optionIndex]++;
    voters[userId] = optionIndex;

    await postRef.update({
      'poll_data': {...pollData, 'votes': currentVotes, 'voters': voters},
    });
  }

  Future<void> deletePost(String postId) async {
    await _firestore.collection('posts').doc(postId).delete();
  }

  Stream<List<Post>> searchPosts(
    String query, {
    List<String> blockedUserIds = const [],
  }) {
    return _firestore
        .collection('posts')
        .orderBy('created_at', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Post.fromMap(doc.data()))
              .where(
                (p) =>
                    p.content.toLowerCase().contains(query.toLowerCase()) &&
                    !blockedUserIds.contains(p.authorId),
              )
              .toList();
        });
  }

  Stream<List<String>> searchTags(String query) {
    return _firestore
        .collection('posts')
        .orderBy('created_at', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
          final Set<String> tags = {};
          final regExp = RegExp(r"\#(\w+)");

          for (final doc in snapshot.docs) {
            final content = doc.data()['content'] as String;
            final matches = regExp.allMatches(content);
            for (final match in matches) {
              final tag = match.group(0);
              if (tag != null) {
                tags.add(tag);
              }
            }
          }

          return tags
              .where((t) => t.toLowerCase().contains(query.toLowerCase()))
              .toList();
        });
  }

  Future<void> incrementViewCount(String postId) async {
    final userId = currentUserId;
    if (userId == null) return;

    final viewDoc = _firestore
        .collection('posts')
        .doc(postId)
        .collection('views')
        .doc(userId);

    final snapshot = await viewDoc.get();
    if (snapshot.exists) return; // Already viewed

    final batch = _firestore.batch();
    batch.set(viewDoc, {
      'uid': userId,
      'timestamp': FieldValue.serverTimestamp(),
    });
    batch.update(_firestore.collection('posts').doc(postId), {
      'views_count': FieldValue.increment(1),
    });
    await batch.commit();
  }

  Future<void> incrementShareCount(String postId) async {
    await _firestore.collection('posts').doc(postId).update({
      'shares_count': FieldValue.increment(1),
    });
  }

  // New: Watch trending tags (aggregates from recent posts)
  Stream<List<Map<String, dynamic>>> watchTrendingTags() {
    return _firestore
        .collection('posts')
        .orderBy('created_at', descending: true)
        .limit(100) // Look at last 100 posts for trending
        .snapshots()
        .map((snapshot) {
          final tagCounts = <String, int>{};

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final tags = List<String>.from(data['hashtags'] ?? []);
            for (final tag in tags) {
              final normalizedTag = tag.toLowerCase();
              tagCounts[normalizedTag] = (tagCounts[normalizedTag] ?? 0) + 1;
            }
          }

          final sortedTags = tagCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          return sortedTags
              .map((e) => {'tag': e.key, 'count': e.value})
              .take(10) // Top 10
              .toList();
        });
  }

  // New: Watch all video posts specifically for Reels
  Stream<List<Post>> watchVideoPosts({
    List<String> blockedUserIds = const [],
    int limit = 50,
  }) {
    return _firestore
        .collection('posts')
        .where('media_type', isEqualTo: 'video')
        .where('status', isEqualTo: 'active')
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Post.fromMap(doc.data()))
              .where((p) => !blockedUserIds.contains(p.authorId))
              .toList(),
        );
  }


  Future<PaginatedPostsResult> fetchFollowingPostsPage(
    String userId, {
    List<String> blockedUserIds = const [],
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 15,
  }) async {
    final followingSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('following')
        .orderBy('timestamp', descending: true)
        .limit(30)
        .get();

    final followingUids = followingSnapshot.docs.map((doc) => doc.id).toList();

    if (followingUids.isEmpty) {
      return PaginatedPostsResult(
        posts: [],
        lastDocument: null,
        hasMore: false,
      );
    }

    var query = _firestore
        .collection('posts')
        .where('author_id', whereIn: followingUids)
        .where('status', isEqualTo: 'active')
        .orderBy('created_at', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final postSnapshot = await query.get();
    final posts = postSnapshot.docs
        .map((doc) => Post.fromMap(doc.data()))
        .where((p) => !blockedUserIds.contains(p.authorId))
        .toList();

    return PaginatedPostsResult(
      posts: posts,
      lastDocument: postSnapshot.docs.isNotEmpty ? postSnapshot.docs.last : null,
      hasMore: postSnapshot.docs.length == limit,
    );
  }

  Future<PaginatedPostsResult> fetchChannelPostsPage(
      String channelId, {
      List<String> blockedUserIds = const [],
      DocumentSnapshot<Map<String, dynamic>>? startAfter,
      int limit = 15}) async {
    var query = _firestore.collection('posts')
        .where('channel_id', isEqualTo: channelId)
        .where('status', isEqualTo: 'active')
        .orderBy('created_at', descending: true);
    final res = await fetchPostsPage(query, startAfter: startAfter, limit: limit);
    return PaginatedPostsResult(
      posts: res.posts.where((p) => !blockedUserIds.contains(p.authorId)).toList(),
      lastDocument: res.lastDocument,
      hasMore: res.hasMore,
    );
  }

  Future<PaginatedPostsResult> fetchDiscoveryPostsPage({
      List<String> blockedUserIds = const [],
      DocumentSnapshot<Map<String, dynamic>>? startAfter,
      int limit = 15}) async {
    var query = _firestore.collection('posts')
        .where('status', isEqualTo: 'active')
        .orderBy('created_at', descending: true);
    final res = await fetchPostsPage(query, startAfter: startAfter, limit: limit);
    return PaginatedPostsResult(
      posts: res.posts.where((p) => !blockedUserIds.contains(p.authorId)).toList(),
      lastDocument: res.lastDocument,
      hasMore: res.hasMore,
    );
  }

  Future<PaginatedPostsResult> fetchVideoPostsPage({
      List<String> blockedUserIds = const [],
      DocumentSnapshot<Map<String, dynamic>>? startAfter,
      int limit = 15}) async {
    var query = _firestore.collection('posts')
        .where('media_type', isEqualTo: 'video')
        .where('status', isEqualTo: 'active')
        .orderBy('created_at', descending: true);
    final res = await fetchPostsPage(query, startAfter: startAfter, limit: limit);
    return PaginatedPostsResult(
      posts: res.posts.where((p) => !blockedUserIds.contains(p.authorId)).toList(),
      lastDocument: res.lastDocument,
      hasMore: res.hasMore,
    );
  }

  Future<PaginatedPostsResult> loadFirstPageForQuery(
    Query<Map<String, dynamic>> query, {
    int limit = 15,
  }) {
    return fetchPostsPage(
      query,
      limit: limit,
    );
  }

  Future<PaginatedPostsResult> loadMoreForQuery(
    Query<Map<String, dynamic>> query,
    DocumentSnapshot<Map<String, dynamic>>? cursor, {
    int limit = 15,
  }) {
    return fetchPostsPage(
      query,
      startAfter: cursor,
      limit: limit,
    );
  }

  Future<PaginatedPostsResult> fetchPostsPage(
    Query<Map<String, dynamic>> query, {
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 15,
  }) async {
    var pagedQuery = query.limit(limit);
    if (startAfter != null) {
      pagedQuery = pagedQuery.startAfterDocument(startAfter);
    }

    final snapshot = await pagedQuery.get();
    final posts = snapshot.docs.map((doc) => Post.fromMap(doc.data())).toList();

    return PaginatedPostsResult(
      posts: posts,
      lastDocument:
          snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      hasMore: snapshot.docs.length == limit,
    );
  }
}

class PaginatedPostsResult {
  final List<Post> posts;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;

  PaginatedPostsResult({
    required this.posts,
    required this.lastDocument,
    required this.hasMore,
  });
}
