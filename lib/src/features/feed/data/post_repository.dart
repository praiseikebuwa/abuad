import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

import '../domain/post.dart';
import '../../notifications/data/notification_repository.dart';
import '../../notifications/domain/notification.dart';
import '../../user/data/user_repository.dart';

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
    await _firestore.collection('posts').doc(post.id).set(post.toMap());
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

  Stream<List<Post>> watchPosts() {
    return _firestore
        .collection('posts')
        .orderBy('created_at', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Post.fromMap(doc.data())).toList(),
        );
  }

  // New: Watch user specific posts (for Profile)
  Stream<List<Post>> watchUserPosts(String userId) {
    return _firestore
        .collection('posts')
        .where('author_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .limit(20)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Post.fromMap(doc.data())).toList(),
        );
  }

  // New: Watch channel specific posts
  Stream<List<Post>> watchChannelPosts(String channelId) {
    Query query = _firestore.collection('posts');

    if (channelId == 'general') {
      query = query.where('channel_id', whereIn: ['general', 'public']);
    } else {
      query = query.where('channel_id', isEqualTo: channelId);
    }

    return query
        .orderBy('created_at', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Post.fromMap(doc.data() as Map<String, dynamic>))
              .toList(),
        );
  }

  // New: Watch posts by hashtag
  Stream<List<Post>> watchPostsByTag(String tag) {
    return _firestore
        .collection('posts')
        .where('hashtags', arrayContains: tag.toLowerCase())
        .orderBy('created_at', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Post.fromMap(doc.data())).toList(),
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
    return _firestore
        .collectionGroup('likes')
        .where('uid', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .asyncMap((snapshot) async {
          final postIds = snapshot.docs
              .map((doc) => doc.reference.parent.parent!.id)
              .toList();
          if (postIds.isEmpty) return [];

          final posts = <Post>[];
          for (final id in postIds) {
            final doc = await _firestore.collection('posts').doc(id).get();
            if (doc.exists) {
              posts.add(Post.fromMap(doc.data()!));
            }
          }
          return posts;
        });
  }

  Stream<Post?> watchPost(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .snapshots()
        .map((doc) => doc.exists ? Post.fromMap(doc.data()!) : null);
  }

  // New: Watch user media (images/videos)
  Stream<List<Post>> watchUserMedia(String userId) {
    return _firestore
        .collection('posts')
        .where('author_id', isEqualTo: userId)
        .where('media_type', whereIn: ['image', 'video', 'gif'])
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

  Future<void> addComment(String postId, String content) async {
    final userId = currentUserId;
    if (userId == null) return;

    final commentId = _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc()
        .id;

    final user = await _userRepository.getUserById(userId);
    final userName = user?.displayName ?? 'Student';
    final userAvatar = user?.avatarUrl;

    await _firestore.runTransaction((transaction) async {
      final postRef = _firestore.collection('posts').doc(postId);
      final commentRef = postRef.collection('comments').doc(commentId);

      transaction.set(commentRef, {
        'id': commentId,
        'user_id': userId,
        'user_name': userName,
        'user_avatar': userAvatar,
        'content': content,
        'created_at': FieldValue.serverTimestamp(),
      });

      transaction.update(postRef, {'comments_count': FieldValue.increment(1)});
    });
  }

  Stream<List<Map<String, dynamic>>> watchComments(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('created_at', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': data['id'],
              'userId': data['user_id'],
              'userName': data['user_name'] ?? 'Student',
              'userAvatar': data['user_avatar'],
              'content': data['content'],
              'timestamp':
                  (data['created_at'] as Timestamp?)?.millisecondsSinceEpoch,
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

  Future<void> repost(Post originalPost, String commentary) async {
    final userId = currentUserId;
    if (userId == null) return;

    final user = await _userRepository.getUserById(userId);
    if (user == null) return;

    final newPostId = _firestore.collection('posts').doc().id;
    final now = DateTime.now();

    // If original post is a repost, we likely want to repost the *original* content,
    // but the current UI requirement implies we just treat the target post as the one being quoted.
    // So we just take the passed `originalPost` data.

    final repostData = {
      'post_id': originalPost.id,
      'author_id': originalPost.authorId,
      'author_name': originalPost.authorName,
      'author_handle': originalPost.authorHandle,
      'author_avatar_url': originalPost.authorAvatarUrl,
      'content': originalPost.content,
      'media_url': originalPost.mediaUrl,
      'media_type': originalPost.mediaType.name,
      'timestamp': originalPost.timestamp.toIso8601String(),
      'is_verified': originalPost.isVerified,
      'verification_type': originalPost.verificationType,
      'is_anonymous': originalPost.isAnonymous,
    };

    final newPost = Post(
      id: newPostId,
      authorId: userId,
      authorName: user.displayName,
      authorHandle: user.handle,
      authorAvatarUrl: user.avatarUrl,
      content: commentary,
      timestamp: now,
      repostData: repostData,
      isVerified: user.isVerified,
      verificationType: user.verificationType,
    );

    // Run transaction
    await _firestore.runTransaction((transaction) async {
      // 1. Create the new post
      transaction.set(
        _firestore.collection('posts').doc(newPostId),
        newPost.toMap(),
      );

      // 2. Increment repost count on the original post
      final originalPostRef = _firestore
          .collection('posts')
          .doc(originalPost.id);
      transaction.update(originalPostRef, {
        'repost_count': FieldValue.increment(1),
      });
    });

    // 3. Send Notification (outside transaction to avoid complex logic inside)
    if (originalPost.authorId != userId) {
      await _notificationRepository.sendNotification(
        recipientId: originalPost.authorId,
        senderId: userId,
        senderName: user.displayName,
        senderAvatarUrl: user.avatarUrl,
        type: NotificationType
            .repost, // Make sure to add 'repost' to NotificationType enum
        title: 'New Repost',
        body: '${user.displayName} reposted your post',
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

    final pollData = postSnapshot.data()!['poll'] as Map<String, dynamic>;
    final votedUsers = List<String>.from(pollData['voted_users'] ?? []);
    if (votedUsers.contains(userId)) {
      throw Exception("You have already voted on this poll");
    }

    final options = List<Map<String, dynamic>>.from(
      pollData['options'].map((x) => Map<String, dynamic>.from(x)),
    );
    options[optionIndex]['votes'] = (options[optionIndex]['votes'] ?? 0) + 1;

    await postRef.update({
      'poll': {
        ...pollData,
        'options': options,
        'voted_users': FieldValue.arrayUnion([userId]),
      },
    });
  }

  Future<void> deletePost(String postId) async {
    await _firestore.collection('posts').doc(postId).delete();
  }

  Stream<List<Post>> searchPosts(String query) {
    return _firestore
        .collection('posts')
        .orderBy('created_at', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Post.fromMap(doc.data()))
              .where(
                (p) => p.content.toLowerCase().contains(query.toLowerCase()),
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
}
