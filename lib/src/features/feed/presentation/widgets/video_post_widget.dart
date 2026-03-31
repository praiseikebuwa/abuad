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
  final bool _isPlaying = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-initialize to show first frame if possible or just be ready
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    if (_controller != null) return;

    setState(() => _isLoading = true);
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );
      await _controller!.initialize();
      setState(() {
        _isInitialized = true;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Video initialization error: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: widget.height,
        width: double.infinity,
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Show thumbnail while not initialized
            if (!_isInitialized)
              if (widget.thumbnailUrl != null)
                CachedNetworkImage(
                  imageUrl: widget.thumbnailUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: widget.height,
                )
              else
                const Center(
                  child: Icon(
                    Icons.movie_outlined,
                    color: Colors.white24,
                    size: 64,
                  ),
                ),

            // The Video Player
            if (_isInitialized && _controller != null)
              Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              ),

            // Large Play Button Overlay (when paused or not started)
            if (!_isPlaying && !_isLoading)
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

            // Loading indicator
            if (_isLoading)
              const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),

            // Simple Replay Overlay
            if (_isInitialized &&
                _controller != null &&
                _controller!.value.position == _controller!.value.duration)
              const Center(
                child: Icon(Icons.replay, color: Colors.white, size: 48),
              ),
          ],
        ),
      ),
    );
  }
}
