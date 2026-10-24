import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/post.dart';
import '../../auth/data/auth_repository.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/api_client.dart';
import '../../../core/utils/profanity_filter.dart';

final postRepositoryProvider = Provider<PostRepository>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return PostRepository(authRepo: authRepo);
});

final isPostLikedProvider = StreamProvider.family<bool, String>((ref, postId) {
  return ref.watch(postRepositoryProvider).watchPostLiked(postId);
});

final isPostSavedProvider = StreamProvider.family<bool, String>((ref, postId) {
  return ref.watch(postRepositoryProvider).watchPostSaved(postId);
});

final postProvider = StreamProvider.family<Post?, String>((ref, postId) {
  return ref.watch(postRepositoryProvider).watchPost(postId);
});

final savedPostsProvider = FutureProvider.family<List<Post>, String>((ref, userId) async {
  return ref.watch(postRepositoryProvider).getSavedPosts();
});

final userPostsProvider = FutureProvider.family<List<Post>, String>((ref, userId) async {
  return ref.watch(postRepositoryProvider).getUserPosts(userId);
});

final userMediaProvider = FutureProvider.family<List<Post>, String>((ref, userId) async {
  return ref.watch(postRepositoryProvider).getUserMedia(userId);
});

final userLikesProvider = FutureProvider.family<List<Post>, String>((ref, userId) async {
  return ref.watch(postRepositoryProvider).getUserLikes(userId);
});

final userRepliesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, userId) async {
  return ref.watch(postRepositoryProvider).getUserReplies(userId);
});

final trendingTagsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(postRepositoryProvider).getTrendingTags();
});

class PostPageResult {
  final List<Post> posts;
  final String? nextCursor;
  final bool hasMore;

  const PostPageResult({
    required this.posts,
    this.nextCursor,
    this.hasMore = false,
  });
}

class PostRepository {
  final AuthRepository? authRepo;
  PostRepository({this.authRepo});

  String? get currentUserId => authRepo?.currentUserId;

  static final Map<String, Post> _postsCache = {};
  static final StreamController<Map<String, Post>> _postsController =
      StreamController<Map<String, Post>>.broadcast();

  static final Map<String, bool> _savedPostsMap = {};
  static final Map<String, bool> _likedPostsMap = {};

  static final Map<String, List<Map<String, dynamic>>> _localComments = {};
  static final StreamController<Map<String, List<Map<String, dynamic>>>> _commentsController =
      StreamController<Map<String, List<Map<String, dynamic>>>>.broadcast();

  Map<String, dynamic> _normalizeCommentMap(Map<String, dynamic> raw) {
    final author = raw['author'] is Map ? raw['author'] as Map : {};
    final user = raw['user'] is Map ? raw['user'] as Map : {};

    final String authorId = (raw['authorId'] ??
            raw['author_id'] ??
            raw['userId'] ??
            raw['user_id'] ??
            author['id'] ??
            user['id'] ??
            '')
        .toString();

    final String authorName = (raw['authorName'] ??
            raw['author_name'] ??
            raw['userName'] ??
            raw['user_name'] ??
            author['fullName'] ??
            author['displayName'] ??
            user['fullName'] ??
            user['displayName'] ??
            'Student')
        .toString();

    final String authorHandle = (raw['authorHandle'] ??
            raw['author_handle'] ??
            raw['userHandle'] ??
            author['username'] ??
            user['username'] ??
            'student')
        .toString();

    final String? authorAvatarUrl = raw['authorAvatarUrl'] ??
        raw['author_avatar_url'] ??
        raw['userAvatar'] ??
        raw['user_avatar'] ??
        author['avatarUrl'] ??
        user['avatarUrl'];

    final String authorVerificationType = (raw['authorVerificationType'] ??
            raw['verificationType'] ??
            raw['verification_type'] ??
            author['verificationType'] ??
            'none')
        .toString();

    final bool isVerified = raw['authorIsVerified'] ??
        raw['isVerified'] ??
        raw['is_verified'] ??
        author['isVerified'] ??
        false;

    int timestamp = DateTime.now().millisecondsSinceEpoch;
    final rawTs = raw['timestamp'] ?? raw['time_stamp'];
    if (rawTs is int && rawTs > 0) {
      timestamp = rawTs;
    } else if (rawTs is String && rawTs.isNotEmpty) {
      final parsed = DateTime.tryParse(rawTs);
      if (parsed != null) timestamp = parsed.millisecondsSinceEpoch;
    } else {
      final createdAt = raw['createdAt'] ?? raw['created_at'];
      if (createdAt is String && createdAt.isNotEmpty) {
        final parsed = DateTime.tryParse(createdAt);
        if (parsed != null) timestamp = parsed.millisecondsSinceEpoch;
      }
    }

    final String commentId = (raw['id'] ?? raw['comment_id'] ?? DateTime.now().millisecondsSinceEpoch.toString()).toString();

    return {
      'id': commentId,
      'postId': (raw['postId'] ?? raw['post_id'] ?? '').toString(),
      'authorId': authorId,
      'authorName': authorName,
      'authorHandle': authorHandle.startsWith('@') ? authorHandle : '@$authorHandle',
      'authorAvatarUrl': authorAvatarUrl,
      'authorVerificationType': authorVerificationType,
      'authorIsVerified': isVerified,
      'content': (raw['content'] ?? raw['text'] ?? '').toString(),
      'parentId': raw['parentId'] ?? raw['parent_id'] ?? raw['parentCommentId'],
      'timestamp': timestamp,
      'createdAt': DateTime.fromMillisecondsSinceEpoch(timestamp).toIso8601String(),
      'likesCount': (raw['likesCount'] ?? raw['likes_count'] ?? raw['_count']?['likes'] ?? 0) as int,
      'isLiked': (raw['isLiked'] ?? raw['is_liked'] ?? false) as bool,
      'imageUrl': raw['imageUrl'] ?? raw['image_url'],
    };
  }

  Future<List<Post>> getPosts({int limit = 50}) async {
    try {
      final response = await ApiClient.get('/posts');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          final List list = data['data'];
          final posts = list.map((item) {
            var p = Post.fromMap(item as Map<String, dynamic>);
            if (_likedPostsMap.containsKey(p.id)) {
              final localLiked = _likedPostsMap[p.id]!;
              if (p.isLiked != localLiked) {
                final countDiff = localLiked ? (p.isLiked ? 0 : 1) : (p.isLiked ? -1 : 0);
                p = p.copyWith(isLiked: localLiked, likesCount: (p.likesCount + countDiff).clamp(0, 999999));
              }
            }
            if (_savedPostsMap.containsKey(p.id)) {
              final localSaved = _savedPostsMap[p.id]!;
              p = p.copyWith(savesCount: (p.savesCount + (localSaved ? 1 : 0)).clamp(0, 999999));
            }
            _postsCache[p.id] = p;
            return p;
          }).toList();
          return posts;
        }
      }
    } catch (e) {
      debugPrint('Error fetching posts from backend API: $e');
    }
    return _postsCache.values.toList();
  }

  Post? getPostSync(String postId) => _postsCache[postId];
  Post? getCachedPost(String postId) => _postsCache[postId];

  Stream<List<Post>> watchPosts({
    List<String> blockedUserIds = const [],
    int limit = 50,
  }) async* {
    final posts = await getPosts(limit: limit);
    yield posts;

    await for (final cache in _postsController.stream) {
      yield cache.values.toList();
    }
  }

  Future<Post?> getPost(String postId) async {
    try {
      final response = await ApiClient.get('/posts/$postId');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          var p = Post.fromMap(Map<String, dynamic>.from(data['data']));
          if (_likedPostsMap.containsKey(p.id)) {
            final localLiked = _likedPostsMap[p.id]!;
            if (p.isLiked != localLiked) {
              final countDiff = localLiked ? (p.isLiked ? 0 : 1) : (p.isLiked ? -1 : 0);
              p = p.copyWith(isLiked: localLiked, likesCount: (p.likesCount + countDiff).clamp(0, 999999));
            }
          }
          if (_savedPostsMap.containsKey(p.id)) {
            final localSaved = _savedPostsMap[p.id]!;
            p = p.copyWith(savesCount: (p.savesCount + (localSaved ? 1 : 0)).clamp(0, 999999));
          }
          _postsCache[p.id] = p;
          _postsController.add(Map<String, Post>.from(_postsCache));
          return p;
        }
      }
    } catch (e) {
      debugPrint('Error fetching single post $postId: $e');
    }
    return _postsCache[postId];
  }

  Stream<Post?> watchPost(String postId) async* {
    if (_postsCache.containsKey(postId)) {
      yield _postsCache[postId];
    } else {
      final fetched = await getPost(postId);
      yield fetched;
    }

    await for (final cache in _postsController.stream) {
      yield cache[postId];
    }
  }

  Stream<List<Post>> watchPostsByTag(String tag) async* {
    final posts = await getPosts();
    yield posts.where((p) => p.hashtags.contains(tag)).toList();
  }

  Future<List<Post>> getFollowingPosts({int limit = 50}) async {
    try {
      final response = await ApiClient.get('/posts/following?limit=$limit');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          final List list = data['data'];
          final posts = list.map((item) {
            var p = Post.fromMap(Map<String, dynamic>.from(item));
            if (_likedPostsMap.containsKey(p.id)) {
              final localLiked = _likedPostsMap[p.id]!;
              if (p.isLiked != localLiked) {
                final countDiff = localLiked ? (p.isLiked ? 0 : 1) : (p.isLiked ? -1 : 0);
                p = p.copyWith(isLiked: localLiked, likesCount: (p.likesCount + countDiff).clamp(0, 999999));
              }
            }
            if (_savedPostsMap.containsKey(p.id)) {
              final localSaved = _savedPostsMap[p.id]!;
              p = p.copyWith(savesCount: (p.savesCount + (localSaved ? 1 : 0)).clamp(0, 999999));
            }
            _postsCache[p.id] = p;
            return p;
          }).toList();
          return posts;
        }
      }
    } catch (e) {
      debugPrint('Error fetching following posts from backend API: $e');
    }
    return [];
  }

  Stream<List<Post>> watchFollowingPosts([dynamic arg1, dynamic arg2]) async* {
    final page = await fetchFeedPage(limit: 30, feedType: 'following');
    if (page.posts.isNotEmpty) {
      yield page.posts;
    } else {
      yield await getFollowingPosts();
    }
  }

  Stream<List<Post>> watchVideoPosts({int limit = 30}) async* {
    final page = await fetchVideoPostsPage(limit: limit);
    if (page.posts.isNotEmpty) {
      yield page.posts;
    } else {
      final posts = await getPosts();
      yield posts.where((p) =>
        p.mediaType == MediaType.video ||
        p.mediaUrl.toLowerCase().contains('.mp4') ||
        p.mediaUrl.toLowerCase().contains('.mov') ||
        p.mediaUrl.toLowerCase().contains('.webm')
      ).toList();
    }
  }

  Stream<List<Map<String, dynamic>>> watchComments(String postId) async* {
    // 1. Instant Cache-First: yield immediately if comments already cached in memory
    final cached = _localComments[postId];
    if (cached != null && cached.isNotEmpty) {
      final seenIds = <String>{};
      final list = <Map<String, dynamic>>[];
      for (final c in cached) {
        final id = c['id']?.toString() ?? '';
        if (id.isNotEmpty && !seenIds.contains(id)) {
          seenIds.add(id);
          list.add(_normalizeCommentMap(c));
        }
      }
      yield list;
    }

    try {
      final res = await ApiClient.get('/posts/$postId/comments').timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['data'] is List) {
          final List list = data['data'];
          final serverComments = list.map((e) => _normalizeCommentMap(Map<String, dynamic>.from(e))).toList();
          
          final existingLocal = _localComments[postId] ?? [];
          final serverIds = serverComments.map((c) => c['id'].toString()).toSet();
          
          // Keep only local pending comments that have not yet arrived on the server
          final pendingLocal = existingLocal.where((c) {
            final cId = c['id'].toString();
            if (serverIds.contains(cId)) return false;
            final isAlreadyOnServer = serverComments.any((sc) =>
              sc['authorId'] == c['authorId'] &&
              sc['content'] == c['content'] &&
              sc['parentId'] == c['parentId']
            );
            return !isAlreadyOnServer;
          }).toList();
          
          _localComments[postId] = [...serverComments, ...pendingLocal];
        }
      }
    } catch (_) {}

    // Yield updated deduplicated list
    final seenIds = <String>{};
    final initialList = <Map<String, dynamic>>[];
    for (final c in (_localComments[postId] ?? [])) {
      final id = c['id']?.toString() ?? '';
      if (id.isNotEmpty && !seenIds.contains(id)) {
        seenIds.add(id);
        initialList.add(_normalizeCommentMap(c));
      }
    }
    yield initialList;

    await for (final map in _commentsController.stream) {
      final streamSeen = <String>{};
      final streamList = <Map<String, dynamic>>[];
      for (final c in (map[postId] ?? [])) {
        final id = c['id']?.toString() ?? '';
        if (id.isNotEmpty && !streamSeen.contains(id)) {
          streamSeen.add(id);
          streamList.add(_normalizeCommentMap(c));
        }
      }
      yield streamList;
    }
  }

  Stream<List<Map<String, dynamic>>> watchReplies(String postId, String commentId) async* {
    final comments = _localComments[postId] ?? [];
    final replies = comments.where((c) => c['parentId'] == commentId).toList();
    yield replies;

    await for (final map in _commentsController.stream) {
      final updated = map[postId] ?? [];
      yield updated.where((c) => c['parentId'] == commentId).toList();
    }
  }

  Stream<bool> watchPostLiked(String postId) async* {
    yield isPostLikedSync(postId);
    await for (final cache in _postsController.stream) {
      if (cache.containsKey(postId)) {
        yield cache[postId]!.isLiked;
      }
    }
  }

  bool isPostLikedSync(String postId) {
    return _likedPostsMap[postId] ?? _postsCache[postId]?.isLiked ?? false;
  }

  Future<bool> isPostLiked(String postId) async {
    return isPostLikedSync(postId);
  }

  Stream<bool> watchPostSaved(String postId) async* {
    yield isPostSavedSync(postId);
    await for (final cache in _postsController.stream) {
      if (cache.containsKey(postId)) {
        yield cache[postId]!.isSaved;
      }
    }
  }

  bool isPostSavedSync(String postId) {
    return _savedPostsMap[postId] ?? _postsCache[postId]?.isSaved ?? false;
  }

  Future<bool> isPostSaved(String postId) async {
    return isPostSavedSync(postId);
  }

  Future<List<Post>> getSavedPosts() async {
    try {
      final response = await ApiClient.get('/posts/saved');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          final List list = data['data'];
          return list.map((item) => Post.fromMap(item as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching saved posts from backend API: $e');
    }
    final savedIds = _savedPostsMap.entries.where((e) => e.value).map((e) => e.key).toSet();
    return _postsCache.values.where((p) => savedIds.contains(p.id)).toList();
  }

  Future<List<Post>> getUserPosts(String userId) async {
    try {
      final response = await ApiClient.get('/posts/user/$userId');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          final List list = data['data'];
          return list.map((item) => Post.fromMap(item as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching user posts from backend API: $e');
    }
    return _postsCache.values.where((p) => p.authorId == userId).toList();
  }

  Future<void> addPost(Post post) async {
    bool isSafe = true;
    if (post.content.isNotEmpty) {
      isSafe = await ProfanityFilter.isTextSafe(post.content);
    }
    if (isSafe && post.mediaUrl.isNotEmpty) {
      isSafe = await ProfanityFilter.isMediaSafe(post.mediaUrl, mediaType: post.mediaType.name);
    }
    if (isSafe && post.allMediaUrls.isNotEmpty) {
      for (final mUrl in post.allMediaUrls) {
        if (!isSafe) break;
        if (mUrl.isNotEmpty) {
          isSafe = await ProfanityFilter.isMediaSafe(mUrl, mediaType: post.mediaType.name);
        }
      }
    }

    if (!isSafe && AppConfig.blockFlaggedPosts) {
      throw Exception('Content violates community guidelines and cannot be posted.');
    }

    final payload = {
      'content': post.content,
      'mediaUrl': post.mediaUrl,
      'mediaUrls': post.allMediaUrls,
      'mediaType': post.mediaType.name,
      'channelId': post.channelId,
      'isAnonymous': post.isAnonymous,
      'visibility': post.visibility,
      'replyPermission': post.replyPermission,
      'pollData': post.pollData,
    };

    final res = await ApiClient.post('/posts', payload);
    if (res.statusCode == 200 || res.statusCode == 201) {
      try {
        final data = jsonDecode(res.body);
        if (data['data'] != null) {
          final created = Post.fromMap(data['data']);
          _postsCache[created.id] = created;
          _postsController.add(_postsCache);
        }
      } catch (_) {}
    } else {
      try {
        final errData = jsonDecode(res.body);
        if (errData is Map && errData['error'] != null) {
          throw Exception(errData['error']);
        }
      } catch (e) {
        if (e is Exception && !e.toString().contains('Failed to create post')) rethrow;
      }
      throw Exception('Failed to create post: ${res.body}');
    }
  }

  Future<void> toggleLike(String postId) async {
    final currentLiked = isPostLikedSync(postId);
    final newLiked = !currentLiked;
    _likedPostsMap[postId] = newLiked;

    if (_postsCache.containsKey(postId)) {
      final p = _postsCache[postId]!;
      final newCount = (p.likesCount + (newLiked ? 1 : -1)).clamp(0, 999999);
      _postsCache[postId] = p.copyWith(isLiked: newLiked, likesCount: newCount);
      _postsController.add(Map<String, Post>.from(_postsCache));
    } else {
      _postsController.add(Map<String, Post>.from(_postsCache));
    }

    try {
      final res = await ApiClient.post('/posts/$postId/like', {});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['isLiked'] != null) {
          final bool serverIsLiked = data['isLiked'] == true;
          _likedPostsMap[postId] = serverIsLiked;
          if (_postsCache.containsKey(postId)) {
            final p = _postsCache[postId]!;
            _postsCache[postId] = p.copyWith(isLiked: serverIsLiked);
            _postsController.add(Map<String, Post>.from(_postsCache));
          }
        }
      }
    } catch (e) {
      debugPrint('Error toggling like: $e');
    }
  }

  /// Record user behavioral interaction signals (view, like, save, share, watch_complete, skip, not_interested)
  Future<void> recordInteraction(String postId, String action) async {
    try {
      await ApiClient.post('/posts/$postId/interact', {'action': action});
    } catch (_) {}
  }

  Future<void> addComment(String postId, String text, {String? parentId, String? parentCommentId}) async {
    final user = authRepo?.currentUser;
    final String tempCommentId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final DateTime now = DateTime.now();

    final newComment = _normalizeCommentMap({
      'id': tempCommentId,
      'postId': postId,
      'authorId': user?.uid ?? 'anon',
      'authorName': user?.displayName ?? 'Student',
      'authorHandle': user?.handle ?? 'student',
      'authorAvatarUrl': user?.avatarUrl,
      'authorVerificationType': user?.verificationType ?? 'none',
      'authorIsVerified': user?.isVerified ?? false,
      'content': text,
      'parentId': parentId ?? parentCommentId,
      'timestamp': now.millisecondsSinceEpoch,
      'createdAt': now.toIso8601String(),
      'likesCount': 0,
      'isLiked': false,
    });

    _localComments.putIfAbsent(postId, () => []).add(newComment);
    _commentsController.add(Map.from(_localComments));

    // Update Post comment count instantly
    if (_postsCache.containsKey(postId)) {
      final p = _postsCache[postId]!;
      _postsCache[postId] = p.copyWith(commentsCount: p.commentsCount + 1);
      _postsController.add(Map<String, Post>.from(_postsCache));
    }

    try {
      final res = await ApiClient.post('/posts/$postId/comment', {
        'content': text,
        'parentCommentId': parentId ?? parentCommentId,
      });
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        if (data['data'] != null) {
          final serverComment = _normalizeCommentMap(Map<String, dynamic>.from(data['data']));
          final list = _localComments[postId];
          if (list != null) {
            final idx = list.indexWhere((c) => c['id'] == tempCommentId);
            if (idx != -1) {
              list[idx] = serverComment;
            } else {
              if (!list.any((c) => c['id'] == serverComment['id'])) {
                list.add(serverComment);
              }
            }
            _commentsController.add(Map.from(_localComments));
          }
        }
      }
    } catch (e) {
      debugPrint('Error posting comment: $e');
    }
  }

  Future<void> editComment(String postId, String commentId, String newContent) async {
    if (_localComments.containsKey(postId)) {
      final list = _localComments[postId]!;
      final idx = list.indexWhere((c) => c['id'] == commentId);
      if (idx != -1) {
        list[idx]['content'] = newContent;
        _commentsController.add(Map.from(_localComments));
      }
    }

    try {
      await ApiClient.post('/posts/$postId/comment/$commentId', {
        'content': newContent,
      });
    } catch (e) {
      debugPrint('Error editing comment: $e');
    }
  }

  Future<void> toggleCommentLike(String postId, String commentId) async {
    if (_localComments.containsKey(postId)) {
      final list = _localComments[postId]!;
      final idx = list.indexWhere((c) => c['id'] == commentId);
      if (idx != -1) {
        final currentLiked = list[idx]['isLiked'] == true;
        final newLiked = !currentLiked;
        final currentLikes = (list[idx]['likesCount'] as int? ?? 0);
        final newCount = (currentLikes + (newLiked ? 1 : -1)).clamp(0, 999999);

        list[idx]['isLiked'] = newLiked;
        list[idx]['likesCount'] = newCount;
        _commentsController.add(Map.from(_localComments));
      }
    }

    try {
      await ApiClient.post('/posts/$postId/comment/$commentId/like', {});
    } catch (e) {
      debugPrint('Error toggling comment like: $e');
    }
  }

  Future<void> deleteComment(dynamic arg1, [dynamic arg2]) async {
    final postId = arg1 is String ? arg1 : null;
    final commentId = arg2 is String ? arg2 : null;
    if (postId != null && commentId != null && _localComments.containsKey(postId)) {
      _localComments[postId]!.removeWhere((c) => c['id'] == commentId);
      _commentsController.add(Map.from(_localComments));

      if (_postsCache.containsKey(postId)) {
        final p = _postsCache[postId]!;
        _postsCache[postId] = p.copyWith(commentsCount: (p.commentsCount - 1).clamp(0, 999999));
        _postsController.add(Map<String, Post>.from(_postsCache));
      }

      try {
        await ApiClient.delete('/posts/$postId/comment/$commentId');
      } catch (e) {
        debugPrint('Error deleting comment: $e');
      }
    }
  }

  Future<void> deletePost(String postId) async {
    _postsCache.remove(postId);
    _postsController.add(Map<String, Post>.from(_postsCache));
    await ApiClient.delete('/posts/$postId');
  }

  Future<void> repost(dynamic postOrId, [dynamic arg2]) async {
    final Post? originalPost = postOrId is Post ? postOrId : _postsCache[postOrId.toString()];
    final String? commentText = arg2 is String ? arg2 : null;
    final String postId = originalPost?.id ?? postOrId.toString();

    // 1. Increment repost count on original post
    if (_postsCache.containsKey(postId)) {
      final p = _postsCache[postId]!;
      _postsCache[postId] = p.copyWith(repostCount: p.repostCount + 1);
    }

    // 2. Insert new Repost item into feed stream
    final user = authRepo?.currentUser;
    if (originalPost != null) {
      final String repostId = 'repost_${DateTime.now().millisecondsSinceEpoch}';
      final newRepostPost = Post(
        id: repostId,
        authorId: user?.uid ?? 'anon',
        authorName: user?.displayName ?? 'Student',
        authorHandle: user?.handle ?? '@student',
        authorAvatarUrl: user?.avatarUrl,
        content: commentText ?? '',
        timestamp: DateTime.now(),
        isVerified: user?.isVerified ?? false,
        verificationType: user?.verificationType ?? 'none',
        repostData: {
          'id': originalPost.id,
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
        },
      );

      final Map<String, Post> updatedCache = {
        repostId: newRepostPost,
        ..._postsCache,
      };
      _postsCache.clear();
      _postsCache.addAll(updatedCache);
      _postsController.add(Map<String, Post>.from(_postsCache));
    } else {
      _postsController.add(Map<String, Post>.from(_postsCache));
    }

    try {
      final res = await ApiClient.post('/posts/$postId/repost', {
        if (commentText != null && commentText.isNotEmpty) 'content': commentText,
      });
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['data'] != null) {
          final serverRepost = Post.fromMap(data['data']);
          final Map<String, Post> updatedCache = {
            serverRepost.id: serverRepost,
            ..._postsCache,
          };
          _postsCache.clear();
          _postsCache.addAll(updatedCache);
          _postsController.add(Map<String, Post>.from(_postsCache));
        }
      }
    } catch (e) {
      debugPrint('Error posting repost: $e');
    }
  }

  Future<void> incrementShareCount(String postId) async {
    if (_postsCache.containsKey(postId)) {
      final p = _postsCache[postId]!;
      _postsCache[postId] = p.copyWith(sharesCount: p.sharesCount + 1);
      _postsController.add(_postsCache);
    }
    try {
      await ApiClient.post('/posts/$postId/share', {});
    } catch (_) {}
  }

  Future<void> togglePostSave(String postId) async {
    final currentSaved = isPostSavedSync(postId);
    final newSaved = !currentSaved;
    _savedPostsMap[postId] = newSaved;

    if (_postsCache.containsKey(postId)) {
      final p = _postsCache[postId]!;
      final newCount = (p.savesCount + (newSaved ? 1 : -1)).clamp(0, 999999);
      _postsCache[postId] = p.copyWith(savesCount: newCount, isSaved: newSaved);
      _postsController.add(Map<String, Post>.from(_postsCache));
    } else {
      _postsController.add(Map<String, Post>.from(_postsCache));
    }

    try {
      final res = await ApiClient.post('/posts/$postId/save', {});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['isSaved'] != null) {
          final bool serverSaved = data['isSaved'] == true;
          _savedPostsMap[postId] = serverSaved;
          if (_postsCache.containsKey(postId)) {
            final p = _postsCache[postId]!;
            _postsCache[postId] = p.copyWith(isSaved: serverSaved);
            _postsController.add(Map<String, Post>.from(_postsCache));
          }
        }
      }
    } catch (e) {
      debugPrint('Error toggling post save: $e');
    }
  }

  Future<PostPageResult> fetchFeedPage({
    String? cursor,
    int limit = 15,
    String feedType = 'foryou',
    String? channel,
  }) async {
    try {
      final queryParams = <String, String>{
        'feed': feedType,
        'limit': limit.toString(),
      };
      if (cursor != null && cursor.isNotEmpty) {
        queryParams['cursor'] = cursor;
      }
      if (channel != null && channel.isNotEmpty && channel != 'all') {
        queryParams['channel'] = channel;
      }
      final queryString = Uri(queryParameters: queryParams).query;
      final response = await ApiClient.get('/posts?$queryString');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          final List list = data['data'];
          final posts = list.map((item) {
            var p = Post.fromMap(Map<String, dynamic>.from(item));
            if (_likedPostsMap.containsKey(p.id)) {
              final localLiked = _likedPostsMap[p.id]!;
              if (p.isLiked != localLiked) {
                final countDiff = localLiked ? (p.isLiked ? 0 : 1) : (p.isLiked ? -1 : 0);
                p = p.copyWith(isLiked: localLiked, likesCount: (p.likesCount + countDiff).clamp(0, 999999));
              }
            }
            if (_savedPostsMap.containsKey(p.id)) {
              final localSaved = _savedPostsMap[p.id]!;
              p = p.copyWith(savesCount: (p.savesCount + (localSaved ? 1 : 0)).clamp(0, 999999));
            }
            _postsCache[p.id] = p;
            return p;
          }).toList();

          final nextCursor = data['nextCursor'] as String?;
          final hasMore = (data['hasMore'] as bool?) ?? (nextCursor != null);

          return PostPageResult(
            posts: posts,
            nextCursor: nextCursor,
            hasMore: hasMore,
          );
        }
      }
    } catch (e) {
      debugPrint('Error fetching feed page: $e');
    }
    return const PostPageResult(posts: [], nextCursor: null, hasMore: false);
  }

  Future<PostPageResult> fetchFollowingPostsPage({String? cursor, int limit = 15}) async {
    return fetchFeedPage(cursor: cursor, limit: limit, feedType: 'following');
  }

  Future<PostPageResult> fetchDiscoveryPostsPage({String? cursor, int limit = 15}) async {
    return fetchFeedPage(cursor: cursor, limit: limit, feedType: 'foryou');
  }

  Future<PostPageResult> fetchVideoPostsPage({String? cursor, int limit = 15}) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
      };
      if (cursor != null && cursor.isNotEmpty) {
        queryParams['cursor'] = cursor;
      }
      final queryString = Uri(queryParameters: queryParams).query;
      final response = await ApiClient.get('/posts/videos?$queryString');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          final List list = data['data'];
          final posts = list.map((item) {
            var p = Post.fromMap(Map<String, dynamic>.from(item));
            if (_likedPostsMap.containsKey(p.id)) {
              final localLiked = _likedPostsMap[p.id]!;
              if (p.isLiked != localLiked) {
                final countDiff = localLiked ? (p.isLiked ? 0 : 1) : (p.isLiked ? -1 : 0);
                p = p.copyWith(isLiked: localLiked, likesCount: (p.likesCount + countDiff).clamp(0, 999999));
              }
            }
            if (_savedPostsMap.containsKey(p.id)) {
              final localSaved = _savedPostsMap[p.id]!;
              p = p.copyWith(savesCount: (p.savesCount + (localSaved ? 1 : 0)).clamp(0, 999999));
            }
            _postsCache[p.id] = p;
            return p;
          }).toList();

          final nextCursor = data['nextCursor'] as String?;
          final hasMore = (data['hasMore'] as bool?) ?? (nextCursor != null);

          return PostPageResult(
            posts: posts,
            nextCursor: nextCursor,
            hasMore: hasMore,
          );
        }
      }
    } catch (e) {
      debugPrint('Error fetching video posts page: $e');
    }
    return const PostPageResult(posts: [], nextCursor: null, hasMore: false);
  }

  Future<PostPageResult> fetchChannelPostsPage({String? cursor, int limit = 15, required String channelId}) async {
    return fetchFeedPage(cursor: cursor, limit: limit, feedType: 'foryou');
  }

  Future<Map<String, dynamic>?> votePoll(String postId, int optionIndex) async {
    try {
      final response = await ApiClient.post('/posts/$postId/poll-vote', {'optionIndex': optionIndex});
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final poll = body['data'] ?? body['pollData'];
        if (poll is Map) {
          final pollMap = Map<String, dynamic>.from(poll);
          if (_postsCache.containsKey(postId)) {
            final oldPost = _postsCache[postId]!;
            final updatedPost = oldPost.copyWith(pollData: pollMap);
            _postsCache[postId] = updatedPost;
            _postsController.add(_postsCache);
          }
          return pollMap;
        }
      }
    } catch (e) {
      debugPrint('Error voting on poll: $e');
    }
    return null;
  }

  Future<void> incrementViewCount(String postId) async {
    try {
      await ApiClient.post('/posts/$postId/view', {});
    } catch (_) {}
  }

  Future<void> trackReelWatchMetrics({
    dynamic postId,
    int? watchedMs,
    double? completionRate,
    int? replayCount,
    bool? skippedQuickly,
    bool? completed,
    String? source,
  }) async {
    try {
      final pid = postId?.toString();
      if (pid == null || pid.isEmpty) return;
      await ApiClient.post('/posts/$pid/watch', {
        'watchedMs': watchedMs ?? 0,
        'durationMs': watchedMs ?? 0,
        'completionRate': completionRate ?? 0.0,
        'replayCount': replayCount ?? 0,
        'skippedQuickly': skippedQuickly ?? false,
        'completed': completed ?? false,
        'source': source ?? 'reels',
      });
    } catch (e) {
      debugPrint('Error sending watch metrics: $e');
    }
  }

  Future<List<Post>> getUserLikes(String userId) async {
    try {
      final response = await ApiClient.get('/posts/user/$userId/likes');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          final List list = data['data'];
          return list.map((item) => Post.fromMap(item as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching user likes from backend API: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getUserReplies(String userId) async {
    try {
      final response = await ApiClient.get('/posts/user/$userId/replies');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          final List list = data['data'];
          return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching user replies from backend API: $e');
    }
    return [];
  }

  Future<List<Post>> getUserMedia(String userId) async {
    try {
      final response = await ApiClient.get('/posts/user/$userId/media');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          final List list = data['data'];
          return list.map((item) => Post.fromMap(item as Map<String, dynamic>)).toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching user media from backend API: $e');
    }
    final posts = await getUserPosts(userId);
    return posts.where((p) => p.mediaUrl.isNotEmpty).toList();
  }

  Stream<List<Post>> watchUserPosts(String userId) {
    return Stream.fromFuture(getUserPosts(userId));
  }

  Stream<List<Map<String, dynamic>>> watchUserReplies(String userId) {
    return Stream.fromFuture(getUserReplies(userId));
  }

  Stream<List<Post>> watchUserLikes(String userId) {
    return Stream.fromFuture(getUserLikes(userId));
  }

  Stream<List<Post>> watchUserMedia(String userId) {
    return Stream.fromFuture(getUserMedia(userId));
  }

  Future<List<Map<String, dynamic>>> getTrendingTags() async {
    try {
      final res = await ApiClient.get('/posts/trending-tags');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['data'] is List) {
          return (data['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching trending tags from API: $e');
    }

    // Dynamic extraction fallback from cached posts
    final Map<String, int> counts = {};
    for (final p in _postsCache.values) {
      for (final tag in p.hashtags) {
        final clean = tag.replaceAll('#', '').trim().toLowerCase();
        if (clean.isNotEmpty) {
          counts[clean] = (counts[clean] ?? 0) + 1 + (p.likesCount ~/ 5);
        }
      }
      final matches = RegExp(r'#([a-zA-Z0-9_]+)').allMatches(p.content);
      for (final m in matches) {
        final clean = m.group(1)!.toLowerCase();
        if (clean.isNotEmpty) {
          counts[clean] = (counts[clean] ?? 0) + 1;
        }
      }
    }

    if (counts.isNotEmpty) {
      final list = counts.entries.map((e) => {
        'tag': '#${e.key}',
        'name': e.key,
        'count': e.value,
      }).toList();
      list.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      return list.take(12).toList();
    }

    // Default fallback tags
    return [
      {'tag': '#ABUAD', 'count': 28},
      {'tag': '#Trending', 'count': 19},
      {'tag': '#CampusLife', 'count': 15},
      {'tag': '#Tech', 'count': 12},
      {'tag': '#Sports', 'count': 9},
      {'tag': '#News', 'count': 8},
      {'tag': '#Engineering', 'count': 6},
    ];
  }

  Stream<List<Post>> watchSuggestedPosts() async* {
    try {
      final res = await ApiClient.get('/posts?limit=30');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['data'] is List) {
          final posts = (data['data'] as List)
              .map((item) => Post.fromMap(item as Map<String, dynamic>))
              .toList();
          for (final p in posts) {
            _postsCache[p.id] = p;
          }
          yield posts;
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching suggested posts: $e');
    }

    if (_postsCache.isNotEmpty) {
      yield _postsCache.values.toList();
    } else {
      yield [];
    }
  }

  Future<List<Post>> searchPosts(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    try {
      final encoded = Uri.encodeComponent(cleanQuery);
      final res = await ApiClient.get('/posts/search?q=$encoded');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['data'] is List) {
          final posts = (data['data'] as List)
              .map((item) => Post.fromMap(item as Map<String, dynamic>))
              .toList();
          for (final p in posts) {
            _postsCache[p.id] = p;
          }
          return posts;
        }
      }
    } catch (e) {
      debugPrint('Error searching posts: $e');
    }

    // Cache-based fallback search
    final q = cleanQuery.toLowerCase();
    final rawTag = q.replaceAll('#', '');
    return _postsCache.values.where((p) {
      final content = p.content.toLowerCase();
      final author = p.authorName.toLowerCase();
      final handle = p.authorHandle.toLowerCase();
      final tags = p.hashtags.map((t) => t.toLowerCase()).toList();

      return content.contains(q) ||
          content.contains(rawTag) ||
          author.contains(q) ||
          handle.contains(q) ||
          tags.any((t) => t.contains(q) || t.contains(rawTag));
    }).toList();
  }
}


