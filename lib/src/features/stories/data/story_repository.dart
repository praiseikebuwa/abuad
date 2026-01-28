import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../domain/story_model.dart';
import '../../../core/services/supabase_storage_service.dart';

/// Repository for Story operations with Firestore
class StoryRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SupabaseStorageService _storage = SupabaseStorageService();

  /// Create a new story
  /// Uploads media to Supabase and saves to Firestore with 24h expiration
  Future<String> createStory({
    required XFile mediaFile,
    required String mediaType,
    String? caption,
    String? backgroundColor,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get user data
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      // Upload media to Supabase
      debugPrint('📤 Uploading story media to Supabase...');
      final mediaUrl = mediaType == 'video'
          ? await _storage.uploadVideo(mediaFile)
          : await _storage.uploadImage(mediaFile);

      // Calculate expiration (24 hours from now)
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(hours: 24));

      // Create story document
      final storyData = {
        'userId': user.uid,
        'userName': userData['displayName'] ?? 'Unknown User',
        'userAvatar': userData['avatarUrl'] ?? '',
        'mediaUrl': mediaUrl,
        'mediaType': mediaType,
        'caption': caption,
        'backgroundColor': backgroundColor,
        'createdAt': Timestamp.fromDate(now),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'viewCount': 0,
        'viewers': [],
      };

      final docRef = await _firestore.collection('stories').add(storyData);
      debugPrint('✅ Story created: ${docRef.id}');

      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error creating story: $e');
      rethrow;
    }
  }

  /// Get all stories for a specific user (non-expired)
  Stream<List<Story>> getUserStories(String userId) {
    return _firestore
        .collection('stories')
        .where('userId', isEqualTo: userId)
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .orderBy('expiresAt')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Story.fromFirestore(doc)).toList();
        });
  }

  /// Get all non-expired stories grouped by user
  Stream<Map<String, List<Story>>> getAllStoriesGrouped() {
    return _firestore
        .collection('stories')
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .orderBy('expiresAt')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          final stories = snapshot.docs
              .map((doc) => Story.fromFirestore(doc))
              .toList();

          // Group stories by userId
          final grouped = <String, List<Story>>{};
          for (final story in stories) {
            grouped.putIfAbsent(story.userId, () => []).add(story);
          }

          return grouped;
        });
  }

  /// Get all non-expired stories as a flat list
  Stream<List<Story>> getAllStories() {
    return _firestore
        .collection('stories')
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .orderBy('expiresAt')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Story.fromFirestore(doc)).toList();
        });
  }

  /// Mark a story as viewed by the current user
  Future<void> markAsViewed(String storyId, String viewerId) async {
    try {
      final storyRef = _firestore.collection('stories').doc(storyId);
      final storyDoc = await storyRef.get();

      if (!storyDoc.exists) return;

      final story = Story.fromFirestore(storyDoc);

      // Don't track if already viewed
      if (story.hasViewed(viewerId)) return;

      // Add viewer to list and increment count
      await storyRef.update({
        'viewers': FieldValue.arrayUnion([viewerId]),
        'viewCount': FieldValue.increment(1),
      });

      // Track in subcollection for analytics
      await storyRef.collection('views').doc(viewerId).set({
        'viewerId': viewerId,
        'viewedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Story $storyId marked as viewed by $viewerId');
    } catch (e) {
      debugPrint('❌ Error marking story as viewed: $e');
    }
  }

  /// Delete a story (only owner can delete)
  Future<void> deleteStory(String storyId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final storyDoc = await _firestore
          .collection('stories')
          .doc(storyId)
          .get();
      if (!storyDoc.exists) return;

      final story = Story.fromFirestore(storyDoc);

      // Verify ownership
      if (story.userId != user.uid) {
        throw Exception('You can only delete your own stories');
      }

      // Delete story
      await _firestore.collection('stories').doc(storyId).delete();
      debugPrint('✅ Story deleted: $storyId');
    } catch (e) {
      debugPrint('❌ Error deleting story: $e');
      rethrow;
    }
  }

  /// Get viewers for a story (for owner to see who viewed)
  Future<List<Map<String, dynamic>>> getStoryViewers(String storyId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final storyDoc = await _firestore
          .collection('stories')
          .doc(storyId)
          .get();
      if (!storyDoc.exists) return [];

      final story = Story.fromFirestore(storyDoc);

      // Only owner can see viewers
      if (story.userId != user.uid) return [];

      final viewsSnapshot = await _firestore
          .collection('stories')
          .doc(storyId)
          .collection('views')
          .orderBy('viewedAt', descending: true)
          .get();

      final viewers = <Map<String, dynamic>>[];
      for (final viewDoc in viewsSnapshot.docs) {
        final viewData = viewDoc.data();
        final viewerId = viewData['viewerId'];

        // Get viewer user data
        final userDoc = await _firestore
            .collection('users')
            .doc(viewerId)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          viewers.add({
            'userId': viewerId,
            'displayName': userData['displayName'],
            'avatarUrl': userData['avatarUrl'],
            'viewedAt': viewData['viewedAt'],
          });
        }
      }

      return viewers;
    } catch (e) {
      debugPrint('❌ Error getting story viewers: $e');
      return [];
    }
  }

  /// Check if user has unviewed stories from a specific user
  Future<bool> hasUnviewedStories(String userId, String currentUserId) async {
    try {
      final snapshot = await _firestore
          .collection('stories')
          .where('userId', isEqualTo: userId)
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .get();

      for (final doc in snapshot.docs) {
        final story = Story.fromFirestore(doc);
        if (!story.hasViewed(currentUserId)) {
          return true; // Found at least one unviewed story
        }
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error checking unviewed stories: $e');
      return false;
    }
  }
}
