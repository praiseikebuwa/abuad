import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:video_player/video_player.dart';
import '../../domain/post.dart';

/// State containing our active video controllers.
class ReelControllerState {
  final Map<String, VideoPlayerController> controllers;
  final Map<String, String> errors;

  ReelControllerState({
    required this.controllers,
    this.errors = const {},
  });

  ReelControllerState copyWith({
    Map<String, VideoPlayerController>? controllers,
    Map<String, String>? errors,
  }) {
    return ReelControllerState(
      controllers: controllers ?? this.controllers,
      errors: errors ?? this.errors,
    );
  }
}

class ReelControllerManager extends Notifier<ReelControllerState> {
  static const int _preloadAhead = 2;
  static const int _preloadBehind = 1;
  static final CacheManager _cacheManager = CacheManager(
    Config(
      'reelsVideoCache',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 120,
    ),
  );
  final Set<String> _initializingIds = <String>{};
  final Map<String, StreamSubscription<FileResponse>> _cacheSubscriptions = {};

  @override
  ReelControllerState build() {
    ref.onDispose(() {
      for (final controller in state.controllers.values) {
        controller.dispose();
      }
      for (final subscription in _cacheSubscriptions.values) {
        subscription.cancel();
      }
      _cacheSubscriptions.clear();
    });
    return ReelControllerState(controllers: {});
  }

  /// Updates the preloading window based on the current index.
  Future<void> updateConfig(int currentIndex, List<Post> posts) async {
    if (posts.isEmpty) return;

    final activeIds = <String>{};
    final start = (currentIndex - _preloadBehind).clamp(0, posts.length - 1);
    final end = (currentIndex + _preloadAhead).clamp(0, posts.length - 1);

    // 1. Identify which posts should have controllers
    for (int i = start; i <= end; i++) {
      activeIds.add(posts[i].id);
    }

    // 2. Dispose and remove controllers for posts outside the window
    final updatedControllers = Map<String, VideoPlayerController>.from(state.controllers);
    final updatedErrors = Map<String, String>.from(state.errors);

    final toRemove = updatedControllers.keys.where((id) => !activeIds.contains(id)).toList();
    for (final id in toRemove) {
      final controller = updatedControllers[id];
      if (controller != null) {
        if (controller.value.isPlaying) {
          controller.pause();
        }
        controller.dispose();
      }
      updatedControllers.remove(id);
      updatedErrors.remove(id);
      _initializingIds.remove(id);
      _cacheSubscriptions.remove(id)?.cancel();
    }

    state = state.copyWith(controllers: updatedControllers, errors: updatedErrors);

    // 3. Initialize missing controllers for posts in the window
    for (int i = start; i <= end; i++) {
      final post = posts[i];
      _ensureControllerForPost(post);
    }
  }

  Future<void> _ensureControllerForPost(Post post) async {
    if (post.mediaUrl.isEmpty) return;
    if (state.controllers.containsKey(post.id) || _initializingIds.contains(post.id)) return;

    _initializingIds.add(post.id);

    // Create and register controller immediately so the UI tree gets a valid controller on frame 0
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(post.mediaUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );

    state = state.copyWith(
      controllers: Map<String, VideoPlayerController>.from(state.controllers)..[post.id] = controller,
    );

    // Background disk cache prime
    _primeDiskCache(post.id, post.mediaUrl);

    // Kick off initialization immediately
    _initController(post.id, controller);
  }

  void _primeDiskCache(String postId, String mediaUrl) {
    if (_cacheSubscriptions.containsKey(postId)) return;
    _cacheSubscriptions[postId] = _cacheManager
        .getFileStream(mediaUrl, withProgress: true)
        .listen(
      (_) {},
      onError: (e) {
        debugPrint('Cache prime failed for $postId: $e');
      },
      onDone: () {
        _cacheSubscriptions.remove(postId);
      },
      cancelOnError: false,
    );
  }

  Future<void> _initController(String postId, VideoPlayerController controller) async {
    try {
      await controller.initialize();
      await controller.setLooping(true);
      // We don't play here; the individual page will handle play/pause
    } catch (e) {
      debugPrint('Error preloading video $postId: $e');
      if (ref.mounted) {
        state = state.copyWith(
          errors: Map<String, String>.from(state.errors)..[postId] = e.toString(),
        );
      }
    } finally {
      _initializingIds.remove(postId);
    }
  }

  /// Manually retry a failed initialization
  Future<void> retry(Post post) async {
    final updatedControllers = Map<String, VideoPlayerController>.from(state.controllers);
    updatedControllers.remove(post.id)?.dispose();
    _cacheSubscriptions.remove(post.id)?.cancel();
    _initializingIds.remove(post.id);

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(post.mediaUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    if (!ref.mounted) {
      await controller.dispose();
      return;
    }

    state = state.copyWith(
      controllers: updatedControllers..[post.id] = controller,
      errors: Map<String, String>.from(state.errors)..remove(post.id),
    );

    _initializingIds.add(post.id);
    _initController(post.id, controller);
  }
}

final reelControllerProvider = NotifierProvider<ReelControllerManager, ReelControllerState>(
  ReelControllerManager.new,
);
