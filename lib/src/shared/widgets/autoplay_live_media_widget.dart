import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../../core/utils/url_validator.dart';

/// AutoPlayLiveMediaWidget
///
/// Seamlessly supports:
/// 1. Short live photo videos (.mp4, .mov, .webm) with silent looping autoplay.
/// 2. Animated GIFs (.gif) with smooth infinite looping autoplay.
/// 3. Standard web images (.jpg, .jpeg, .png, .webp) with caching and placeholders.
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
        clean.endsWith('.mkv');
  }

  bool _isGifUrl(String url) {
    final clean = url.toLowerCase().split('?').first;
    return clean.endsWith('.gif');
  }

  void _initMedia() {
    final rawUrl = widget.url;
    if (rawUrl == null || rawUrl.isEmpty) return;

    final formatted = UrlValidator.formatImageUrl(rawUrl);
    if (formatted.isEmpty || !UrlValidator.isValidUrl(formatted)) return;

    if (_isVideoUrl(formatted)) {
      final controller = VideoPlayerController.networkUrl(Uri.parse(formatted));
      _videoController = controller;

      controller.initialize().then((_) {
        if (!mounted || _videoController != controller) return;
        controller.setLooping(true);
        controller.setVolume(0.0);
        controller.play();
        setState(() {
          _isVideoInitialized = true;
        });
      }).catchError((_) {
        if (!mounted) return;
        setState(() {
          _isVideoInitialized = false;
        });
      });
    }
  }

  void _disposeVideo() {
    _videoController?.dispose();
    _videoController = null;
    _isVideoInitialized = false;
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
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

    if (_isVideoUrl(formatted)) {
      if (_isVideoInitialized && _videoController != null) {
        content = SizedBox.expand(
          child: FittedBox(
            fit: widget.fit,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: _videoController!.value.size.width > 0
                  ? _videoController!.value.size.width
                  : (widget.width ?? 100),
              height: _videoController!.value.size.height > 0
                  ? _videoController!.value.size.height
                  : (widget.height ?? 100),
              child: VideoPlayer(_videoController!),
            ),
          ),
        );
      } else {
        content = widget.placeholder ??
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
      }
    } else if (_isGifUrl(formatted)) {
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
