import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/story.dart';
import '../data/story_repository.dart';
import 'package:abuad/src/features/user/data/user_repository.dart';
import '../../feed/domain/report.dart';
import '../../feed/presentation/widgets/report_bottom_sheet.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'create_story_screen.dart';
import 'package:abuad/src/core/utils/url_validator.dart';
import 'package:abuad/src/core/widgets/verification_badge.dart';

/// Full-screen story viewer with Snapchat-style controls
class StoryViewerScreen extends ConsumerStatefulWidget {
  final Map<String, List<Story>> storiesGrouped;
  final String initialUserId;
  final int initialStoryIndex;
  final bool singleUserMode;

  const StoryViewerScreen({
    super.key,
    required this.storiesGrouped,
    required this.initialUserId,
    this.initialStoryIndex = 0,
    this.singleUserMode = false,
  });

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen>
    with TickerProviderStateMixin {
  late PageController _userPageController;
  late int _currentUserIndex;
  late int _currentStoryIndex;
  Timer? _storyTimer;
  bool _isPaused = false;
  late List<String> _userIds;
  late TextEditingController _messageController;
  late FocusNode _focusNode;
  bool _isTyping = false;
  bool _isNavigating = false;

  VideoPlayerController? _videoPlayerController;
  AudioPlayer? _bgAudioPlayer;
  bool _isMediaLoading = false;
  late AnimationController _progressAnimController;
  DateTime? _touchStartTime;
  Offset? _touchStartPosition;
  bool _isHolding = false;

  @override
  void initState() {
    super.initState();
    if (widget.singleUserMode) {
      _userIds = widget.storiesGrouped.containsKey(widget.initialUserId)
          ? [widget.initialUserId]
          : widget.storiesGrouped.keys.take(1).toList();
    } else {
      _userIds = widget.storiesGrouped.keys.toList();
    }

    // Find initial user index
    _currentUserIndex = _userIds.indexOf(widget.initialUserId);
    if (_currentUserIndex == -1) _currentUserIndex = 0;

    _currentStoryIndex = widget.initialStoryIndex;
    _userPageController = PageController(initialPage: _currentUserIndex);
    _messageController = TextEditingController();
    _focusNode = FocusNode();

    _progressAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _messageController.addListener(() {
      if (_messageController.text.isNotEmpty && !_isTyping) {
        setState(() => _isTyping = true);
      } else if (_messageController.text.isEmpty && _isTyping) {
        setState(() => _isTyping = false);
      }
    });

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _pauseStory();
      } else {
        if (_messageController.text.isEmpty) {
          _resumeStory();
        }
      }
    });

    // Mark first story as viewed and set up media playback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markCurrentStoryViewed();
      _setupStoryMedia();
    });
  }

  @override
  void dispose() {
    _storyTimer?.cancel();
    _progressAnimController.dispose();
    _videoPlayerController?.dispose();
    _bgAudioPlayer?.stop();
    _bgAudioPlayer?.dispose();
    _userPageController.dispose();
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Story? get _currentStory {
    if (_currentUserIndex < 0 || _currentUserIndex >= _userIds.length) return null;
    final currentUserId = _userIds[_currentUserIndex];
    final stories = widget.storiesGrouped[currentUserId];
    if (stories == null || _currentStoryIndex < 0 || _currentStoryIndex >= stories.length) return null;
    return stories[_currentStoryIndex];
  }

  void _setupStoryMedia() {
    _storyTimer?.cancel();
    _progressAnimController.stop();
    _progressAnimController.reset();

    final oldVideo = _videoPlayerController;
    _videoPlayerController = null;
    oldVideo?.pause();
    oldVideo?.dispose();

    _bgAudioPlayer?.stop();

    final story = _currentStory;
    if (story == null) return;

    final isVideo = story.type == 'video' ||
        story.content.toLowerCase().endsWith('.mp4') ||
        story.content.toLowerCase().contains('.mp4?');

    // Background soundtrack playback
    if (story.audioUrl != null && story.audioUrl!.isNotEmpty) {
      _bgAudioPlayer ??= AudioPlayer();
      _bgAudioPlayer!.play(UrlSource(story.audioUrl!)).catchError((e) {
        debugPrint('Error playing story audio: $e');
      });
    }

    if (isVideo) {
      setState(() => _isMediaLoading = true);
      final isLocal = !story.content.startsWith('http://') && !story.content.startsWith('https://');
      final controller = isLocal
          ? VideoPlayerController.file(File(story.content))
          : VideoPlayerController.networkUrl(Uri.parse(story.content));
      _videoPlayerController = controller;

      controller.initialize().then((_) {
        if (!mounted || _videoPlayerController != controller) {
          controller.dispose();
          return;
        }
        final dur = controller.value.duration;
        final validDuration = dur.inMilliseconds > 500 ? dur : const Duration(seconds: 10);
        _progressAnimController.duration = validDuration;
        controller.play();
        setState(() => _isMediaLoading = false);
        _startStoryPlayback(validDuration);
      }).catchError((err) {
        debugPrint('Error initializing video in story viewer: $err');
        if (!mounted || _videoPlayerController != controller) return;
        setState(() => _isMediaLoading = false);
        _progressAnimController.duration = const Duration(seconds: 5);
        _startStoryPlayback(const Duration(seconds: 5));
      });
    } else {
      setState(() => _isMediaLoading = false);
      const dur = Duration(seconds: 5);
      _progressAnimController.duration = dur;
      _startStoryPlayback(dur);
    }
  }

  void _startStoryPlayback(Duration duration) {
    if (_isPaused || _isMediaLoading || !mounted) return;
    _progressAnimController.forward(from: _progressAnimController.value);

    _storyTimer?.cancel();
    final remainingMs = (duration.inMilliseconds * (1.0 - _progressAnimController.value)).round();
    _storyTimer = Timer(Duration(milliseconds: remainingMs.clamp(100, 120000)), () {
      if (!_isPaused && !_isMediaLoading && mounted) {
        _nextStory();
      }
    });
  }

  void _pauseStory() {
    setState(() => _isPaused = true);
    _storyTimer?.cancel();
    _progressAnimController.stop();
    _videoPlayerController?.pause();
    _bgAudioPlayer?.pause();
  }

  void _resumeStory() {
    if (_focusNode.hasFocus || _isTyping || _isMediaLoading) return;
    setState(() => _isPaused = false);
    _videoPlayerController?.play();
    _bgAudioPlayer?.resume();
    _startStoryPlayback(_progressAnimController.duration ?? const Duration(seconds: 5));
  }


  void _markCurrentStoryViewed() {
    final currentUserId = _userIds[_currentUserIndex];
    final stories = widget.storiesGrouped[currentUserId];
    if (stories != null && _currentStoryIndex < stories.length) {
      final story = stories[_currentStoryIndex];
      ref.read(storyRepositoryProvider).markAsViewed(story.id);
    }
  }

  void _safePop() {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;
    _storyTimer?.cancel();
    _progressAnimController.stop();
    _videoPlayerController?.pause();
    _bgAudioPlayer?.stop();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/');
    }
  }

  void _nextStory() {
    if (_isNavigating) return;

    final currentUserId = _userIds[_currentUserIndex];
    final stories = widget.storiesGrouped[currentUserId];
    if (stories == null) return;

    if (_currentStoryIndex < stories.length - 1) {
      // Next story of current user
      setState(() {
        _currentStoryIndex++;
      });
      _markCurrentStoryViewed();
      _setupStoryMedia();
    } else {
      // Reached the end of current user's stories
      if (widget.singleUserMode || _currentUserIndex >= _userIds.length - 1) {
        // Stop here and return directly to the screen where the user came from
        _safePop();
      } else {
        // Next user's stories
        setState(() {
          _currentUserIndex++;
          _currentStoryIndex = 0;
        });
        _userPageController.animateToPage(
          _currentUserIndex,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
        );
        _markCurrentStoryViewed();
        _setupStoryMedia();
      }
    }
  }

  void _previousStory() {
    if (_currentStoryIndex > 0) {
      // Previous story of current user
      setState(() {
        _currentStoryIndex--;
      });
      _setupStoryMedia();
    } else {
      if (widget.singleUserMode) {
        // Stay within this user's story in singleUserMode
        return;
      }
      // Previous user's stories
      if (_currentUserIndex > 0) {
        setState(() {
          _currentUserIndex--;
          final prevUserId = _userIds[_currentUserIndex];
          final prevStories = widget.storiesGrouped[prevUserId];
          _currentStoryIndex = (prevStories?.length ?? 1) - 1;
        });
        _userPageController.animateToPage(
          _currentUserIndex,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
        );
        _setupStoryMedia();
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
            _safePop();
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

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      _pauseStory();
      await launchUrl(url, mode: LaunchMode.externalApplication);
      if (mounted) {
        _resumeStory();
      }
    }
  }

  Future<void> _likeCurrentStory() async {
    final currentUserId = _userIds[_currentUserIndex];
    final stories = widget.storiesGrouped[currentUserId]!;
    final story = stories[_currentStoryIndex];
    final myId = ref.read(currentUserProvider).value?.uid;

    if (myId == null) return;

    final isLiking = !story.hasLiked(myId);

    await ref
        .read(storyRepositoryProvider)
        .likeStory(story.id, isLiking: isLiking);

    // Update local state if needed (Stream should handle it, but for snappiness)
    if (mounted) {
      setState(() {
        // Force rebuild to show like animation if implemented
      });
    }
  }

  void _reshareStory(Story story) {
    _pauseStory();
    _showReshareOptionsSheet(story);
  }

  void _showReshareOptionsSheet(Story story) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF111827),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Share Status / Story',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.repeat_rounded, color: Color(0xFF8B5CF6)),
                  ),
                  title: const Text('Repost to My Story', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  subtitle: const Text('Share this status to your story with attribution', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateStoryScreen(resharedStory: story),
                      ),
                    ).then((_) {
                      if (mounted) _resumeStory();
                    });
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.send_rounded, color: Color(0xFF3B82F6)),
                  ),
                  title: const Text('Send in Chat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  subtitle: const Text('Share status directly with friends or groups', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _resumeStory();
                    context.push('/chat');
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.ios_share_rounded, color: Colors.tealAccent),
                  ),
                  title: const Text('Share via...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  subtitle: const Text('Share external link via WhatsApp, X, etc.', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _shareStory(story);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      if (mounted) _resumeStory();
    });
  }

  void _shareStory(Story story) {
    _pauseStory();

    final text =
        'Check out this story on Abuad App! ${story.caption ?? ""}\n\nhttps://abuadapp.com.ng/story/${story.id}';
    SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: 'Story from ${story.userName}',
      ),
    ).then((_) {
      if (mounted) {
        _resumeStory();
      }
    });
  }

  void _sendMessage(Story story) {
    if (_messageController.text.trim().isEmpty) return;

    // Logic to send story reply as a chat message
    // For now, just clear and unfocus
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Reply sent!')));

    _messageController.clear();
    _focusNode.unfocus();
  }

  void _showViewers(Story story) {
    _pauseStory();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildViewersSheet(context, story),
    ).whenComplete(() {
      if (mounted) {
        _resumeStory();
      }
    });
  }

  Widget _buildViewersSheet(BuildContext context, Story story) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const TabBar(
                tabs: [
                  Tab(text: 'Viewers'),
                  Tab(text: 'Likes'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildUserList(story.viewers),
                    _buildUserList(story.likes, isLikeList: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserList(List<String> userIds, {bool isLikeList = false}) {
    if (userIds.isEmpty) {
      return const Center(child: Text('No users yet'));
    }
    return ListView.builder(
      itemCount: userIds.length,
      itemBuilder: (context, index) {
        final userId = userIds[index];
        return Consumer(
          builder: (context, ref, child) {
            final userAsync = ref.watch(userProvider(userId));
            return userAsync.when(
              data: (user) {
                final avatarUrl = user?.avatarUrl;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage:
                        (avatarUrl != null &&
                            UrlValidator.isValidUrl(avatarUrl))
                        ? CachedNetworkImageProvider(avatarUrl)
                        : null,
                    child:
                        (avatarUrl == null ||
                            !UrlValidator.isValidUrl(avatarUrl))
                        ? Text(user?.displayName[0].toUpperCase() ?? '?')
                        : null,
                  ),
                  title: Text(user?.displayName ?? 'Unknown'),
                  trailing: isLikeList
                      ? const Icon(Icons.favorite, color: Colors.red, size: 20)
                      : null,
                );
              },
              loading: () => const ListTile(title: Text('Loading...')),
              error: (_, _) => const SizedBox(),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _safePop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: (details) {
            _touchStartTime = DateTime.now();
            _touchStartPosition = details.globalPosition;
            _isHolding = false;
            // Instantly pause timer & video when finger touches screen
            _pauseStory();
          },
          onTapUp: (details) {
            final now = DateTime.now();
            final durationMs = _touchStartTime != null
                ? now.difference(_touchStartTime!).inMilliseconds
                : 999;
            final dxDiff = _touchStartPosition != null
                ? (details.globalPosition.dx - _touchStartPosition!.dx).abs()
                : 0.0;

            // Only navigate if it was a quick, deliberate tap and NOT a hold to view
            if (durationMs < 300 && dxDiff < 25 && !_isHolding) {
              final width = MediaQuery.of(context).size.width;
              if (details.globalPosition.dx < width * 0.35) {
                _previousStory();
              } else {
                _nextStory();
              }
            } else {
              // Released after holding snap to view — resume playback
              _resumeStory();
            }
            _touchStartTime = null;
            _isHolding = false;
          },
          onTapCancel: () {
            _touchStartTime = null;
            _isHolding = false;
            _resumeStory();
          },
          onLongPressStart: (_) {
            _isHolding = true;
            _pauseStory();
          },
          onLongPressEnd: (_) {
            _isHolding = false;
            _resumeStory();
          },
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity! > 0) {
              _safePop();
            }
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification) {
                // Pause video and timer immediately during horizontal 3D swipe
                _pauseStory();
              } else if (notification is ScrollEndNotification) {
                // Resume story video and timer once swipe settles
                _resumeStory();
              }
              return false;
            },
            child: PageView.builder(
            controller: _userPageController,
            physics: widget.singleUserMode
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            itemCount: _userIds.length,
            onPageChanged: (index) {
              if (index != _currentUserIndex) {
                setState(() {
                  _currentUserIndex = index;
                  _currentStoryIndex = 0;
                });
                _markCurrentStoryViewed();
                _setupStoryMedia();
              }
            },
            itemBuilder: (context, userIndex) {
              final userId = _userIds[userIndex];
              final stories = widget.storiesGrouped[userId]!;

              // FIX: Only use _currentStoryIndex for the active user index
              // Pre-cached neighbors should use index 0 to avoid RangeError
              final actualStoryIndex = userIndex == _currentUserIndex
                  ? _currentStoryIndex
                  : 0;
              final story = stories[actualStoryIndex];

              return AnimatedBuilder(
                animation: _userPageController,
                builder: (context, child) {
                  double position = 0.0;
                  if (_userPageController.position.haveDimensions) {
                    position = (userIndex -
                        (_userPageController.page ?? _currentUserIndex.toDouble()));
                  } else {
                    position = (userIndex - _currentUserIndex).toDouble();
                  }

                  // 3D Cube Rotation Transition
                  final isLeaving = position < 0;
                  final rotationY = (position * 0.6).clamp(-1.2, 1.2);
                  final opacity =
                      (1.0 - (position.abs() * 0.3)).clamp(0.2, 1.0);

                  return Transform(
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(rotationY),
                    alignment: isLeaving
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Opacity(
                      opacity: opacity,
                      child: child,
                    ),
                  );
                },
                child: Consumer(
                builder: (context, ref, child) {
                  final viewerId = ref.watch(currentUserProvider).value?.uid;
                  final userAsync = ref.watch(userProvider(userId));

                  return userAsync.when(
                    data: (user) {
                      final userName =
                          user?.displayName ??
                          (story.userName.isNotEmpty
                              ? story.userName
                              : 'Unknown');
                      final userAvatar =
                          user?.avatarUrl ??
                          (story.userAvatar.isNotEmpty
                              ? story.userAvatar
                              : null);

                      final isOwnStory = story.authorId == viewerId;

                      final isVideoStory = story.type == 'video' ||
                          story.content.toLowerCase().endsWith('.mp4') ||
                          story.content.toLowerCase().contains('.mp4?');

                      return Stack(
                        children: [
                          // Story Content (Video, Image, or Text)
                          Center(
                            child: story.type == 'text'
                                ? Container(
                                    color: Color(
                                      story.backgroundColor ?? 0xFF000000,
                                    ),
                                    width: double.infinity,
                                    height: double.infinity,
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.all(32),
                                    child: Text(
                                      story.content,
                                      textAlign: _parseTextAlign(
                                        story.textAlign,
                                      ),
                                      style: TextStyle(
                                        color: Color(
                                          story.textColor ?? 0xFFFFFFFF,
                                        ),
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        fontFamily:
                                            story.fontFamily ?? 'Roboto',
                                      ),
                                    ),
                                  )
                                : isVideoStory
                                    ? (_videoPlayerController != null &&
                                            _videoPlayerController!.value.isInitialized
                                        ? FittedBox(
                                            fit: BoxFit.contain,
                                            child: SizedBox(
                                              width: _videoPlayerController!.value.size.width,
                                              height: _videoPlayerController!.value.size.height,
                                              child: VideoPlayer(_videoPlayerController!),
                                            ),
                                          )
                                        : const Center(
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                            ),
                                          ))
                                    : CachedNetworkImage(
                                        imageUrl: story.content,
                                        fit: BoxFit.contain,
                                        width: double.infinity,
                                        height: double.infinity,
                                        placeholder: (context, url) => const Center(
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                          ),
                                        ),
                                        errorWidget: (context, url, error) =>
                                            const Center(
                                              child: Icon(
                                                Icons.error,
                                                color: Colors.white,
                                                size: 48,
                                              ),
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
                                    Colors.black.withValues(alpha: 0.6),
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
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.3,
                                      ),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                    child: index < _currentStoryIndex
                                        ? Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          )
                                        : index == _currentStoryIndex
                                            ? AnimatedBuilder(
                                                animation: _progressAnimController,
                                                builder: (context, _) => FractionallySizedBox(
                                                  alignment: Alignment.centerLeft,
                                                  widthFactor: _progressAnimController.value.clamp(0.0, 1.0),
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius: BorderRadius.circular(2),
                                                    ),
                                                  ),
                                                ),
                                              )
                                            : const SizedBox.shrink(),
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
                                // Profile Avatar & Name (Navigates to Profile)
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      _pauseStory();
                                      context.push('/user/$userId').then((_) {
                                        if (mounted) {
                                          _resumeStory();
                                        }
                                      });
                                    },
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundImage:
                                              (userAvatar != null &&
                                                  UrlValidator.isValidUrl(
                                                    userAvatar,
                                                  ))
                                              ? CachedNetworkImageProvider(
                                                  userAvatar,
                                                )
                                              : null,
                                          backgroundColor: const Color(
                                            0xFF8B5CF6,
                                          ),
                                          child:
                                              (userAvatar == null ||
                                                  !UrlValidator.isValidUrl(
                                                    userAvatar,
                                                  ))
                                              ? Text(
                                                  userName.isNotEmpty
                                                      ? userName[0]
                                                            .toUpperCase()
                                                      : '?',
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
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      userName,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  if (user != null &&
                                                      (user.isVerified ||
                                                          (user
                                                                  .verificationType
                                                                  .isNotEmpty &&
                                                              user.verificationType !=
                                                                  'none'))) ...[
                                                    const SizedBox(width: 4),
                                                    VerificationBadge(
                                                      type:
                                                          user
                                                              .verificationType
                                                              .isNotEmpty
                                                          ? user.verificationType
                                                          : 'blue',
                                                      size: 14,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              Text(
                                                timeago.format(story.createdAt),
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.8),
                                                  fontSize: 13,
                                                ),
                                              ),
                                              if (story.musicTitle != null &&
                                                  story.musicTitle!.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons.music_note_rounded,
                                                      color: AppColors.secondaryTeal,
                                                      size: 13,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Flexible(
                                                      child: Text(
                                                        '${story.musicTitle}${story.musicArtist != null ? " · ${story.musicArtist}" : ""}',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Follow button (If not followed)
                                if (!isOwnStory &&
                                    !(ref
                                            .watch(isFollowingProvider(userId))
                                            .value ??
                                        true))
                                  Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: TextButton(
                                      onPressed: () {
                                        ref
                                            .read(userRepositoryProvider)
                                            .followUser(userId);
                                      },
                                      style: TextButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 4,
                                        ),
                                        minimumSize: const Size(60, 30),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Follow',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                // Viewers Count (Author Only)
                                if (isOwnStory)
                                  GestureDetector(
                                    onTap: () => _showViewers(story),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.4,
                                        ),
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
                                            '${story.viewers.length}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                if (isOwnStory)
                                  IconButton(
                                    onPressed: _deleteCurrentStory,
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.white,
                                    ),
                                  ),
                                IconButton(
                                  onPressed: _safePop,
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                  ),
                                ),
                                if (!isOwnStory)
                                  IconButton(
                                    onPressed: () {
                                      _pauseStory();
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (context) => ReportBottomSheet(
                                          targetId: story.id,
                                          type: ReportType.story,
                                        ),
                                      ).then((_) {
                                        if (mounted) {
                                          _resumeStory();
                                        }
                                      });
                                    },
                                    icon: const Icon(
                                      Icons.report_outlined,
                                      color: Colors.white,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Reshare indicator (Attribution)
                          if (story.reshareAuthorName != null)
                            Positioned(
                              top: MediaQuery.of(context).padding.top + 85,
                              left: 12,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 8,
                                    sigmaY: 8,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.3,
                                      ),
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.15,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.repeat,
                                          color: Color(0xFFC4B5FD),
                                          size: 14,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Reshared from @${story.reshareAuthorName}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // Mentions and Caption
                          Positioned(
                            bottom: 80,
                            left: 16,
                            right: 16,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (story.mentions.isNotEmpty)
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    alignment: WrapAlignment.center,
                                    children: story.mentions
                                        .map(
                                          (mention) => GestureDetector(
                                            onTap: () {
                                              _pauseStory();
                                              ref
                                                  .read(userRepositoryProvider)
                                                  .getUserByHandle(mention)
                                                  .then((user) {
                                                    if (user != null &&
                                                        context.mounted) {
                                                      context.push(
                                                        '/user/${user.uid}',
                                                      );
                                                    } else if (context.mounted) {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            'User @$mention not found',
                                                          ),
                                                        ),
                                                      );
                                                      _resumeStory();
                                                    }
                                                  });
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(
                                                  alpha: 0.5,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(15),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFF8B5CF6,
                                                  ).withValues(alpha: 0.8),
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(
                                                      0xFF8B5CF6,
                                                    ).withValues(alpha: 0.2),
                                                    blurRadius: 4,
                                                    spreadRadius: 1,
                                                  ),
                                                ],
                                              ),
                                              child: Text(
                                                '@$mention',
                                                style: const TextStyle(
                                                  color: Color(0xFFC4B5FD),
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                if (story.mentions.isNotEmpty &&
                                    story.caption != null &&
                                    story.caption!.isNotEmpty)
                                  const SizedBox(height: 8),
                                if (story.caption != null &&
                                    story.caption!.isNotEmpty &&
                                    story.type != 'text')
                                  Text(
                                    story.caption!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      shadows: [
                                        Shadow(
                                          blurRadius: 4,
                                          color: Colors.black,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Link Button (Visit Link)
                          if (story.linkUrl != null &&
                              story.linkUrl!.isNotEmpty)
                            Positioned(
                              bottom: 90,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: GestureDetector(
                                  onTap: () => _launchUrl(story.linkUrl!),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF8B5CF6),
                                          Color(0xFFEC4899),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.3,
                                          ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(
                                          Icons.share_outlined,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Visit Link',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // Actions Bar (Bottom)
                          Positioned(
                            bottom: MediaQuery.of(context).padding.bottom + 16,
                            left: 16,
                            right: 16,
                            child: Row(
                              children: [
                                // Frosted Glass Reply Input Bar
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(28),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                      child: Container(
                                        height: 50,
                                        padding: const EdgeInsets.symmetric(horizontal: 14),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(28),
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Colors.white.withValues(alpha: 0.20),
                                              Colors.white.withValues(alpha: 0.08),
                                            ],
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.32),
                                            width: 1.2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.2),
                                              blurRadius: 16,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.chat_bubble_outline_rounded,
                                              color: Colors.white70,
                                              size: 19,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: TextField(
                                                controller: _messageController,
                                                focusNode: _focusNode,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                decoration: const InputDecoration(
                                                  hintText: 'Reply to story...',
                                                  hintStyle: TextStyle(
                                                    color: Colors.white60,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w400,
                                                  ),
                                                  border: InputBorder.none,
                                                  isDense: true,
                                                  contentPadding: EdgeInsets.zero,
                                                ),
                                                onSubmitted: (_) => _sendMessage(story),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 10),

                                // Actions (Like, Reshare, Share) OR Send Button
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOutCubic,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!_isTyping && !_focusNode.hasFocus) ...[
                                        // Like Button
                                        ClipOval(
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                            child: Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: (viewerId != null && story.hasLiked(viewerId))
                                                    ? Colors.red.withValues(alpha: 0.25)
                                                    : Colors.white.withValues(alpha: 0.15),
                                                border: Border.all(
                                                  color: (viewerId != null && story.hasLiked(viewerId))
                                                      ? Colors.redAccent.withValues(alpha: 0.6)
                                                      : Colors.white.withValues(alpha: 0.25),
                                                  width: 1.2,
                                                ),
                                              ),
                                              child: IconButton(
                                                padding: EdgeInsets.zero,
                                                onPressed: _likeCurrentStory,
                                                icon: Icon(
                                                  (viewerId != null && story.hasLiked(viewerId))
                                                      ? Icons.favorite_rounded
                                                      : Icons.favorite_border_rounded,
                                                  color: (viewerId != null && story.hasLiked(viewerId))
                                                      ? Colors.redAccent
                                                      : Colors.white,
                                                  size: 22,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Reshare Button
                                        ClipOval(
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                            child: Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                                                border: Border.all(
                                                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                                                  width: 1.2,
                                                ),
                                              ),
                                              child: IconButton(
                                                padding: EdgeInsets.zero,
                                                onPressed: () => _reshareStory(story),
                                                icon: const Icon(
                                                  Icons.repeat_rounded,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Share Button
                                        ClipOval(
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                            child: Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.white.withValues(alpha: 0.15),
                                                border: Border.all(
                                                  color: Colors.white.withValues(alpha: 0.25),
                                                  width: 1.2,
                                                ),
                                              ),
                                              child: IconButton(
                                                padding: EdgeInsets.zero,
                                                onPressed: () => _shareStory(story),
                                                icon: const Icon(
                                                  Icons.ios_share_rounded,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ] else ...[
                                        // Glowing Send Button
                                        GestureDetector(
                                          onTap: () => _sendMessage(story),
                                          child: Container(
                                            width: 46,
                                            height: 46,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: const LinearGradient(
                                                colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFF14B8A6).withValues(alpha: 0.45),
                                                  blurRadius: 14,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
                                            ),
                                            child: const Center(
                                              child: Icon(
                                                Icons.arrow_upward_rounded,
                                                color: Colors.white,
                                                size: 24,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Center(
                      child: Text(
                        "Error: $e",
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    ),
  ),
);
  }

  TextAlign _parseTextAlign(String? align) {
    switch (align) {
      case 'left':
        return TextAlign.left;
      case 'right':
        return TextAlign.right;
      default:
        return TextAlign.center;
    }
  }
}
