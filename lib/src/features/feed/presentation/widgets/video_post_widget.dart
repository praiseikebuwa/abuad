import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

class VideoPostWidget extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final double height;

  const VideoPostWidget({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
    this.height = 250,
  });

  @override
  State<VideoPostWidget> createState() => _VideoPostWidgetState();
}

class _VideoPostWidgetState extends State<VideoPostWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isBuffering = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
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
      controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      controller.addListener(_videoListener);
      await controller.play();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _isInitialized = true;
        _isPlaying = true;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Video initialization error: $e");
      controller?.dispose();
    } finally {
      if (mounted && !_isInitialized) {
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
    if (isBuffering != _isBuffering) {
      setState(() => _isBuffering = isBuffering);
    }
    if (controller.value.isPlaying && !_isPlaying) {
      setState(() => _isPlaying = true);
    } else if (!controller.value.isPlaying && _isPlaying) {
      setState(() => _isPlaying = false);
    }
  }

  void _resetController() {
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    _isPlaying = false;
    _isBuffering = false;
    _hasError = false;
  }

  @override
  void dispose() {
    _resetController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: GestureDetector(
        onTap: _hasError ? null : _togglePlayback,
        child: Container(
          height: widget.height,
          width: double.infinity,
          color: Colors.black,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_isInitialized && _controller != null)
                AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                )
              else
                _buildPlaceholder(),

              if (_isLoading || _isBuffering)
                const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),

              if (_hasError)
                const Center(
                  child: Icon(
                    Icons.error_outline,
                    color: Colors.redAccent,
                    size: 48,
                  ),
                ),

              if (!_isPlaying && !_isLoading && !_hasError)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    if (widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: widget.thumbnailUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: widget.height,
        errorWidget: (_, __, ___) => Container(color: Colors.grey[900]),
        placeholder: (_, __) => Container(color: Colors.grey[900]),
      );
    }
    return const Center(
      child: Icon(
        Icons.movie_outlined,
        color: Colors.white24,
        size: 64,
      ),
    );
  }

  void _togglePlayback() {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (_controller!.value.isPlaying) {
      _controller!.pause();
      setState(() => _isPlaying = false);
    } else {
      _controller!.play();
      setState(() => _isPlaying = true);
    }
  }
}
