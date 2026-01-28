import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../domain/story_model.dart';
import '../providers/story_providers.dart';

/// Full-screen story viewer with Snapchat-style controls
class StoryViewerScreen extends ConsumerStatefulWidget {
  final Map<String, List<Story>> storiesGrouped;
  final String initialUserId;

  const StoryViewerScreen({
    super.key,
    required this.storiesGrouped,
    required this.initialUserId,
  });

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen> {
  late PageController _userPageController;
  late int _currentUserIndex;
  late int _currentStoryIndex;
  Timer? _storyTimer;
  bool _isPaused = false;
  late List<String> _userIds;

  @override
  void initState() {
    super.initState();
    _userIds = widget.storiesGrouped.keys.toList();

    // Find initial user index
    _currentUserIndex = _userIds.indexOf(widget.initialUserId);
    if (_currentUserIndex == -1) _currentUserIndex = 0;

    _currentStoryIndex = 0;
    _userPageController = PageController(initialPage: _currentUserIndex);

    // Mark first story as viewed and start timer
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markCurrentStoryViewed();
      _startStoryTimer();
    });
  }

  @override
  void dispose() {
    _storyTimer?.cancel();
    _userPageController.dispose();
    super.dispose();
  }

  void _startStoryTimer() {
    _storyTimer?.cancel();
    if (_isPaused) return;

    _storyTimer = Timer(const Duration(seconds: 5), () {
      _nextStory();
    });
  }

  void _markCurrentStoryViewed() {
    final currentUserId = _userIds[_currentUserIndex];
    final stories = widget.storiesGrouped[currentUserId]!;
    if (_currentStoryIndex < stories.length) {
      final story = stories[_currentStoryIndex];
      final viewerId = ref.read(currentUserIdProvider);
      ref.read(storyRepositoryProvider).markAsViewed(story.id, viewerId);
    }
  }

  void _nextStory() {
    final currentUserId = _userIds[_currentUserIndex];
    final stories = widget.storiesGrouped[currentUserId]!;

    if (_currentStoryIndex < stories.length - 1) {
      // Next story of current user
      setState(() {
        _currentStoryIndex++;
      });
      _markCurrentStoryViewed();
      _startStoryTimer();
    } else {
      // Next user's stories
      if (_currentUserIndex < _userIds.length - 1) {
        setState(() {
          _currentUserIndex++;
          _currentStoryIndex = 0;
        });
        _userPageController.animateToPage(
          _currentUserIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        _markCurrentStoryViewed();
        _startStoryTimer();
      } else {
        // End of all stories
        Navigator.pop(context);
      }
    }
  }

  void _previousStory() {
    if (_currentStoryIndex > 0) {
      // Previous story of current user
      setState(() {
        _currentStoryIndex--;
      });
      _startStoryTimer();
    } else {
      // Previous user's stories
      if (_currentUserIndex > 0) {
        setState(() {
          _currentUserIndex--;
          final prevUserId = _userIds[_currentUserIndex];
          _currentStoryIndex = widget.storiesGrouped[prevUserId]!.length - 1;
        });
        _userPageController.animateToPage(
          _currentUserIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        _startStoryTimer();
      }
    }
  }

  void _deleteCurrentStory() async {
    final currentUserId = _userIds[_currentUserIndex];
    final stories = widget.storiesGrouped[currentUserId]!;
    final story = stories[_currentStoryIndex];

    // Confirm deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Story?'),
        content: const Text('This story will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(storyRepositoryProvider).deleteStory(story.id);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Story deleted')));
          // Move to next or close
          if (stories.length == 1) {
            Navigator.pop(context);
          } else {
            _nextStory();
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < width / 3) {
            _previousStory();
          } else if (details.globalPosition.dx > 2 * width / 3) {
            _nextStory();
          }
        },
        onLongPressStart: (_) {
          setState(() {
            _isPaused = true;
          });
          _storyTimer?.cancel();
        },
        onLongPressEnd: (_) {
          setState(() {
            _isPaused = false;
          });
          _startStoryTimer();
        },
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity! > 0) {
            Navigator.pop(context);
          }
        },
        child: PageView.builder(
          controller: _userPageController,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _userIds.length,
          onPageChanged: (index) {
            setState(() {
              _currentUserIndex = index;
              _currentStoryIndex = 0;
            });
            _markCurrentStoryViewed();
            _startStoryTimer();
          },
          itemBuilder: (context, userIndex) {
            final userId = _userIds[userIndex];
            final stories = widget.storiesGrouped[userId]!;
            final story = stories[_currentStoryIndex];
            final viewerId = ref.watch(currentUserIdProvider);
            final isOwnStory = story.userId == viewerId;

            return Stack(
              children: [
                // Story image
                Center(
                  child: CachedNetworkImage(
                    imageUrl: story.mediaUrl,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    errorWidget: (context, url, error) => const Center(
                      child: Icon(Icons.error, color: Colors.white, size: 48),
                    ),
                  ),
                ),

                // Gradient overlay at top
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.6),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Progress bars
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 8,
                  right: 8,
                  child: Row(
                    children: List.generate(
                      stories.length,
                      (index) => Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: index < _currentStoryIndex
                                ? 1.0
                                : index == _currentStoryIndex
                                ? (_isPaused ? 0.5 : 1.0)
                                : 0.0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // User info header
                Positioned(
                  top: MediaQuery.of(context).padding.top + 20,
                  left: 12,
                  right: 12,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: story.userAvatar.isNotEmpty
                            ? CachedNetworkImageProvider(story.userAvatar)
                            : null,
                        backgroundColor: const Color(0xFF8B5CF6),
                        child: story.userAvatar.isEmpty
                            ? Text(
                                story.userName[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              story.userName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              story.timeAgo,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (story.viewCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.remove_red_eye,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${story.viewCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: 8),
                      if (isOwnStory)
                        IconButton(
                          onPressed: _deleteCurrentStory,
                          icon: const Icon(Icons.delete, color: Colors.white),
                        ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // Caption at bottom
                if (story.caption != null && story.caption!.isNotEmpty)
                  Positioned(
                    bottom: 40,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        story.caption!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
