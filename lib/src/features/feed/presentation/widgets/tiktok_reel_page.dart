import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../data/post_repository.dart';
import '../../../user/data/user_repository.dart';
import '../../domain/post.dart' as domain;
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/share_sheet.dart';
import '../providers/reel_controller_provider.dart';
import '../providers/feed_provider.dart';
import 'reel_comment_sheet.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../../core/utils/url_validator.dart';
import '../../../../core/widgets/verification_badge.dart';
import '../../../../shared/widgets/abuad_markdown.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'bookmark_folder_picker_sheet.dart';

/// TikTok-style reel page used inside the vertical Reels viewer.
class TikTokReelPage extends ConsumerStatefulWidget {
  final domain.Post post;
  final bool isActive;
  final VoidCallback? onBoost;

  const TikTokReelPage({
    super.key,
    required this.post,
    required this.isActive,
    this.onBoost,
  });

  @override
  ConsumerState<TikTokReelPage> createState() => _TikTokReelPageState();
}

class _TikTokReelPageState extends ConsumerState<TikTokReelPage>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _isBuffering = false;
  bool _showPlayHint = false;
  bool _manuallyPaused = false;
  bool _isVisible = true;
  bool _isCaptionExpanded = false;
  bool _showOverlayUi = true;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Timer? _overlayTimer;
  DateTime? _watchStartAt;
  int _watchedMsAccumulated = 0;
  int _replayCount = 0;
  bool _completed = false;
  bool _hasTrackedWatchSession = false;

  // Double-tap heart splash & Scrubber
  final List<Offset> _doubleTapPositions = [];
  bool _isScrubbing = false;
  Duration _scrubPosition = Duration.zero;
  double _scrubX = 0.0;
  PostRepository? _postRepo;
  bool _isHoldingToPause = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _postRepo = ref.read(postRepositoryProvider);
    _startOverlayTimer();
    // We'll manage the controller via the provider in build/didUpdateWidget
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _postRepo = ref.read(postRepositoryProvider);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !widget.isActive || !_isVisible) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _flushWatchMetrics('app_paused');
      _controller?.pause();
    } else if (state == AppLifecycleState.resumed) {
      if (!_manuallyPaused && (widget.isActive && _isVisible)) {
        _controller?.play();
        _startWatchSessionIfNeeded();
      }
    }
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    if (!mounted) return;

    final wasVisible = _isVisible;
    _isVisible = info.visibleFraction > 0.5;

    if (_controller == null) return;

    if (!_isVisible && wasVisible) {
      // Just became hidden
      _stopWatchSession();
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      }
    } else if (_isVisible && !wasVisible) {
      // Just became visible
      if (widget.isActive &&
          !_manuallyPaused &&
          !_controller!.value.isPlaying) {
        _controller!.play();
        _startWatchSessionIfNeeded();
      }
    }
  }

  void _videoListener() {
    if (!mounted || _controller == null) return;

    final value = _controller!.value;
    final isBuffering = value.isBuffering;
    final isInitialized = value.isInitialized;

    setState(() {
      _isBuffering = isBuffering;
      _position = value.position;
      _duration = value.duration;
      // We also want to clear any play hint if it starts playing
      if (value.isPlaying && _showPlayHint) {
        _showPlayHint = false;
      }
    });

    // If it just finished initializing and we are active, start playing
    if (widget.isActive &&
        isInitialized &&
        !value.isPlaying &&
        !value.isBuffering) {
      _controller!.play();
      _startWatchSessionIfNeeded();
    }

    if (value.isPlaying) {
      _startWatchSessionIfNeeded();
    } else {
      _stopWatchSession();
    }

    final totalMs = value.duration.inMilliseconds;
    if (totalMs > 0) {
      final progress = value.position.inMilliseconds / totalMs;
      if (progress >= 0.95 && !_completed) {
        _completed = true;
      }
      if (value.position.inMilliseconds <= 400 &&
          _position.inMilliseconds > 2000) {
        _replayCount++;
      }
    }
  }

  @override
  void didUpdateWidget(covariant TikTokReelPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _flushWatchMetrics('post_changed');
      _resetWatchState();
    }
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (widget.isActive && !oldWidget.isActive) {
      _controller!.play();
      _startWatchSessionIfNeeded();
    } else if (!widget.isActive && oldWidget.isActive) {
      _flushWatchMetrics('inactive');
      _controller!.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_videoListener);
    _overlayTimer?.cancel();
    _flushWatchMetrics('dispose');
    // Note: We DON'T dispose the controller here because it's managed by ReelControllerManager
    super.dispose();
  }

  void _togglePlayback() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    HapticFeedback.lightImpact();
    if (_controller!.value.isPlaying) {
      _controller!.pause();
      _stopWatchSession();
      setState(() {
        _showPlayHint = true;
        _manuallyPaused = true;
      });
    } else {
      _controller!.play();
      _startWatchSessionIfNeeded();
      setState(() {
        _showPlayHint = false;
        _manuallyPaused = false;
      });
    }
  }

  void _handleHoldToPause(bool holding) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (holding) {
      HapticFeedback.selectionClick();
      _controller!.pause();
      setState(() {
        _isHoldingToPause = true;
      });
    } else {
      if (!_manuallyPaused) {
        _controller!.play();
      }
      setState(() {
        _isHoldingToPause = false;
      });
    }
  }

  void _startWatchSessionIfNeeded() {
    if (_watchStartAt != null || !widget.isActive || !_isVisible) return;
    _watchStartAt = DateTime.now();
  }

  void _stopWatchSession() {
    if (_watchStartAt == null) return;
    final elapsed = DateTime.now().difference(_watchStartAt!).inMilliseconds;
    if (elapsed > 0) {
      _watchedMsAccumulated += elapsed;
    }
    _watchStartAt = null;
  }

  void _resetWatchState() {
    _watchStartAt = null;
    _watchedMsAccumulated = 0;
    _replayCount = 0;
    _completed = false;
    _hasTrackedWatchSession = false;
  }

  Future<void> _flushWatchMetrics(String reason) async {
    _stopWatchSession();
    if (_hasTrackedWatchSession || _watchedMsAccumulated <= 0) return;
    _hasTrackedWatchSession = true;

    final totalMs = _duration.inMilliseconds;
    final completionRate = totalMs <= 0
        ? 0.0
        : (_watchedMsAccumulated / totalMs).clamp(0.0, 1.0);
    final skippedQuickly = _watchedMsAccumulated < 3000;

    try {
      await _postRepo?.trackReelWatchMetrics(
        postId: widget.post.id,
        watchedMs: _watchedMsAccumulated,
        completionRate: completionRate,
        replayCount: _replayCount,
        skippedQuickly: skippedQuickly,
        completed: _completed,
        source: 'reels_$reason',
      );
    } catch (e) {
      debugPrint('Failed to track reel watch metrics: $e');
    }
  }

  void _startOverlayTimer() {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _showOverlayUi = false);
    });
  }


  void _onSurfaceTap() {
    _togglePlayback();
    _startOverlayTimer();
  }

  void _onDoubleTap(Offset position, WidgetRef ref, domain.Post post) {
    HapticFeedback.mediumImpact();
    setState(() {
      _doubleTapPositions.add(position);
    });

    // Handle the like logic
    final apiLiked = ref.read(isPostLikedProvider(post.id)).value ?? false;
    if (!apiLiked) {
      ref.read(optimisticLikeProvider.notifier).toggle(post.id, false);
      ref
          .read(postRepositoryProvider)
          .toggleLike(post.id)
          .then((_) {
            ref.read(optimisticLikeProvider.notifier).confirm(post.id);
          })
          .catchError((_) {
            ref.read(optimisticLikeProvider.notifier).revert(post.id, false);
          });
    }

    // Remove heart after animation
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _doubleTapPositions.remove(position);
        });
      }
    });
  }

  String _formatNumber(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) {
      double k = count / 1000;
      return k >= 10 ? '${k.toStringAsFixed(0)}K' : '${k.toStringAsFixed(1)}K';
    }
    double m = count / 1000000;
    return m >= 10 ? '${m.toStringAsFixed(0)}M' : '${m.toStringAsFixed(1)}M';
  }

  Future<void> _openComments(domain.Post post) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReelCommentSheet(post: post),
    );
  }

  void _openProfileByUserId(String userId) {
    if (!mounted || userId.isEmpty) return;
    context.push('/user/$userId');
  }

  void _handleHorizontalDragEnd(DragEndDetails details, domain.Post post) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -450) {
      _openProfileByUserId(post.authorId);
    }
  }


  @override
  Widget build(BuildContext context) {
    super.build(context);
    final reelState = ref.watch(reelControllerProvider);
    final controller = reelState.controllers[widget.post.id];
    final error = reelState.errors[widget.post.id];

    // Connect local controller reference for listener and didUpdateWidget
    if (controller != _controller) {
      _controller?.removeListener(_videoListener);
      _controller = controller;
      _controller?.addListener(_videoListener);

      // Auto-play if it's already initialized and we are active
      if (widget.isActive &&
          _controller != null &&
          _controller!.value.isInitialized &&
          !_controller!.value.isPlaying) {
        _controller!.play();
      }
    }

    final repo = ref.watch(postRepositoryProvider);

    return StreamBuilder<domain.Post?>(
      stream: repo.watchPost(widget.post.id),
      builder: (context, snapshot) {
        final livePost = snapshot.data ?? widget.post;
        final apiLiked =
            ref.watch(isPostLikedProvider(livePost.id)).value ?? false;
        final optimisticMap = ref.watch(optimisticLikeProvider);
        final optimisticOverride = optimisticMap.containsKey(livePost.id)
            ? optimisticMap[livePost.id]!
            : null;
        final isLiked = optimisticOverride ?? apiLiked;
        final likeDelta = optimisticMap.containsKey(livePost.id)
            ? (optimisticMap[livePost.id]! ? 1 : -1)
            : 0;
        final likeCount = (livePost.likesCount + likeDelta).clamp(0, 9999999);

        return VisibilityDetector(
          key: Key('reel_${widget.post.id}'),
          onVisibilityChanged: _handleVisibilityChanged,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTapDown: (details) =>
                _onDoubleTap(details.localPosition, ref, livePost),
            onHorizontalDragEnd: (details) =>
                _handleHorizontalDragEnd(details, livePost),
            onLongPressStart: (_) => _handleHoldToPause(true),
            onLongPressEnd: (_) => _handleHoldToPause(false),
            onLongPressCancel: () => _handleHoldToPause(false),
            onTap: _onSurfaceTap,
            child: Container(
              color: Colors.black,
              child: Stack(
                children: [
                  // Video Background
                  Positioned.fill(child: _buildVideoLayer(controller, error)),

                  // Loading/Buffering indicator
                  if (controller == null ||
                      !controller.value.isInitialized ||
                      _isBuffering)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                          if (error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Failed to load video',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                            ),
                            TextButton(
                              onPressed: () => ref
                                  .read(reelControllerProvider.notifier)
                                  .retry(widget.post),
                              child: const Text(
                                'Retry',
                                style: TextStyle(
                                  color: AppColors.secondaryTeal,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                  // Center Play / Pause Indicator (TikTok style)
                  Positioned.fill(
                    child: Center(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: (_showPlayHint || _isHoldingToPause) ? 1.0 : 0.0,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: Icon(
                            _isHoldingToPause ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ),

                  Positioned.fill(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      opacity: (_showOverlayUi && !_isHoldingToPause) ? 1 : 0,
                      child: _buildGradientOverlay(),
                    ),
                  ),

                  // Bottom Content (Username, Caption, Hashtags)
                  Positioned(
                    left: 16,
                    right: 80,
                    bottom: MediaQuery.of(context).padding.bottom + 22,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      opacity: (_showOverlayUi && !_isHoldingToPause) ? 1 : 0,
                      child: SafeArea(
                        top: false,
                        child: _buildCaptionSection(livePost),
                      ),
                    ),
                  ),

                  // Sidebar Actions
                  Positioned(
                    right: 12,
                    bottom: MediaQuery.of(context).padding.bottom + 85,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      opacity: (_showOverlayUi && !_isHoldingToPause) ? 1 : 0,
                      child: SafeArea(
                        top: false,
                        child: _buildActionColumn(
                          context,
                          livePost,
                          isLiked,
                          likeCount,
                        ),
                      ),
                    ),
                  ),

                  // Music Disc (positioned relative to bottom right)
                  Positioned(
                    right: 12,
                    bottom: MediaQuery.of(context).padding.bottom + 22,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      opacity: (_showOverlayUi && !_isHoldingToPause) ? 1 : 0,
                      child: SafeArea(
                        top: false,
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            context.push('/audio-track', extra: livePost);
                          },
                          child: _MusicDisc(post: livePost),
                        ),
                      ),
                    ),
                  ),

                  // Double Tap Hearts
                  ..._doubleTapPositions.map((pos) => _buildHeartSplash(pos)),

                  // Timeline Scrubber
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: MediaQuery.of(context).padding.bottom + 2,
                    child: _buildProgressBar(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeartSplash(Offset position) {
    return Positioned(
      left: position.dx - 60,
      top: position.dy - 60,
      child: SizedBox(
        width: 120,
        height: 120,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Central pulsing heart
            const Icon(
              Icons.favorite,
              color: Color(0xFFFE2C55),
              size: 90,
              shadows: [
                Shadow(color: Color(0x66FE2C55), blurRadius: 20),
                Shadow(color: Colors.black45, blurRadius: 8),
              ],
            )
                .animate()
                .scale(
                  duration: 350.ms,
                  curve: Curves.elasticOut,
                  begin: const Offset(0.2, 0.2),
                  end: const Offset(1.2, 1.2),
                )
                .rotate(begin: -0.06, end: 0.06, duration: 250.ms)
                .fadeOut(delay: 450.ms, duration: 350.ms)
                .moveY(begin: 0, end: -60, duration: 800.ms),

            // Top-left satellite heart
            const Positioned(
              left: 15,
              top: 15,
              child: Icon(Icons.favorite, color: Colors.white, size: 22),
            )
                .animate()
                .scale(duration: 250.ms, curve: Curves.easeOut, begin: const Offset(0, 0), end: const Offset(1, 1))
                .move(begin: const Offset(0, 0), end: const Offset(-25, -25), duration: 500.ms)
                .fadeOut(delay: 300.ms, duration: 300.ms),

            // Top-right satellite heart
            const Positioned(
              right: 15,
              top: 15,
              child: Icon(Icons.favorite, color: Color(0xFFFF6584), size: 24),
            )
                .animate()
                .scale(duration: 250.ms, curve: Curves.easeOut, begin: const Offset(0, 0), end: const Offset(1, 1))
                .move(begin: const Offset(0, 0), end: const Offset(25, -30), duration: 500.ms)
                .fadeOut(delay: 350.ms, duration: 300.ms),

            // Sparkle left
            const Positioned(
              left: 10,
              bottom: 30,
              child: Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 16),
            )
                .animate()
                .scale(duration: 200.ms, begin: const Offset(0, 0), end: const Offset(1, 1))
                .move(begin: const Offset(0, 0), end: const Offset(-20, 10), duration: 400.ms)
                .fadeOut(delay: 300.ms, duration: 300.ms),

            // Sparkle right
            const Positioned(
              right: 10,
              bottom: 30,
              child: Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 16),
            )
                .animate()
                .scale(duration: 200.ms, begin: const Offset(0, 0), end: const Offset(1, 1))
                .move(begin: const Offset(0, 0), end: const Offset(20, 10), duration: 400.ms)
                .fadeOut(delay: 300.ms, duration: 300.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoLayer(VideoPlayerController? controller, String? error) {
    final mediaUrl = widget.post.mediaUrl.trim();
    final isVideoFile = mediaUrl.toLowerCase().endsWith('.mp4') ||
        mediaUrl.toLowerCase().endsWith('.mov') ||
        mediaUrl.toLowerCase().endsWith('.webm') ||
        mediaUrl.toLowerCase().contains('/videos/');

    final posterUrl = (!isVideoFile && mediaUrl.isNotEmpty) ? mediaUrl : null;

    final bool isReady = controller != null && controller.value.isInitialized;

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Instant Poster / Thumbnail Layer (Contained on black, no cropping)
          if (posterUrl != null && posterUrl.isNotEmpty)
            Center(
              child: CachedNetworkImage(
                imageUrl: posterUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => Container(color: Colors.black),
                errorWidget: (context, url, err) => Container(
                  color: Colors.black,
                  child: Center(
                    child: Icon(
                      Icons.play_circle_outline,
                      color: Colors.white.withValues(alpha: 0.15),
                      size: 60,
                    ),
                  ),
                ),
              ),
            )
          else
            Container(
              color: Colors.black,
              child: Center(
                child: Icon(
                  Icons.play_circle_outline,
                  color: Colors.white.withValues(alpha: 0.15),
                  size: 60,
                ),
              ),
            ),

          // 2. Active Video Layer (Letterboxed on black background without cropping)
          if (isReady)
            Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio > 0
                    ? controller.value.aspectRatio
                    : (controller.value.size.width > 0 &&
                            controller.value.size.height > 0
                        ? controller.value.size.width /
                            controller.value.size.height
                        : 9.0 / 16.0),
                child: VideoPlayer(controller),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black26, Colors.black54],
          stops: [0.55, 0.8, 1.0],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const SizedBox(height: 3);
    }

    final totalDuration = _controller!.value.duration;
    final currentPos = _isScrubbing ? _scrubPosition : _controller!.value.position;
    final screenWidth = MediaQuery.of(context).size.width;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        // Floating Scrubber Time Tooltip centered above finger
        if (_isScrubbing)
          Positioned(
            bottom: 32,
            left: (_scrubX - 55).clamp(16.0, screenWidth - 126.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white30, width: 1.0),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 3)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.circle, size: 7, color: Color(0xFFFE2C55)),
                  const SizedBox(width: 6),
                  Text(
                    '${_formatDuration(currentPos)} / ${_formatDuration(totalDuration)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ).animate().scale(duration: 120.ms, curve: Curves.easeOut),
          ),

        // Interactive Scrubbing Bar (Generous touch target)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            HapticFeedback.selectionClick();
            final box = context.findRenderObject() as RenderBox?;
            final width = box?.size.width ?? screenWidth;
            if (width > 0 && totalDuration.inMilliseconds > 0) {
              final fraction = (details.localPosition.dx / width).clamp(0.0, 1.0);
              final targetMs = (fraction * totalDuration.inMilliseconds).toInt();
              final target = Duration(milliseconds: targetMs);
              setState(() {
                _isScrubbing = true;
                _scrubPosition = target;
                _scrubX = details.localPosition.dx;
              });
              _controller?.seekTo(target);
            }
          },
          onTapUp: (_) {
            setState(() => _isScrubbing = false);
          },
          onTapCancel: () {
            setState(() => _isScrubbing = false);
          },
          onHorizontalDragStart: (details) {
            HapticFeedback.selectionClick();
            final box = context.findRenderObject() as RenderBox?;
            final width = box?.size.width ?? screenWidth;
            if (width > 0 && totalDuration.inMilliseconds > 0) {
              final fraction = (details.localPosition.dx / width).clamp(0.0, 1.0);
              final targetMs = (fraction * totalDuration.inMilliseconds).toInt();
              setState(() {
                _isScrubbing = true;
                _scrubPosition = Duration(milliseconds: targetMs);
                _scrubX = details.localPosition.dx;
              });
            }
          },
          onHorizontalDragUpdate: (details) {
            final box = context.findRenderObject() as RenderBox?;
            final width = box?.size.width ?? screenWidth;
            if (width > 0 && totalDuration.inMilliseconds > 0) {
              final fraction = (details.localPosition.dx / width).clamp(0.0, 1.0);
              final targetMs = (fraction * totalDuration.inMilliseconds).toInt();
              setState(() {
                _scrubPosition = Duration(milliseconds: targetMs);
                _scrubX = details.localPosition.dx;
              });
              _controller?.seekTo(_scrubPosition);
            }
          },
          onHorizontalDragEnd: (_) {
            HapticFeedback.lightImpact();
            setState(() => _isScrubbing = false);
          },
          onHorizontalDragCancel: () {
            setState(() => _isScrubbing = false);
          },
          child: Container(
            height: 32,
            alignment: Alignment.bottomCenter,
            color: Colors.transparent,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: _isScrubbing ? 5.5 : 2.5,
                  child: VideoProgressIndicator(
                    _controller!,
                    allowScrubbing: false,
                    padding: EdgeInsets.zero,
                    colors: const VideoProgressColors(
                      playedColor: Color(0xFFFE2C55),
                      backgroundColor: Colors.white24,
                      bufferedColor: Colors.white38,
                    ),
                  ),
                ),
                if (_isScrubbing)
                  Positioned(
                    left: (_scrubX - 7).clamp(0.0, screenWidth - 14.0),
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildCaptionSection(domain.Post post) {
    final authorHandle = post.authorHandle.isNotEmpty
        ? post.authorHandle
        : post.authorName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _openProfileByUserId(post.authorId),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '@$authorHandle',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                ),
              ),
              if (post.isVerified) ...[
                const SizedBox(width: 4),
                VerificationBadge(
                  type: post.verificationType,
                  size: 16,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          crossFadeState: _isCaptionExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: AbuadMarkdownContent(
            content: post.content,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            linkColor: AppColors.secondaryTeal,
            textStyle: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.3,
              shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
            ),
          ),
          secondChild: AbuadMarkdownContent(
            content: post.content,
            linkColor: AppColors.secondaryTeal,
            textStyle: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.3,
              shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
            ),
          ),
        ),
        if (post.content.trim().length > 80)
          TextButton(
            onPressed: () {
              setState(() => _isCaptionExpanded = !_isCaptionExpanded);
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              _isCaptionExpanded ? 'less' : 'more...',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/audio-track', extra: post);
          },
          child: Row(
            children: [
              const Icon(Icons.music_note_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Original audio · $authorHandle',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionColumn(
    BuildContext context,
    domain.Post post,
    bool isLiked,
    int likeCount,
  ) {
    final avatarUrl = post.authorAvatarUrl;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Profile
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.2),
                ),
                child: UserAvatar(
                  userId: post.authorId,
                  avatarUrl: avatarUrl,
                  displayName: post.authorName,
                  radius: 19,
                  showStoryRing: true,
                ),
              ),
              Positioned(
                bottom: -8,
                left: 0,
                right: 0,
                child: Center(child: _FollowButton(userId: post.authorId)),
              ),
            ],
          ),
        ),

        // Like
        _ActionIconButton(
          icon: isLiked ? Icons.favorite : Icons.favorite,
          iconColor: isLiked ? const Color(0xFFFE2C55) : Colors.white,
          label: _formatNumber(likeCount),
          onTap: () async {
            final apiLiked =
                ref.watch(isPostLikedProvider(post.id)).value ?? false;
            ref.read(optimisticLikeProvider.notifier).toggle(post.id, apiLiked);
            try {
              await ref.read(postRepositoryProvider).toggleLike(post.id);
              ref.read(optimisticLikeProvider.notifier).confirm(post.id);
            } catch (_) {
              ref
                  .read(optimisticLikeProvider.notifier)
                  .revert(post.id, apiLiked);
            }
          },
        ),

        // Comment
        _ActionIconButton(
          icon: CupertinoIcons.chat_bubble_fill,
          label: _formatNumber(post.commentsCount),
          onTap: () => _openComments(post),
        ),

        // Save
        Consumer(
          builder: (context, ref, child) {
            final optimisticSaveMap = ref.watch(optimisticSaveProvider);
            final apiSaved =
                ref.watch(isPostSavedProvider(post.id)).value ?? post.isSaved;
            final isSaved = optimisticSaveMap.containsKey(post.id)
                ? optimisticSaveMap[post.id]!
                : apiSaved;
            final optimisticSaveCount = optimisticSaveMap.containsKey(post.id)
                ? (post.savesCount + (optimisticSaveMap[post.id]! ? (apiSaved ? 0 : 1) : (apiSaved ? -1 : 0)))
                : post.savesCount;
            const goldColor = Color(0xFFFFB800);

            return _ActionIconButton(
              icon: isSaved ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark,
              iconColor: isSaved ? goldColor : Colors.white,
              labelColor: isSaved ? goldColor : Colors.white,
              label: _formatNumber(optimisticSaveCount),
              onLongPress: () {
                HapticFeedback.mediumImpact();
                BookmarkFolderPickerSheet.show(context, post.id);
              },
              onTap: () async {
                HapticFeedback.lightImpact();
                ref.read(optimisticSaveProvider.notifier).toggle(post.id, apiSaved);
                try {
                  await ref.read(postRepositoryProvider).togglePostSave(post.id);
                  ref.read(optimisticSaveProvider.notifier).confirm(post.id);
                  if (!isSaved && context.mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Saved to Bookmarks'),
                        action: SnackBarAction(
                          label: 'Organize',
                          textColor: AppColors.secondaryTeal,
                          onPressed: () => BookmarkFolderPickerSheet.show(context, post.id),
                        ),
                        duration: const Duration(seconds: 3),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  ref.read(optimisticSaveProvider.notifier).revert(post.id, apiSaved);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error saving post: $e')),
                    );
                  }
                }
              },
            );
          },
        ),

        // Share
        _ActionIconButton(
          icon: CupertinoIcons.share,
          scaleX: -1.0, // Mirrored for TikTok share arrow look
          label: _formatNumber(post.sharesCount),
          onTap: () {
            ref.read(postRepositoryProvider).incrementShareCount(post.id);
            ShareSheet.show(context, post);
          },
        ),
      ],
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color iconColor;
  final Color? labelColor;
  final double scaleX;

  const _ActionIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.onLongPress,
    this.iconColor = Colors.white,
    this.labelColor,
    this.scaleX = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(scaleX, 1.0, 1.0),
              child: Icon(
                icon,
                color: iconColor,
                size: 27,
                shadows: const [Shadow(color: Colors.black45, blurRadius: 4)],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: labelColor ?? Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              shadows: const [Shadow(color: Colors.black45, blurRadius: 2)],
            ),
          ),
        ],
      ),
    );
  }
}

class _MusicDisc extends StatefulWidget {
  final domain.Post post;
  const _MusicDisc({required this.post});

  @override
  State<_MusicDisc> createState() => _MusicDiscState();
}

class _MusicDiscState extends State<_MusicDisc>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Container(
        width: 36,
        height: 36,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Colors.black87, Colors.grey],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white24, width: 1.5),
        ),
        child: ClipOval(
          child:
              (widget.post.authorAvatarUrl != null &&
                  widget.post.authorAvatarUrl!.isNotEmpty &&
                  UrlValidator.isValidUrl(widget.post.authorAvatarUrl!))
              ? CachedNetworkImage(
                  imageUrl: widget.post.authorAvatarUrl!,
                  fit: BoxFit.cover,
                )
              : Container(
                  color: Colors.grey[800],
                  child: Center(
                    child: Text(
                      widget.post.authorName.isNotEmpty
                          ? widget.post.authorName[0]
                          : '?',
                      style: const TextStyle(color: Colors.white, fontSize: 9),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _FollowButton extends ConsumerStatefulWidget {
  final String userId;
  const _FollowButton({required this.userId});

  @override
  ConsumerState<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<_FollowButton> {
  bool _isFollowingInProgress = false;

  @override
  Widget build(BuildContext context) {
    final followingAsync = ref.watch(isFollowingProvider(widget.userId));
    final currentUserId = ref.watch(currentUserIdProvider);

    // Don't show if it's my own profile
    if (currentUserId == widget.userId) return const SizedBox.shrink();

    return followingAsync.when(
      data: (isFollowing) {
        // If already following and no animation in progress, hide
        if (isFollowing && !_isFollowingInProgress) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () async {
            if (_isFollowingInProgress || isFollowing) return;

            setState(() => _isFollowingInProgress = true);

            try {
              // Trigger the follow repository call
              await ref.read(userRepositoryProvider).followUser(widget.userId);

              // Give the user a moment to see the 'tick' animation
              await Future.delayed(const Duration(milliseconds: 800));
            } catch (e) {
              debugPrint('Error following user: $e');
            } finally {
              if (mounted) {
                setState(() => _isFollowingInProgress = false);
              }
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: _isFollowingInProgress
                  ? Colors.green
                  : const Color(0xFFFE2C55),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: _isFollowingInProgress
                  ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 12,
                        )
                        .animate()
                        .scale(duration: 200.ms, curve: Curves.easeOutBack)
                        .rotate(begin: -0.5, end: 0, duration: 400.ms)
                  : const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
