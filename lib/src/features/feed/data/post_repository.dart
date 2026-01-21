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
}
