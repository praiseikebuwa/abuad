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

  Future<void> generateDummyData() async {
    final postsCollection = _firestore.collection('posts');
    final snapshot = await postsCollection.limit(1).get();

    // Only generate if empty
    if (snapshot.docs.isNotEmpty) return;

    final uuid = const Uuid();

    for (int i = 0; i < 5; i++) {
      final id = uuid.v4();
      final post = Post(
        id: id,
        authorId: 'dummy_user_$i',
        authorName: 'Student ${i + 1}',
        authorHandle: '@student${i + 1}',
        content: 'This is a sample live post #$i from Firestore!',
        timestamp: DateTime.now().subtract(Duration(minutes: i * 10)),
        likesCount: i * 5,
        commentsCount: i,
        isVerified: i % 2 == 0,
      );

      await addPost(post);
    }
  }
}
