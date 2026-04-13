import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/story.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/firebase_storage_service.dart';
import '../../user/data/user_repository.dart';
import '../../../core/utils/profanity_filter.dart';
import '../../../core/services/moderation_service.dart';

final storyRepositoryProvider = Provider<StoryRepository>((ref) {
  return StoryRepository(
    FirebaseFirestore.instance,
    ref,
    FirebaseStorageService(),
  );
});

final activeStoriesProvider = StreamProvider<List<Story>>((ref) {
  return ref.watch(storyRepositoryProvider).watchActiveStories();
});

final allStoriesGroupedProvider = Provider<AsyncValue<Map<String, List<Story>>>>((ref) {
  final storiesAsync = ref.watch(activeStoriesProvider);
  return storiesAsync.whenData((stories) {
    final groups = <String, List<Story>>{};
    for (final story in stories) {
      groups.putIfAbsent(story.authorId, () => []).add(story);
    }
    return groups;
  });
});


class StoryRepository {
  final FirebaseFirestore _firestore;
  final Ref _ref;
  final FirebaseStorageService _storage;

  StoryRepository(this._firestore, this._ref, this._storage);

  String? get currentUserId =>
      _ref.read(authRepositoryProvider).currentUser?.uid;

  // Watch all active stories (expiresAt > now)
  Stream<List<Story>> watchActiveStories() {
    return _firestore
        .collection('stories')
        .where('expires_at', isGreaterThan: Timestamp.now())
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Story.fromMap(doc.data())).toList(),
        );
  }

  Future<void> createStory({
    XFile? mediaFile,
    required String content, // If text
    bool isRawContent = false,
    String type = 'image',
    String? caption,
    List<String> mentions = const [],
    String? linkUrl,
    String visibility = 'everyone',
    int? backgroundColor,
    int? textColor,
    String? fontFamily,
    String? textAlign,
    String? reshareAuthorId,
    String? reshareAuthorName,
    String? reshareStoryId,
  }) async {
    final uid = currentUserId;
    if (uid == null) return;

    // Stage 1 & 2: Moderation for caption and text content
    String textToModerate = [content, caption ?? ''].join(' ').trim();
    bool isSafe = true;

    if (textToModerate.isNotEmpty) {
      // Local Moderation (Fast)
      isSafe = !ProfanityFilter.hasProfanity(textToModerate);

      // AI Moderation (Robust)
      if (isSafe) {
        isSafe = await ModerationService.isContentSafe(textToModerate);
      }
    }

    final status = isSafe ? 'active' : 'flagged';

    // Fetch user details for denormalization
    final user = await _ref.read(userRepositoryProvider).getUserById(uid);
    if (user == null) return;

    String finalContent = content;
    if (mediaFile != null) {
      // Upload logic if mediaFile provided
      finalContent = type == 'video'
          ? await _storage.uploadVideo(mediaFile, path: 'stories/$uid/')
          : await _storage.uploadImage(mediaFile, path: 'stories/$uid/');
    }

    final id = _firestore.collection('stories').doc().id;
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(hours: 24));

    final story = Story(
      id: id,
      authorId: uid,
      content: finalContent,
      type: type,
      caption: caption,
      mentions: mentions,
      linkUrl: linkUrl,
      visibility: visibility,
      createdAt: now,
      expiresAt: expiresAt,
      viewers: [],
      likes: [],
      backgroundColor: backgroundColor,
      textColor: textColor,
      fontFamily: fontFamily,
      textAlign: textAlign,
      userName: user.displayName,
      userAvatar: user.avatarUrl ?? '',
      status: status,
      reshareAuthorId: reshareAuthorId,
      reshareAuthorName: reshareAuthorName,
      reshareStoryId: reshareStoryId,
    );

    await _firestore.collection('stories').doc(id).set(story.toMap());
  }

  Future<void> markAsViewed(String storyId) async {
    final uid = currentUserId;
    if (uid == null) return;

    await _firestore.collection('stories').doc(storyId).update({
      'viewers': FieldValue.arrayUnion([uid]),
    });
  }

  Future<void> likeStory(String storyId, {required bool isLiking}) async {
    final uid = currentUserId;
    if (uid == null) return;

    await _firestore.collection('stories').doc(storyId).update({
      'likes': isLiking ? FieldValue.arrayUnion([uid]) : FieldValue.arrayRemove([uid]),
    });
  }

  Future<void> deleteStory(String storyId) async {
    final uid = currentUserId;
    if (uid == null) return;
    // Optional: Verify authorId matches uid before deleting (Firestore rules should handle this but code check is good)
    await _firestore.collection('stories').doc(storyId).delete();
  }
}
