import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../domain/post.dart';

final postRepositoryProvider = Provider<PostRepository>((ref) {
  return PostRepository();
});

class PostRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  Future<void> addPost(Post post) async {
    await _firestore.collection('posts').doc(post.id).set(post.toMap());
  }

  Stream<List<Post>> watchPosts() {
    return _firestore
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return Post.fromMap(doc.id, doc.data());
          }).toList();
        });
  }

  Stream<Post?> watchPost(String postId) {
    return _firestore.collection('posts').doc(postId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Post.fromMap(doc.id, doc.data()!);
    });
  }

  // Toggle like on a post
  Future<void> toggleLike(String postId) async {
    final userId = currentUserId;
    if (userId == null) return;

    final postRef = _firestore.collection('posts').doc(postId);
    final likesRef = postRef.collection('likes').doc(userId);

    final likeDoc = await likesRef.get();

    if (likeDoc.exists) {
      // Unlike
      await likesRef.delete();
      await postRef.update({'likesCount': FieldValue.increment(-1)});
    } else {
      // Like
      await likesRef.set({
        'userId': userId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      await postRef.update({'likesCount': FieldValue.increment(1)});
    }
  }

  // Check if current user has liked a post
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

  // Add a comment to a post
  Future<void> addComment(String postId, String content) async {
    final userId = currentUserId;
    if (userId == null) return;

    final userDoc = await _firestore.collection('users').doc(userId).get();
    final userName = userDoc.data()?['displayName'] ?? 'Student';

    final commentId = const Uuid().v4();
    final postRef = _firestore.collection('posts').doc(postId);

    await postRef.collection('comments').doc(commentId).set({
      'id': commentId,
      'userId': userId,
      'userName': userName,
      'content': content,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    await postRef.update({'commentsCount': FieldValue.increment(1)});
  }

  // Get comments for a post
  Stream<List<Map<String, dynamic>>> watchComments(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => doc.data()).toList();
        });
  }

  // Delete a comment
  Future<void> deleteComment(String postId, String commentId) async {
    final userId = currentUserId;
    if (userId == null) return;

    final postRef = _firestore.collection('posts').doc(postId);
    final commentRef = postRef.collection('comments').doc(commentId);

    // Verify the comment belongs to the current user
    final commentDoc = await commentRef.get();
    if (!commentDoc.exists) return;

    final commentData = commentDoc.data();
    if (commentData?['userId'] != userId) {
      throw Exception('Cannot delete another user\'s comment');
    }

    // Delete comment and decrement count
    await commentRef.delete();
    await postRef.update({'commentsCount': FieldValue.increment(-1)});
  }

  Future<void> repost(Post originalPost, String commentary) async {
    final userId = currentUserId;
    if (userId == null) return;

    final userDoc = await _firestore.collection('users').doc(userId).get();
    final userName = userDoc.data()?['displayName'] ?? 'Student';
    final userHandle = userDoc.data()?['handle'] ?? '@student';

    final uuid = const Uuid();
    final newPostId = uuid.v4();

    // Create the repost data structure (snapshot of original post)
    final repostData = {
      'id': originalPost.id,
      'authorName': originalPost.authorName,
      'authorHandle': originalPost.authorHandle,
      'content': originalPost.content,
      'mediaUrl': originalPost.mediaUrl,
      'timestamp': originalPost.timestamp.toIso8601String(),
    };

    final newPost = Post(
      id: newPostId,
      authorId: userId,
      authorName: userName,
      authorHandle: userHandle,
      content: commentary,
      timestamp: DateTime.now(),
      repostData: repostData,
      channelId: originalPost.channelId,
    );

    await addPost(newPost);

    // Increment share/repost count on the original post
    await _firestore.collection('posts').doc(originalPost.id).update({
      'repostCount': FieldValue.increment(1),
    });
  }

  // Vote on a poll
  Future<void> votePoll(String postId, int optionIndex) async {
    final userId = currentUserId;
    if (userId == null) return;

    final postRef = _firestore.collection('posts').doc(postId);

    // Run as transaction to ensure consistency
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(postRef);
      if (!snapshot.exists) throw Exception("Post does not exist");

      final data = snapshot.data()!;
      final pollData = Map<String, dynamic>.from(data['pollData'] ?? {});

      if (pollData.isEmpty) return; // No poll

      // Initialize votes array if missing
      final List<dynamic> options = pollData['options'] ?? [];
      List<int> votes = List<int>.from(
        pollData['votes'] ?? List.filled(options.length, 0),
      );
      Map<String, int> voters = Map<String, int>.from(pollData['voters'] ?? {});

      // Check if user already voted
      if (voters.containsKey(userId)) {
        // Optional: Change vote (remove old vote)
        // For now, let's just return or throw. Let's allow changing vote.
        final oldVoteIndex = voters[userId]!;
        if (oldVoteIndex < votes.length) {
          votes[oldVoteIndex] = (votes[oldVoteIndex] > 0)
              ? votes[oldVoteIndex] - 1
              : 0;
        }
      }

      // Add new vote
      if (optionIndex < votes.length) {
        votes[optionIndex] = votes[optionIndex] + 1;
        voters[userId] = optionIndex;
      }

      pollData['votes'] = votes;
      pollData['voters'] = voters;

      transaction.update(postRef, {'pollData': pollData});
    });
  }

  // Delete a post (only if user is the author)
  Future<void> deletePost(String postId) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final postRef = _firestore.collection('posts').doc(postId);
    final postDoc = await postRef.get();

    if (!postDoc.exists) {
      throw Exception('Post not found');
    }

    final postData = postDoc.data();
    if (postData?['authorId'] != userId) {
      throw Exception('You can only delete your own posts');
    }

    // Delete all subcollections (likes, comments)
    final batch = _firestore.batch();

    // Delete likes
    final likesSnapshot = await postRef.collection('likes').get();
    for (var doc in likesSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete comments
    final commentsSnapshot = await postRef.collection('comments').get();
    for (var doc in commentsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete the post itself
    batch.delete(postRef);

    await batch.commit();
  }
}
