import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../../../core/utils/url_validator.dart';

class VideoPostWidget extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final double? defaultAspectRatio;
  final VoidCallback? onTap;
  final VoidCallback? onOpenFullscreen;
  final bool autoPlay;
  final bool startMuted;

  const VideoPostWidget({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
    this.defaultAspectRatio,
    this.onTap,
    this.onOpenFullscreen,
    this.autoPlay = true,
    this.startMuted = true,
  });

  @override
  State<VideoPostWidget> createState() => _VideoPostWidgetState();
}

class _VideoPostWidgetState extends State<VideoPostWidget>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isLoading = true;
  bool _isBuffering = false;
  bool _hasError = false;
  bool _isMuted = true;
  bool _isVisible = true;
  bool _manuallyPaused = false;
  double _aspectRatio = 16 / 9;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isMuted = widget.startMuted;
    if (widget.defaultAspectRatio != null && widget.defaultAspectRatio! > 0) {
      _aspectRatio = widget.defaultAspectRatio!;
    }
    _initializePlayer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_isInitialized) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _controller?.pause();
      if (mounted) setState(() => _isPlaying = false);
    } else if (state == AppLifecycleState.resumed) {
      if (_isVisible && !_manuallyPaused && widget.autoPlay) {
        _controller?.play();
        if (mounted) setState(() => _isPlaying = true);
      }
    }
  }

  @override
  void didUpdateWidget(covariant VideoPostWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _resetController();
      _initializePlayer();
    }
  }

  Future<void> _initializePlayer() async {
    if (_controller != null) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    VideoPlayerController? controller;
    try {
      final effectiveUrl = UrlValidator.formatImageUrl(widget.videoUrl);
      controller = VideoPlayerController.networkUrl(
        Uri.parse(effectiveUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(_isMuted ? 0.0 : 1.0);

      controller.addListener(_videoListener);

      if (!mounted) {
        controller.removeListener(_videoListener);
        controller.dispose();
        return;
      }

      final rawRatio = controller.value.aspectRatio;
      // Clamp between portrait 3:4 (0.72) and landscape 16:9 (1.85) for best card layout
      final computedRatio = (rawRatio > 0)
          ? rawRatio.clamp(0.72, 1.85)
          : (widget.defaultAspectRatio ?? (16 / 9));

      setState(() {
        _controller = controller;
        _isInitialized = true;
        _aspectRatio = computedRatio;
        _isLoading = false;
      });

      if (_isVisible && widget.autoPlay && !_manuallyPaused) {
        await controller.play();
        if (mounted) {
          setState(() => _isPlaying = true);
        }
      }
    } catch (e) {
      debugPrint("Video initialization error: $e");
      controller?.dispose();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  void _videoListener() {
    if (!mounted || _controller == null) return;
    final controller = _controller!;
    final isBuffering = controller.value.isBuffering;
    final isPlaying = controller.value.isPlaying;

    if (isBuffering != _isBuffering || isPlaying != _isPlaying) {
      setState(() {
        _isBuffering = isBuffering;
        _isPlaying = isPlaying;
      });
    }
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    if (!mounted) return;
    final wasVisible = _isVisible;
    _isVisible = info.visibleFraction >= 0.45;

    if (_controller == null || !_isInitialized) return;

    if (!_isVisible && wasVisible) {
      // Scrolled off screen - auto pause
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        setState(() => _isPlaying = false);
      }
    } else if (_isVisible && !wasVisible) {
      // Scrolled back on screen - auto play if not manually paused
      if (widget.autoPlay && !_manuallyPaused && !_controller!.value.isPlaying) {
        _controller!.play();
        setState(() => _isPlaying = true);
      }
    }
  }

  void _toggleMute() {
    if (_controller == null || !_isInitialized) return;
    HapticFeedback.lightImpact();
    final newMute = !_isMuted;
    setState(() => _isMuted = newMute);
    _controller!.setVolume(newMute ? 0.0 : 1.0);
  }

  void _togglePlayback() {
    if (_controller == null || !_isInitialized) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
      setState(() {
        _isPlaying = false;
        _manuallyPaused = true;
      });
    } else {
      _controller!.play();
      setState(() {
        _isPlaying = true;
        _manuallyPaused = false;
      });
    }
  }

  void _resetController() {
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    _isPlaying = false;
    _isBuffering = false;
    _isLoading = false;
    _hasError = false;
    _manuallyPaused = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resetController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('video_post_${widget.videoUrl}_${identityHashCode(this)}'),
      onVisibilityChanged: _handleVisibilityChanged,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: _aspectRatio,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_hasError) {
                _initializePlayer();
              } else if (widget.onTap != null) {
                widget.onTap!();
              } else if (widget.onOpenFullscreen != null) {
                widget.onOpenFullscreen!();
              } else {
                _togglePlayback();
              }
            },
            child: Container(
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                alignment: Alignment.center,
                children: [
                  // Video Layer
                  if (_isInitialized && _controller != null)
                    FittedBox(
                      fit: BoxFit.cover,
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox(
                        width: _controller!.value.size.width > 0
                            ? _controller!.value.size.width
                            : 16,
                        height: _controller!.value.size.height > 0
                            ? _controller!.value.size.height
                            : 9,
                        child: VideoPlayer(_controller!),
                      ),
                    )
                  else
                    _buildPlaceholder(),

                  // Loading / Buffering Spinner
                  if (_isLoading || _isBuffering)
                    IgnorePointer(
                      child: Container(
                        color: Colors.black38,
                        child: const Center(
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Error State with clickable Retry button
                  if (_hasError)
                    Center(
                      child: GestureDetector(
                        onTap: _initializePlayer,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.replay_circle_filled_rounded,
                                color: Colors.white,
                                size: 40,
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Tap to retry',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Paused Play Icon Hint (if not loading and manually paused)
                  if (!_isPlaying && !_isLoading && !_isBuffering && !_hasError && _manuallyPaused)
                    IgnorePointer(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                    ),

                  // Top-Right Fullscreen / Reels Button (if provided)
                  if (widget.onOpenFullscreen != null && _isInitialized && !_hasError)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onOpenFullscreen,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.fullscreen_rounded,
                            color: Colors.white,
                            size: 19,
                          ),
                        ),
                      ),
                    ),

                  // Mute / Speaker Icon Button (Bottom Right)
                  if (_isInitialized && !_hasError)
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _toggleMute,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Icon(
                            _isMuted
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    final effectiveThumb = (widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty)
        ? UrlValidator.formatImageUrl(widget.thumbnailUrl)
        : '';
    if (effectiveThumb.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: effectiveThumb,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorWidget: (_, _, _) => Container(color: Colors.grey[900]),
        placeholder: (_, _) => Container(
          color: Colors.grey[900],
          child: const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                color: Colors.white38,
                strokeWidth: 2,
              ),
            ),
          ),
        ),
      );
    }
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Icon(
          Icons.movie_outlined,
          color: Colors.white.withValues(alpha: 0.15),
          size: 48,
        ),
      ),
    );
  }
}
