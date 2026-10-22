import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../../../core/utils/url_validator.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/domain/chat_message.dart';
import '../domain/snap_model.dart';
import '../data/snap_repository.dart';

/// Full-screen Snapchat-style Snap viewer.
/// Supports both:
/// 1. Direct private ephemeral Chat Snaps (with 10s photo countdown, video playback with audio,
///    tap-to-dismiss, single replay enforcement, and Save-in-Chat).
/// 2. Multi-user grouped Snap Stories.
class SnapViewerScreen extends ConsumerStatefulWidget {
  // Direct snap fields
  final ChatMessage? directMessage;
  final String? channelId;
  final String? senderName;
  final String? senderAvatar;
  final VoidCallback? onSnapConsumed;

  // Grouped snap stories fields
  final Map<String, List<Snap>>? snapsGrouped;
  final String? initialUserId;

  const SnapViewerScreen({
    super.key,
    required Map<String, List<Snap>> this.snapsGrouped,
    required String this.initialUserId,
  })  : directMessage = null,
        channelId = null,
        senderName = null,
        senderAvatar = null,
        onSnapConsumed = null;

  const SnapViewerScreen.directSnap({
    super.key,
    required ChatMessage this.directMessage,
    required String this.channelId,
    this.senderName,
    this.senderAvatar,
    this.onSnapConsumed,
  })  : snapsGrouped = null,
        initialUserId = null;

  bool get isDirectSnap => directMessage != null;

  @override
  ConsumerState<SnapViewerScreen> createState() => _SnapViewerScreenState();
}

class _SnapViewerScreenState extends ConsumerState<SnapViewerScreen>
    with SingleTickerProviderStateMixin {
  // Direct snap video & timer
  VideoPlayerController? _videoController;
  AnimationController? _photoProgressController;
  bool _isVideoInitialized = false;
  bool _isVideoLoading = false;
  bool _hasVideoError = false;
  bool _isMuted = false;
  bool _isSavedInChat = false;
  bool _isViewConsumed = false;
  bool _isPhotoTimerStarted = false;

  // Story mode fields
  PageController? _pageController;
  List<String> _userIds = [];
  int _currentUserIndex = 0;
  int _currentSnapIndex = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    if (widget.isDirectSnap) {
      _initDirectSnap();
    } else if (widget.snapsGrouped != null && widget.snapsGrouped!.isNotEmpty) {
      _initGroupedStories();
    }
  }

  void _initDirectSnap() {
    final msg = widget.directMessage!;
    final currentUserId = ref.read(chatRepositoryProvider).currentUserId;
    _isSavedInChat = msg.isSavedBy(currentUserId);

    if (msg.isVideoSnap && msg.imageUrl != null && msg.imageUrl!.isNotEmpty) {
      _initVideoPlayer(msg.imageUrl!);
    }
    // For photos, countdown and view consumption begin when the image successfully loads
  }

  void _recordDirectSnapView() {
    if (_isViewConsumed) return;
    _isViewConsumed = true;
    final channelId = widget.channelId;
    final msgId = widget.directMessage?.id;
    if (channelId != null && msgId != null) {
      ref.read(chatRepositoryProvider).viewSnap(channelId, msgId);
      widget.onSnapConsumed?.call();
    }
  }

  void _initPhotoTimer(int durationSeconds) {
    if (_photoProgressController != null) return;
    _photoProgressController = AnimationController(
      vsync: this,
      duration: Duration(seconds: durationSeconds),
    );

    _photoProgressController!.addListener(() {
      if (mounted) setState(() {});
    });

    _photoProgressController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _dismissViewer();
      }
    });

    _photoProgressController!.forward();
  }

  Future<void> _initVideoPlayer(String url) async {
    setState(() => _isVideoLoading = true);
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      _videoController = controller;
      await controller.initialize();
      await controller.setVolume(_isMuted ? 0.0 : 1.0);
      await controller.play();

      controller.addListener(_videoListener);

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
          _isVideoLoading = false;
        });
        // Media successfully loaded and playing: record viewing attempt
        _recordDirectSnapView();
      }
    } catch (e) {
      debugPrint('Video snap error: $e');
      if (mounted) {
        setState(() {
          _hasVideoError = true;
          _isVideoLoading = false;
        });
      }
    }
  }

  void _videoListener() {
    if (!mounted || _videoController == null) return;
    final controller = _videoController!;
    setState(() {});

    if (controller.value.isInitialized &&
        controller.value.position >= controller.value.duration &&
        controller.value.duration > Duration.zero) {
      controller.removeListener(_videoListener);
      _dismissViewer();
    }
  }

  void _initGroupedStories() {
    _userIds = widget.snapsGrouped!.keys.toList();
    _currentUserIndex = _userIds.indexOf(widget.initialUserId ?? '');
    if (_currentUserIndex < 0) _currentUserIndex = 0;
    _currentSnapIndex = 0;
    _pageController = PageController(initialPage: _currentUserIndex);
    _markCurrentStoryAsViewed();
  }

  void _markCurrentStoryAsViewed() {
    if (_userIds.isEmpty) return;
    final userId = _userIds[_currentUserIndex];
    final snaps = widget.snapsGrouped![userId];
    if (snaps != null && snaps.isNotEmpty && _currentSnapIndex < snaps.length) {
      final snap = snaps[_currentSnapIndex];
      ref.read(snapRepositoryProvider).markSnapAsViewed(snap.id);
    }
  }

  void _dismissViewer() {
    if (_isVideoInitialized || _isPhotoTimerStarted) {
      _recordDirectSnapView();
    }
    // Evict photo from local disk/memory cache if not saved in chat
    if (!_isSavedInChat && widget.directMessage?.imageUrl != null) {
      try {
        CachedNetworkImage.evictFromCache(widget.directMessage!.imageUrl!);
      } catch (_) {}
    }
    if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  void _toggleMute() {
    if (_videoController == null) return;
    setState(() {
      _isMuted = !_isMuted;
      _videoController!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  Future<void> _toggleSaveInChat() async {
    final channelId = widget.channelId;
    final msgId = widget.directMessage?.id;
    if (channelId == null || msgId == null) return;

    HapticFeedback.mediumImpact();
    setState(() => _isSavedInChat = !_isSavedInChat);

    await ref.read(chatRepositoryProvider).toggleSaveMessage(channelId, msgId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isSavedInChat
                ? '📌 Snap saved in chat'
                : 'Snap removed from saved',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    _photoProgressController?.dispose();
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isDirectSnap) {
      return _buildDirectSnapViewer();
    }
    return _buildGroupedStoriesViewer();
  }

  // ── Direct Ephemeral Snap Viewer ───────────────────────────────────────────

  Widget _buildDirectSnapViewer() {
    final msg = widget.directMessage!;
    final mediaUrl = msg.imageUrl ?? '';

    // Calculate progress ratio
    double progress = 0.0;
    if (_photoProgressController != null) {
      progress = _photoProgressController!.value;
    } else if (_videoController != null && _isVideoInitialized) {
      final total = _videoController!.value.duration.inMilliseconds;
      final pos = _videoController!.value.position.inMilliseconds;
      if (total > 0) progress = (pos / total).clamp(0.0, 1.0);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Tapping anywhere consumes the view and immediately dismisses the snap
        onTap: _dismissViewer,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Media Content
            Center(
              child: _buildDirectSnapMedia(mediaUrl, msg.isVideoSnap),
            ),

            // Top gradient overlay for high contrast readable header
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 140,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Animated Linear Progress Countdown Bar
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12,
              right: 12,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3.5,
                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),

            // Header Bar
            Positioned(
              top: MediaQuery.of(context).padding.top + 18,
              left: 14,
              right: 14,
              child: Row(
                children: [
                  // Sender Avatar
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: Colors.white24,
                    backgroundImage: widget.senderAvatar != null &&
                            widget.senderAvatar!.isNotEmpty
                        ? CachedNetworkImageProvider(widget.senderAvatar!)
                        : null,
                    child: widget.senderAvatar == null ||
                            widget.senderAvatar!.isEmpty
                        ? Text(
                            widget.senderName?.isNotEmpty == true
                                ? widget.senderName![0].toUpperCase()
                                : 'S',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  // Sender Name & Snap badge
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.senderName ?? 'Friend',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  letterSpacing: 0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                msg.isVideoSnap ? '🎥 VIDEO SNAP' : '📸 SNAP',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Tap screen to close',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Audio Mute toggle for video snaps
                  if (msg.isVideoSnap && _isVideoInitialized)
                    IconButton(
                      icon: Icon(
                        _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: _toggleMute,
                      tooltip: _isMuted ? 'Unmute' : 'Mute',
                    ),

                  // Explicit "Save in Chat" action (Disallows Save to Gallery)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: _isSavedInChat
                          ? const Color(0xFF6366F1)
                          : Colors.white.withValues(alpha: 0.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: _isSavedInChat
                              ? const Color(0xFF818CF8)
                              : Colors.white30,
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                    icon: Icon(
                      _isSavedInChat
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_add_outlined,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: Text(
                      _isSavedInChat ? 'Saved' : 'Save',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    onPressed: _toggleSaveInChat,
                  ),
                  const SizedBox(width: 4),

                  // Close button
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    onPressed: _dismissViewer,
                  ),
                ],
              ),
            ),

            // Bottom subtle indicator
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 20,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24, width: 0.8),
                  ),
                  child: Text(
                    _isSavedInChat
                        ? '📌 Saved in chat • Accessible anytime'
                        : '🔥 Ephemeral Snap • Replay once then disappears',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectSnapMedia(String mediaUrl, bool isVideo) {
    if (!UrlValidator.isValidUrl(mediaUrl)) {
      return _buildErrorState('Invalid media URL');
    }

    if (isVideo) {
      if (_hasVideoError) {
        return _buildErrorState('Failed to load video snap');
      }
      if (_isVideoLoading || !_isVideoInitialized) {
        return const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFEF4444),
            strokeWidth: 3,
          ),
        );
      }
      return Center(
        child: AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        ),
      );
    }

    // Photo Snap
    final msg = widget.directMessage!;
    return CachedNetworkImage(
      imageUrl: mediaUrl,
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) => const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFEF4444),
          strokeWidth: 3,
        ),
      ),
      imageBuilder: (context, imageProvider) {
        if (!_isPhotoTimerStarted) {
          _isPhotoTimerStarted = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _initPhotoTimer(msg.snapDuration > 0 ? msg.snapDuration : 10);
              _recordDirectSnapView();
            }
          });
        }
        return Image(image: imageProvider, fit: BoxFit.contain);
      },
      errorWidget: (context, url, error) => _buildErrorState('Failed to load snap'),
    );
  }

  Widget _buildErrorState(String message) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
        const SizedBox(height: 16),
        Text(
          message,
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          onPressed: () {
            // Dismiss error state without consuming a viewing attempt
            if (mounted) Navigator.of(context).maybePop();
          },
          child: const Text('Close'),
        ),
      ],
    );
  }

  // ── Grouped Snap Stories Viewer ─────────────────────────────────────────────

  Widget _buildGroupedStoriesViewer() {
    if (_userIds.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No Snaps Available', style: TextStyle(color: Colors.white)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        itemCount: _userIds.length,
        onPageChanged: (index) {
          setState(() {
            _currentUserIndex = index;
            _currentSnapIndex = 0;
          });
          _markCurrentStoryAsViewed();
        },
        itemBuilder: (context, userIndex) {
          final userId = _userIds[userIndex];
          final snaps = widget.snapsGrouped![userId] ?? [];
          if (snaps.isEmpty || _currentSnapIndex >= snaps.length) {
            return const SizedBox.shrink();
          }

          final snap = snaps[_currentSnapIndex];

          return Stack(
            children: [
              Positioned.fill(
                child: UrlValidator.isValidUrl(snap.imageUrl)
                    ? CachedNetworkImage(
                        imageUrl: snap.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                        errorWidget: (context, url, error) => _buildErrorState('Content unavailable'),
                      )
                    : _buildErrorState('Content unavailable'),
              ),

              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.5),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                ),
              ),

              // Progress Bar
              Positioned(
                top: 50,
                left: 10,
                right: 10,
                child: Row(
                  children: List.generate(snaps.length, (index) {
                    return Expanded(
                      child: Container(
                        height: 2.5,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: index <= _currentSnapIndex
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // Header
              Positioned(
                top: 60,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    UserAvatar(
                      userId: snap.userId,
                      avatarUrl: snap.userAvatar,
                      radius: 18,
                      showStoryRing: false,
                      enableDefaultTap: false,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      snap.userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Caption
              if (snap.caption != null && snap.caption!.isNotEmpty)
                Positioned(
                  bottom: 100,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      snap.caption!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),

              // Tap Targets for navigation
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () {
                          if (_currentSnapIndex > 0) {
                            setState(() => _currentSnapIndex--);
                            _markCurrentStoryAsViewed();
                          } else if (_currentUserIndex > 0) {
                            _pageController?.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () {
                          if (_currentSnapIndex < snaps.length - 1) {
                            setState(() => _currentSnapIndex++);
                            _markCurrentStoryAsViewed();
                          } else if (_currentUserIndex < _userIds.length - 1) {
                            _pageController?.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
