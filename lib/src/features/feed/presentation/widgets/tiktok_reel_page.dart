import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../data/post_repository.dart';
import '../../domain/post.dart' as domain;
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/share_sheet.dart';
import '../providers/feed_provider.dart';
import 'animated_like_button.dart';
import 'reel_comment_sheet.dart';

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
    with AutomaticKeepAliveClientMixin {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isBuffering = false;
  bool _isMuted = true;
  bool _showPlayHint = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  Future<void> _initializeController() async {
    if (widget.post.mediaUrl.isEmpty) return;

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.post.mediaUrl),
    );
    controller.addListener(_videoListener);
    controller.setLooping(true);
    _controller = controller;

    try {
      await controller.initialize();
      await controller.setVolume(_isMuted ? 0 : 0.8);
      if (widget.isActive) {
        await controller.play();
      }
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint('TikTokReelPage video error: ');
    }
  }

  void _videoListener() {
    if (!mounted) return;
    final isBuffering = _controller?.value.isBuffering ?? false;
    if (isBuffering != _isBuffering) {
      setState(() => _isBuffering = isBuffering);
    }
    if (_controller?.value.isPlaying ?? false) {
      if (_showPlayHint) {
        setState(() => _showPlayHint = false);
      }
    }
  }

  @override
  void didUpdateWidget(covariant TikTokReelPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (widget.isActive && !oldWidget.isActive) {
      _controller!.play();
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller!.pause();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
  }

  double get _progressValue {
    if (_controller == null || !_controller!.value.isInitialized) return 0;
    final duration = _controller!.value.duration.inMilliseconds;
    if (duration == 0) return 0;
    final position = _controller!.value.position.inMilliseconds.clamp(
      0,
      duration,
    );
    return position / duration;
  }

  void _togglePlayback() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
      setState(() => _showPlayHint = true);
    } else {
      _controller!.play();
      setState(() => _showPlayHint = false);
    }
  }

  void _toggleMute() {
    if (_controller == null) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0 : 0.8);
    });
  }

  Future<void> _openComments(domain.Post post) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReelCommentSheet(post: post),
    );
  }

  void _showEngagementMenu(domain.Post post) {
    if (widget.onBoost != null) {
      widget.onBoost!();
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withValues(alpha: 0.85),
      builder: (context) => Container(
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
              subtitle: const Text('Show it to more students on ABUAD Nest'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Boost queued â€” good luck!')),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.emoji_emotions_outlined,
                color: Colors.amber,
              ),
              title: const Text('Add reaction'),
              subtitle: const Text('Send a quick emoji response'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reaction added!')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final repo = ref.watch(postRepositoryProvider);

    return StreamBuilder<domain.Post?>(
      stream: repo.watchPost(widget.post.id),
      builder: (context, snapshot) {
        final livePost = snapshot.data ?? widget.post;
        final firebaseLiked =
            ref.watch(isPostLikedProvider(livePost.id)).value ?? false;
        final optimisticMap = ref.watch(optimisticLikeProvider);
        final optimisticOverride = optimisticMap.containsKey(livePost.id)
            ? optimisticMap[livePost.id]!
            : null;
        final isLiked = optimisticOverride ?? firebaseLiked;
        final likeDelta = optimisticMap.containsKey(livePost.id)
            ? (optimisticMap[livePost.id]! ? 1 : -1)
            : 0;
        final likeCount = (livePost.likesCount + likeDelta).clamp(0, 999999);

        return GestureDetector(
          onTap: _togglePlayback,
          onLongPress: () => _showEngagementMenu(livePost),
          child: Container(
            color: Colors.black,
            child: Stack(
              children: [
                // Video Background
                Positioned.fill(child: _buildVideoLayer()),

                // Loading/Buffering indicator
                if (!_isInitialized || _isBuffering)
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
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

                Positioned.fill(child: _buildGradientOverlay()),

                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Videos',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Follow request sent'),
                                ),
                              );
                            },
                            style: FilledButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: AppColors.secondaryTeal,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: const Text('Follow'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                Positioned(
                  left: 16,
                  right: 120,
                  bottom: MediaQuery.of(context).padding.bottom + 120,
                  child: SafeArea(
                    top: false,
                    child: _buildCaptionSection(livePost),
                  ),
                ),

                Positioned(
                  right: 16,
                  bottom: MediaQuery.of(context).padding.bottom + 140,
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

                Positioned(
                  left: 0,
                  right: 0,
                  bottom: MediaQuery.of(context).padding.bottom + 64,
                  child: SafeArea(
                    top: false,
                    child: _buildCommentHint(context, livePost.commentsCount),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoLayer() {
    if (_isInitialized && _controller != null) {
      final size = _controller!.value.size;
      final width = size.width > 0 ? size.width : 1;
      final height = size.height > 0 ? size.height : 1;
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: 30,
            height: 40,
            child: VideoPlayer(_controller!),
          ),
        ),
      );
    }
    return Container(color: Colors.black);
  }

  Widget _buildGradientOverlay() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black87],
          stops: [0.45, 1],
        ),
      ),
    );
  }

  Widget _buildCaptionSection(domain.Post post) {
    final cleanHashtags = post.hashtags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .map((tag) => tag.startsWith('#') ? tag : '#$tag')
        .toList();
    final tagsLine = cleanHashtags.join(' ');
    final authorHandle = post.authorHandle.isNotEmpty
        ? '@${post.authorHandle}'
        : post.authorName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          post.content.trim().isEmpty ? 'New video' : post.content,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.4,
          ),
        ),
        if (tagsLine.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            tagsLine,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              letterSpacing: 0.4,
            ),
          ),
        ],
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(
              Icons.music_note_outlined,
              size: 14,
              color: Colors.white70,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Original audio � $authorHandle',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
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
        if (avatarUrl != null && avatarUrl.isNotEmpty)
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white24,
            backgroundImage: CachedNetworkImageProvider(avatarUrl),
          )
        else
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white24,
            child: Text(
              post.authorName.isNotEmpty ? post.authorName[0] : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        const SizedBox(height: 12),
        IconButton(
          icon: Icon(
            _isMuted ? Icons.volume_off : Icons.volume_up,
            color: Colors.white,
          ),
          onPressed: _toggleMute,
        ),
        AnimatedLikeButton(
          isLiked: isLiked,
          count: likeCount,
          showCount: true,
          iconSize: 32,
          onTap: () async {
            final firebaseLiked =
                ref.watch(isPostLikedProvider(post.id)).value ?? false;
            ref
                .read(optimisticLikeProvider.notifier)
                .toggle(post.id, firebaseLiked);
            try {
              await ref.read(postRepositoryProvider).toggleLike(post.id);
              ref.read(optimisticLikeProvider.notifier).confirm(post.id);
            } catch (_) {
              ref
                  .read(optimisticLikeProvider.notifier)
                  .revert(post.id, firebaseLiked);
            }
          },
        ),
        const SizedBox(height: 16),
        _ActionIconButton(
          icon: Icons.chat_bubble_outline,
          label: post.commentsCount,
          onTap: () => _openComments(post),
        ),
        _ActionIconButton(
          icon: Icons.rocket_launch,
          label: post.repostCount,
          onTap: () => _showEngagementMenu(post),
        ),
        _ActionIconButton(
          icon: Icons.share,
          label: post.viewsCount,
          onTap: () => ShareSheet.show(context, post),
        ),
      ],
    );
  }

  Widget _buildCommentHint(BuildContext context, int commentsCount) {
    final label = commentsCount == 1 ? 'comment' : 'comments';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$commentsCount $label',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final int label;
  final VoidCallback onTap;

  const _ActionIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: onTap,
          ),
          Text(
            label.toString(),
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
