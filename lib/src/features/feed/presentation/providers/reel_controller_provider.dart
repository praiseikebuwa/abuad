import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  @override
  ReelControllerState build() {
    ref.onDispose(() {
      for (final controller in state.controllers.values) {
        controller.dispose();
      }
    });
    return ReelControllerState(controllers: {});
  }

  /// Updates the preloading window based on the current index.
  Future<void> updateConfig(int currentIndex, List<Post> posts) async {
    if (posts.isEmpty) return;

    final activeIds = <String>{};
    const windowSize = 2; // Preload 2 ahead, 1 behind

    final start = (currentIndex - 1).clamp(0, posts.length - 1);
    final end = (currentIndex + windowSize).clamp(0, posts.length - 1);

    // 1. Identify which posts should have controllers
    for (int i = start; i <= end; i++) {
      activeIds.add(posts[i].id);
    }

    // 2. Dispose and remove controllers for posts outside the window
    final updatedControllers = Map<String, VideoPlayerController>.from(state.controllers);
    final updatedErrors = Map<String, String>.from(state.errors);

    final toRemove = updatedControllers.keys.where((id) => !activeIds.contains(id)).toList();
    for (final id in toRemove) {
      updatedControllers[id]?.dispose();
      updatedControllers.remove(id);
      updatedErrors.remove(id);
    }

    // 3. Initialize missing controllers for posts in the window
    for (int i = start; i <= end; i++) {
      final post = posts[i];
      if (!updatedControllers.containsKey(post.id) && post.mediaUrl.isNotEmpty) {
        final controller = VideoPlayerController.networkUrl(
          Uri.parse(post.mediaUrl),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
        
        updatedControllers[post.id] = controller;
        
        // Background initialization
        _initController(post.id, controller);
      }
    }

    state = state.copyWith(controllers: updatedControllers, errors: updatedErrors);
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
    }
  }

  /// Manually retry a failed initialization
  void retry(Post post) {
    if (state.controllers.containsKey(post.id)) {
      state.controllers[post.id]?.dispose();
    }
    
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(post.mediaUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    
    state = state.copyWith(
      controllers: Map<String, VideoPlayerController>.from(state.controllers)..[post.id] = controller,
      errors: Map<String, String>.from(state.errors)..remove(post.id),
    );
    
    _initController(post.id, controller);
  }
}

final reelControllerProvider = NotifierProvider<ReelControllerManager, ReelControllerState>(
  ReelControllerManager.new,
);
