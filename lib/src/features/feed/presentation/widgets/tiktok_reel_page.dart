import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:flutter/gestures.dart';
import '../../data/post_repository.dart';
import '../../../user/data/user_repository.dart';
import '../../domain/post.dart' as domain;
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/share_sheet.dart';
import '../providers/feed_provider.dart';
import 'reel_comment_sheet.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../../core/utils/url_validator.dart';

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
  bool _isMuted = false;
  bool _showPlayHint = false;
  // Double-tap heart splash
  final List<Offset> _doubleTapPositions = [];

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


  void _onDoubleTap(Offset position, WidgetRef ref, domain.Post post) {
    setState(() {
      _doubleTapPositions.add(position);
    });

    // Handle the like logic
    final firebaseLiked = ref.read(isPostLikedProvider(post.id)).value ?? false;
    if (!firebaseLiked) {
      ref.read(optimisticLikeProvider.notifier).toggle(post.id, false);
      ref.read(postRepositoryProvider).toggleLike(post.id).then((_) {
        ref.read(optimisticLikeProvider.notifier).confirm(post.id);
      }).catchError((_) {
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Post saved!')),
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
        final likeCount = (livePost.likesCount + likeDelta).clamp(0, 9999999);

        return GestureDetector(
          onTap: _togglePlayback,
          onDoubleTapDown: (details) =>
              _onDoubleTap(details.localPosition, ref, livePost),
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

                // Bottom Content (Username, Caption, Hashtags)
                Positioned(
                  left: 16,
                  right: 80,
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  child: SafeArea(
                    top: false,
                    child: _buildCaptionSection(livePost),
                  ),
                ),

                // Sidebar Actions
                Positioned(
                  right: 12,
                  bottom: MediaQuery.of(context).padding.bottom + 80,
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

                // Music Disc (positioned relative to bottom right)
                Positioned(
                  right: 12,
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  child: SafeArea(top: false, child: _MusicDisc(post: livePost)),
                ),

                // Double Tap Hearts
                ..._doubleTapPositions.map((pos) => _buildHeartSplash(pos)),
              ],
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
      child: const Icon(
        Icons.favorite,
        color: Colors.redAccent,
        size: 100,
      )
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

  Widget _buildVideoLayer() {
    if (_isInitialized && _controller != null) {
      final size = _controller!.value.size;
      final width = (size.width > 0 ? size.width : 1.0).toDouble();
      final height = (size.height > 0 ? size.height : 1.0).toDouble();
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: width,
            height: height,
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
          colors: [
            Colors.transparent,
            Colors.black26,
            Colors.black54,
          ],
          stops: [0.55, 0.8, 1.0],
        ),
      ),
    );
  }

  Widget _buildCaptionSection(domain.Post post) {
    final authorHandle = post.authorHandle.isNotEmpty ? post.authorHandle : post.authorName;
    
    // Split content to handle hashtags
    final List<String> words = post.content.split(' ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            // Navigate to profile or print
            debugPrint('Username tapped: ${post.authorName}');
          },
          child: Text(
            authorHandle,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
            ),
          ),
        ),
        const SizedBox(height: 8),
        RichText(
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.3,
              shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
            ),
            children: words.map((word) {
              final isHashtag = word.startsWith('#');
              if (isHashtag) {
                return TextSpan(
                  text: '$word ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      debugPrint('Hashtag tapped: $word');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Searching for $word...')),
                      );
                    },
                );
              }
              return TextSpan(text: '$word ');
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(
              Icons.music_note_rounded,
              size: 16,
              color: Colors.white,
            ),
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
              const Positioned(
                bottom: -9,
                left: 0,
                right: 0,
                child: Center(child: _FollowButton()),
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

        // Comment
        _ActionIconButton(
          icon: Icons.chat_bubble_rounded,
          label: _formatNumber(post.commentsCount),
          onTap: () => _openComments(post),
        ),

        // Save
        Consumer(
          builder: (context, ref, child) {
            final isSaved =
                ref.watch(isPostSavedProvider(post.id)).value ?? false;
            return _ActionIconButton(
              icon: Icons.bookmark_rounded,
              iconColor: isSaved ? const Color(0xFFFFD700) : Colors.white,
              label: _formatNumber(post.savesCount),
              onTap: () async {
                try {
                  await ref.read(userRepositoryProvider).togglePostSave(post.id);
                } catch (e) {
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
          icon: Icons.reply_rounded,
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
  final double scaleX;

  const _ActionIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = Colors.white,
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
              transform: Matrix4.identity()..scale(scaleX, 1.0),
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black45, blurRadius: 2)],
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

class _MusicDiscState extends State<_MusicDisc> with SingleTickerProviderStateMixin {
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
          child: (widget.post.authorAvatarUrl != null &&
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

class _FollowButton extends StatelessWidget {
  const _FollowButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: const BoxDecoration(
        color: Color(0xFFFE2C55), // TikTok Red
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.add, color: Colors.white, size: 16),
    );
  }
}
