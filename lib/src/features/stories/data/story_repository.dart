import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/moderation_service.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/story.dart';

final storyRepositoryProvider = Provider<StoryRepository>((ref) {
  return StoryRepository(ref);
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
  final Ref _ref;

  StoryRepository(this._ref);

  String? get currentUserId =>
      _ref.read(authRepositoryProvider).currentUser?.uid ??
      _ref.read(authRepositoryProvider).currentUserId;

  Stream<List<Story>> watchActiveStories() async* {
    try {
      final response = await ApiClient.get('/stories');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          yield (data['data'] as List).map((x) => Story.fromMap(x)).toList();
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching active stories: $e');
    }
    yield [];
  }

  Future<void> createStory({
    XFile? mediaFile,
    required String content,
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
    if (uid == null) throw Exception('User not authenticated');

    var user = await _ref.read(userRepositoryProvider).getUserById(uid);
    user ??= _ref.read(authRepositoryProvider).currentUser;
    if (user == null) throw Exception('User profile details not found');

    String finalContent = content;
    if (mediaFile != null) {
      try {
        final bytes = await mediaFile.readAsBytes();
        final uploadedUrl = await ApiClient.uploadBytes(
          bytes,
          mediaFile.name.isNotEmpty ? mediaFile.name : 'story_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
          finalContent = uploadedUrl;
        } else {
          finalContent = mediaFile.path;
        }
      } catch (e) {
        debugPrint('Error uploading story media: $e');
        finalContent = mediaFile.path;
      }
    }

    if (caption != null && caption.isNotEmpty) {
      final isTextSafe = await ModerationService.isContentSafe(caption);
      if (!isTextSafe && AppConfig.blockFlaggedPosts) {
        throw Exception('Story caption violates community guidelines.');
      }
    }

    if (finalContent.isNotEmpty) {
      final isMediaSafe = await ModerationService.isMediaSafe(finalContent, mediaType: type);
      if (!isMediaSafe && AppConfig.blockFlaggedPosts) {
        throw Exception('Story media violates community guidelines.');
      }
    }

    final id = 'story_${DateTime.now().millisecondsSinceEpoch}';
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
      status: 'active',
      reshareAuthorId: reshareAuthorId,
      reshareAuthorName: reshareAuthorName,
      reshareStoryId: reshareStoryId,
    );

    await ApiClient.post('/stories', story.toMap());
    _ref.invalidate(activeStoriesProvider);
  }

  Future<void> markAsViewed(String storyId) async {
    try {
      await ApiClient.post('/stories/$storyId/view', {});
      _ref.invalidate(activeStoriesProvider);
    } catch (e) {
      debugPrint('Error marking story viewed: $e');
    }
  }

  Future<void> likeStory(String storyId, {required bool isLiking}) async {
    try {
      await ApiClient.post('/stories/$storyId/like', {'isLiking': isLiking});
      _ref.invalidate(activeStoriesProvider);
    } catch (e) {
      debugPrint('Error liking story: $e');
    }
  }

  Future<void> deleteStory(String storyId) async {
    try {
      await ApiClient.delete('/stories/$storyId');
      _ref.invalidate(activeStoriesProvider);
    } catch (e) {
      debugPrint('Error deleting story: $e');
    }
  }
}
