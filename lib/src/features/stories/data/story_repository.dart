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
  final authRepo = ref.watch(authRepositoryProvider);
  return StoryRepository(authRepo: authRepo);
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
  final AuthRepository authRepo;

  StoryRepository({required this.authRepo});

  final StreamController<List<Story>> _storiesController =
      StreamController<List<Story>>.broadcast();
  List<Story> _cachedStories = [];
  Timer? _pollingTimer;

  String? get currentUserId =>
      authRepo.currentUser?.uid ?? authRepo.currentUserId;

  Stream<List<Story>> watchActiveStories() {
    fetchStories();

    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      fetchStories();
    });

    if (_cachedStories.isNotEmpty) {
      return Stream.value(_cachedStories).concatWith([_storiesController.stream]);
    }
    return _storiesController.stream;
  }

  Future<List<Story>> fetchStories() async {
    try {
      final response = await ApiClient.get('/stories');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          final stories = (data['data'] as List).map((x) => Story.fromMap(x)).toList();
          _cachedStories = stories;
          if (!_storiesController.isClosed) {
            _storiesController.add(stories);
          }
          return stories;
        }
      }
    } catch (e) {
      debugPrint('Error fetching active stories: $e');
    }
    return _cachedStories;
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
    final user = authRepo.currentUser;
    final uid = user?.uid ?? currentUserId;
    if (uid == null) throw Exception('User not authenticated');

    String finalContent = content;
    if (mediaFile != null) {
      try {
        final bytes = await mediaFile.readAsBytes();
        final uploadedUrl = await ApiClient.uploadBytes(
          bytes,
          mediaFile.name.isNotEmpty
              ? mediaFile.name
              : 'story_${DateTime.now().millisecondsSinceEpoch}.jpg',
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
      userName: user?.displayName ?? 'Student',
      userAvatar: user?.avatarUrl ?? '',
      status: 'active',
      reshareAuthorId: reshareAuthorId,
      reshareAuthorName: reshareAuthorName,
      reshareStoryId: reshareStoryId,
    );

    final res = await ApiClient.post('/stories', story.toMap());
    if (res.statusCode != 200 && res.statusCode != 201) {
      final err = jsonDecode(res.body);
      throw Exception(err['error'] ?? err['message'] ?? 'Failed to post story');
    }

    await fetchStories();
  }

  Future<void> markAsViewed(String storyId) async {
    try {
      await ApiClient.post('/stories/$storyId/view', {});
      await fetchStories();
    } catch (e) {
      debugPrint('Error marking story viewed: $e');
    }
  }

  Future<void> likeStory(String storyId, {required bool isLiking}) async {
    try {
      await ApiClient.post('/stories/$storyId/like', {'isLiking': isLiking});
      await fetchStories();
    } catch (e) {
      debugPrint('Error liking story: $e');
    }
  }

  Future<void> deleteStory(String storyId) async {
    try {
      await ApiClient.delete('/stories/$storyId');
      await fetchStories();
    } catch (e) {
      debugPrint('Error deleting story: $e');
    }
  }
}

extension _StreamConcat<T> on Stream<T> {
  Stream<T> concatWith(Iterable<Stream<T>> otherStreams) async* {
    yield* this;
    for (final s in otherStreams) {
      yield* s;
    }
  }
}
