import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/post.dart';
import '../../data/post_repository.dart';
import '../../../../core/widgets/verification_badge.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../../shared/widgets/share_sheet.dart';
import 'video_more_menu.dart';
import 'reel_comment_sheet.dart';

class PremiumVideoPlayer extends ConsumerStatefulWidget {
  final Post post;
  final bool autoPlay;

  const PremiumVideoPlayer({
    super.key,
    required this.post,
    this.autoPlay = true,
  });

  @override
  ConsumerState<PremiumVideoPlayer> createState() => _PremiumVideoPlayerState();
}

class _PremiumVideoPlayerState extends ConsumerState<PremiumVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _showControls = true;
  Timer? _controlsTimer;
  bool _isVfxActive = false;
  BoxFit _fitMode = BoxFit.cover;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  Future<void> _initializeController() async {
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.post.mediaUrl),
    );

    try {
      await _controller.initialize();
      await _controller.setLooping(true);
      if (widget.autoPlay) {
        await _controller.play();
      }
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }

      _controller.addListener(_videoListener);
      _startControlsTimer();
    } catch (e) {
      debugPrint("Video initialization error: $e");
    }
  }

  void _videoListener() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_videoListener);
    _controller.dispose();
    _controlsTimer?.cancel();
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startControlsTimer();
    }
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller.value.isPlaying) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return GestureDetector(
      onTap: _toggleControls,
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            // Video with Dynamic Fit Mode
            Positioned.fill(
              child: FittedBox(
                fit: _fitMode,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            ),

            // Subtle Cinematic Filter (VFX)
            if (_isVfxActive)
              Positioned.fill(
                child: Container(
                  color: Colors.amber.withOpacity(0.12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 0.1, sigmaY: 0.1),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.withOpacity(0.05),
                            Colors.transparent,
                            Colors.orange.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Gradients for readability
            _buildGradients(),

            // Top Bar
            _buildTopBar(),

            // Profile info area (Bottom Left)
            _buildBottomInfo(),

            // Side Interaction Column
            _buildSideActions(),

            // Video Timeline (Progress)
            if (_showControls) _buildVideoTimeline(),
          ],
        ),
      ),
    );
  }

  Widget _buildGradients() {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 120,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black54, Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 250,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black54, Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    final topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 80 + topPadding,
        padding: EdgeInsets.only(top: topPadding, left: 8, right: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 22,
              ),
              onPressed: () => context.pop(),
            ),
            IconButton(
              icon: const Icon(
                Icons.more_horiz_rounded,
                color: Colors.white,
                size: 28,
              ),
              onPressed: () => VideoMoreMenu.show(context, widget.post),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomInfo() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Positioned(
      left: 16,
      bottom: 24 + bottomPadding,
      right: 80,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: UserAvatar(
                  userId: widget.post.authorId,
                  avatarUrl: widget.post.authorAvatarUrl,
                  radius: 20,
                  showStoryRing: false,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.post.authorName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          shadows: [
                            Shadow(blurRadius: 10, color: Colors.black54),
                          ],
                        ),
                      ),
                      if (widget.post.isVerified) ...[
                        const SizedBox(width: 4),
                        VerificationBadge(
                          type: widget.post.verificationType,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                  Text(
                    widget.post.authorHandle.startsWith('@')
                        ? widget.post.authorHandle
                        : '@${widget.post.authorHandle}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      shadows: const [
                        Shadow(blurRadius: 10, color: Colors.black54),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.post.content,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.3,
              shadows: [Shadow(blurRadius: 10, color: Colors.black45)],
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSideActions() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Positioned(
      right: 12,
      bottom: 40 + bottomPadding,
      child: Column(
        children: [
          Consumer(
            builder: (context, ref, child) {
              final isLiked =
                  ref.watch(isPostLikedProvider(widget.post.id)).value ?? false;
              return _SideActionItem(
                icon: isLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: _formatCount(widget.post.likesCount),
                iconColor: isLiked ? Colors.pink : Colors.white,
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(postRepositoryProvider).toggleLike(widget.post.id);
                },
              );
            },
          ),
          const SizedBox(height: 16),
          _SideActionItem(
            icon: Icons.chat_bubble_rounded,
            label: _formatCount(widget.post.commentsCount),
            onTap: () {
              HapticFeedback.lightImpact();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => ReelCommentSheet(post: widget.post),
              );
            },
          ),
          const SizedBox(height: 16),
          _SideActionItem(
            icon: Icons.ios_share_rounded,
            label: "Send",
            onTap: () {
              HapticFeedback.lightImpact();
              ShareSheet.show(context, widget.post);
            },
          ),
          const SizedBox(height: 24),
          IconButton(
            icon: Icon(
              _fitMode == BoxFit.cover
                  ? Icons.zoom_in_map_rounded
                  : Icons.zoom_out_map_rounded,
              color: Colors.white.withOpacity(0.8),
              size: 26,
            ),
            onPressed: () {
              HapticFeedback.mediumImpact();
              setState(() {
                _fitMode = _fitMode == BoxFit.cover
                    ? BoxFit.contain
                    : BoxFit.cover;
              });
            },
          ),
          const SizedBox(height: 8),
          IconButton(
            icon: Icon(
              Icons.auto_awesome_rounded,
              color: _isVfxActive
                  ? Colors.amber
                  : Colors.white.withOpacity(0.8),
              size: 26,
            ),
            onPressed: () {
              HapticFeedback.mediumImpact();
              setState(() {
                _isVfxActive = !_isVfxActive;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVideoTimeline() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.only(bottom: 4),
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: SliderComponentShape.noThumb,
            overlayShape: SliderComponentShape.noOverlay,
            activeTrackColor: Colors.white70,
            inactiveTrackColor: Colors.white24,
          ),
          child: Slider(
            value: _controller.value.position.inMilliseconds.toDouble(),
            max: _controller.value.duration.inMilliseconds.toDouble(),
            onChanged: (val) {
              _controller.seekTo(Duration(milliseconds: val.toInt()));
            },
          ),
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return "${(count / 1000000).toStringAsFixed(1)}M";
    if (count >= 1000) return "${(count / 1000).toStringAsFixed(1)}K";
    return count.toString();
  }
}

class _SideActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconColor;

  const _SideActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon, color: iconColor, size: 30),
          onPressed: onTap,
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(blurRadius: 8, color: Colors.black45)],
          ),
        ),
      ],
    );
  }
}
