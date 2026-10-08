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

  // Double-tap heart splash
  final List<Offset> _doubleTapPositions = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startOverlayTimer();
    // We'll manage the controller via the provider in build/didUpdateWidget
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
      await ref
          .read(postRepositoryProvider)
          .trackReelWatchMetrics(
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
    _overlayTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _showOverlayUi = false);
    });
  }

  void _revealOverlayUi() {
    if (!mounted) return;
    setState(() => _showOverlayUi = true);
    _startOverlayTimer();
  }

  void _onSurfaceTap() {
    if (!_showOverlayUi) {
      _revealOverlayUi();
      return;
    }
    _togglePlayback();
    _startOverlayTimer();
  }

  void _onDoubleTap(Offset position, WidgetRef ref, domain.Post post) {
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

  void _showEngagementMenu(domain.Post post) {
    if (widget.onBoost != null) {
      widget.onBoost!();
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Post actions',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.rocket_launch,
                  color: AppColors.secondaryTeal,
                ),
                title: const Text('Boost this post'),
                subtitle: const Text('Show it to more students on Abuad life'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Boost queued — good luck!')),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.bookmark_border_rounded,
                  color: Colors.white,
                ),
                title: const Text('Save post'),
                subtitle: const Text('Add to your bookmarks'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Post saved!')));
                },
              ),
            ],
          ),
        ),
      ),
    );
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
            onDoubleTapDown: (details) =>
                _onDoubleTap(details.localPosition, ref, livePost),
            onHorizontalDragEnd: (details) =>
                _handleHorizontalDragEnd(details, livePost),
            onLongPress: () => _showEngagementMenu(livePost),
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

                  // Play hint
                  Positioned.fill(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: _showPlayHint ? 1 : 0,
                      child: const Center(
                        child: Icon(
                          Icons.play_arrow,
                          color: Colors.white54,
                          size: 64,
                        ),
                      ),
                    ),
                  ),

                  Positioned.fill(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      opacity: _showOverlayUi ? 1 : 0,
                      child: _buildGradientOverlay(),
                    ),
                  ),

                  // Bottom Content (Username, Caption, Hashtags)
                  Positioned(
                    left: 16,
                    right: 80,
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      opacity: _showOverlayUi ? 1 : 0,
                      child: SafeArea(
                        top: false,
                        child: _buildCaptionSection(livePost),
                      ),
                    ),
                  ),

                  // Sidebar Actions
                  Positioned(
                    right: 12,
                    bottom: MediaQuery.of(context).padding.bottom + 80,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      opacity: _showOverlayUi ? 1 : 0,
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
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      opacity: _showOverlayUi ? 1 : 0,
                      child: SafeArea(
                        top: false,
                        child: _MusicDisc(post: livePost),
                      ),
                    ),
                  ),

                  // Double Tap Hearts
                  ..._doubleTapPositions.map((pos) => _buildHeartSplash(pos)),

                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
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
      left: position.dx - 50,
      top: position.dy - 50,
      child: const Icon(Icons.favorite, color: Colors.redAccent, size: 100)
          .animate()
          .scale(
            duration: 300.ms,
            curve: Curves.elasticOut,
            begin: const Offset(0, 0),
            end: const Offset(1, 1),
          )
          .fadeOut(delay: 400.ms, duration: 400.ms)
          .moveY(begin: 0, end: -50, duration: 800.ms),
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

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Instant Poster / Thumbnail Layer (Prevents black flash while loading)
        if (posterUrl != null && posterUrl.isNotEmpty)
          CachedNetworkImage(
            imageUrl: posterUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: Colors.black),
            errorWidget: (context, url, err) => Container(
              color: Colors.black,
              child: Center(
                child: Icon(
                  Icons.play_circle_outline,
                  color: Colors.white.withValues(alpha: 0.15),
                  size: 80,
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
                size: 80,
              ),
            ),
          ),

        // 2. Active Video Layer (Plays on top as soon as ready)
        if (isReady)
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width > 0
                    ? controller.value.size.width
                    : 16.0,
                height: controller.value.size.height > 0
                    ? controller.value.size.height
                    : 9.0,
                child: VideoPlayer(controller),
              ),
            ),
          ),
      ],
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
      return const SizedBox(height: 2.5);
    }
    return SizedBox(
      height: 12,
      child: VideoProgressIndicator(
        _controller!,
        allowScrubbing: true,
        padding: const EdgeInsets.only(top: 9.5),
        colors: const VideoProgressColors(
          playedColor: Color(0xFFFE2C55),
          backgroundColor: Colors.white24,
          bufferedColor: Colors.white38,
        ),
      ),
    );
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
        Row(
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
          padding: const EdgeInsets.only(bottom: 20),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: UserAvatar(
                  userId: post.authorId,
                  avatarUrl: avatarUrl,
                  displayName: post.authorName,
                  radius: 24,
                  showStoryRing: true,
                ),
              ),
              Positioned(
                bottom: -9,
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
              onTap: () async {
                HapticFeedback.lightImpact();
                ref.read(optimisticSaveProvider.notifier).toggle(post.id, apiSaved);
                try {
                  await ref.read(postRepositoryProvider).togglePostSave(post.id);
                  ref.read(optimisticSaveProvider.notifier).confirm(post.id);
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
  final Color iconColor;
  final Color? labelColor;
  final double scaleX;

  const _ActionIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = Colors.white,
    this.labelColor,
    this.scaleX = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(scaleX, 1.0, 1.0),
              child: Icon(
                icon,
                color: iconColor,
                size: 38,
                shadows: const [Shadow(color: Colors.black45, blurRadius: 4)],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: labelColor ?? Colors.white,
              fontSize: 13,
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
        width: 45,
        height: 45,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Colors.black87, Colors.grey],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white24, width: 2),
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
                      style: const TextStyle(color: Colors.white, fontSize: 10),
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
            width: 22,
            height: 22,
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
                          size: 16,
                        )
                        .animate()
                        .scale(duration: 200.ms, curve: Curves.easeOutBack)
                        .rotate(begin: -0.5, end: 0, duration: 400.ms)
                  : const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 18,
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
