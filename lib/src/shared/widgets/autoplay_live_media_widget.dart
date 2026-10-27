import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../../core/utils/url_validator.dart';

/// AutoPlayLiveMediaWidget
///
/// Seamlessly supports:
/// 1. Short live photo videos (.mp4, .mov, .webm, .m4v, .mkv, .avi, .3gp) with silent looping autoplay.
/// 2. Animated live photos and stickers (.webp, .gif) with infinite looping animation.
/// 3. Standard web images (.jpg, .jpeg, .png) with caching and instant thumbnail preview.
/// 4. Graceful fallback: If video autoplay is restricted or fails, seamlessly renders the live photo frame!
class AutoPlayLiveMediaWidget extends StatefulWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool isCircle;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const AutoPlayLiveMediaWidget({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.isCircle = false,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<AutoPlayLiveMediaWidget> createState() => _AutoPlayLiveMediaWidgetState();
}

class _AutoPlayLiveMediaWidgetState extends State<AutoPlayLiveMediaWidget> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _hasVideoError = false;

  @override
  void initState() {
    super.initState();
    _initMedia();
  }

  @override
  void didUpdateWidget(AutoPlayLiveMediaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _disposeVideo();
      _initMedia();
    }
  }

  bool _isVideoUrl(String url) {
    final clean = url.toLowerCase().split('?').first;
    return clean.endsWith('.mp4') ||
        clean.endsWith('.mov') ||
        clean.endsWith('.webm') ||
        clean.endsWith('.m4v') ||
        clean.endsWith('.mkv') ||
        clean.endsWith('.avi') ||
        clean.endsWith('.3gp') ||
        url.toLowerCase().contains('/video') ||
        url.toLowerCase().contains('format=mp4') ||
        url.toLowerCase().contains('live_video');
  }

  bool _isAnimatedImageUrl(String url) {
    final clean = url.toLowerCase().split('?').first;
    return clean.endsWith('.gif') || clean.endsWith('.webp');
  }

  void _initMedia() {
    final rawUrl = widget.url;
    if (rawUrl == null || rawUrl.isEmpty) return;

    final formatted = UrlValidator.formatImageUrl(rawUrl);
    if (formatted.isEmpty || !UrlValidator.isValidUrl(formatted)) return;

    if (_isVideoUrl(formatted)) {
      _hasVideoError = false;
      try {
        final controller = VideoPlayerController.networkUrl(
          Uri.parse(formatted),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
        _videoController = controller;

        // Ensure volume is 0 BEFORE initialization to guarantee browser autoplay compliance
        controller.setVolume(0.0);
        controller.setLooping(true);

        controller.initialize().then((_) {
          if (!mounted || _videoController != controller) return;
          controller.setLooping(true);
          controller.setVolume(0.0);
          controller.play();
          setState(() {
            _isVideoInitialized = true;
          });
        }).catchError((err) {
          debugPrint('AutoPlayLiveMediaWidget video error: $err');
          if (!mounted) return;
          setState(() {
            _isVideoInitialized = false;
            _hasVideoError = true;
          });
        });
      } catch (e) {
        debugPrint('AutoPlayLiveMediaWidget initialization error: $e');
        _hasVideoError = true;
      }
    }
  }

  void _disposeVideo() {
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;
    _isVideoInitialized = false;
    _hasVideoError = false;
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  void _resumeVideoIfPaused() {
    if (_videoController != null && _isVideoInitialized) {
      if (!_videoController!.value.isPlaying) {
        _videoController!.setVolume(0.0);
        _videoController!.play();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawUrl = widget.url;
    if (rawUrl == null || rawUrl.isEmpty) {
      return _wrapShape(widget.placeholder ?? const SizedBox.shrink());
    }

    final formatted = UrlValidator.formatImageUrl(rawUrl);
    if (formatted.isEmpty || !UrlValidator.isValidUrl(formatted)) {
      return _wrapShape(widget.errorWidget ?? const SizedBox.shrink());
    }

    Widget content;

    if (_isVideoUrl(formatted) && !_hasVideoError) {
      if (_isVideoInitialized && _videoController != null) {
        final size = _videoController!.value.size;
        final vWidth = size.width > 0 ? size.width : (widget.width ?? 300);
        final vHeight = size.height > 0 ? size.height : (widget.height ?? 300);

        content = GestureDetector(
          onTap: _resumeVideoIfPaused,
          child: FittedBox(
            fit: widget.fit,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: vWidth,
              height: vHeight,
              child: VideoPlayer(_videoController!),
            ),
          ),
        );
      } else {
        // While video initializes, show live image preview directly instead of infinite spinner!
        content = Image.network(
          formatted,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) =>
              widget.placeholder ??
              Container(
                color: Colors.black12,
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
        );
      }
    } else if (_isAnimatedImageUrl(formatted)) {
      // Handles animated WebP & GIF with infinite looping and hardware acceleration
      content = Image.network(
        formatted,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        gaplessPlayback: true,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return widget.placeholder ??
              Container(
                color: Colors.black12,
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
        },
        errorBuilder: (context, error, stackTrace) =>
            widget.errorWidget ??
            Container(
              color: Colors.black12,
              child: const Icon(Icons.broken_image_rounded),
            ),
      );
    } else {
      // Standard static images with robust disk & memory caching
      content = CachedNetworkImage(
        imageUrl: formatted,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        placeholder: (context, url) =>
            widget.placeholder ??
            Container(
              color: Colors.black12,
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        errorWidget: (context, url, error) =>
            widget.errorWidget ??
            Container(
              color: Colors.black12,
              child: const Icon(Icons.broken_image_rounded),
            ),
      );
    }

    return _wrapShape(content);
  }

  Widget _wrapShape(Widget child) {
    Widget sized = SizedBox(
      width: widget.width,
      height: widget.height,
      child: child,
    );

    if (widget.isCircle) {
      return ClipOval(child: sized);
    }

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: sized,
      );
    }

    return sized;
  }
}
