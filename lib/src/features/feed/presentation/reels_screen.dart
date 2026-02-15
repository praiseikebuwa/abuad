import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../domain/post.dart';
import '../data/post_repository.dart';
import 'widgets/animated_like_button.dart';
import '../../user/data/user_repository.dart';

class ReelsScreen extends ConsumerStatefulWidget {
  final List<Post> videos;
  final int initialIndex;

  const ReelsScreen({super.key, required this.videos, this.initialIndex = 0});

  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends ConsumerState<ReelsScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        controller: _pageController,
        itemCount: widget.videos.length,
        itemBuilder: (context, index) {
          return _ReelPlayerItem(post: widget.videos[index]);
        },
      ),
    );
  }
}

class _ReelPlayerItem extends ConsumerStatefulWidget {
  final Post post;

  const _ReelPlayerItem({required this.post});

  @override
  ConsumerState<_ReelPlayerItem> createState() => _ReelPlayerItemState();
}

class _ReelPlayerItemState extends ConsumerState<_ReelPlayerItem> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.post.mediaUrl),
    );
    await _controller!.initialize();
    await _controller!.setLooping(true);
    await _controller!.play();
    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video Player
        GestureDetector(
          onTap: () {
            if (_controller != null) {
              if (_controller!.value.isPlaying) {
                _controller!.pause();
              } else {
                _controller!.play();
              }
              setState(() {});
            }
          },
          child: Container(
            color: Colors.black,
            child: _isInitialized
                ? Center(
                    child: AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    ),
                  )
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
          ),
        ),

        // Gradient Overlay
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black54,
                ],
                stops: [0.0, 0.6, 1.0],
              ),
            ),
          ),
        ),

        // Right Action Bar
        Positioned(
          right: 16,
          bottom: 100,
          child: Column(
            children: [
              // Like Button
              Consumer(
                builder: (context, ref, child) {
                  final isLiked = ref
                      .watch(postRepositoryProvider)
                      .isPostLiked(post.id);
                  return StreamBuilder<bool>(
                    stream: isLiked,
                    builder: (context, snapshot) {
                      return Column(
                        children: [
                          AnimatedLikeButton(
                            isLiked: snapshot.data ?? false,
                            count: post.likesCount,
                            onTap: () => ref
                                .read(postRepositoryProvider)
                                .toggleLike(post.id),
                            iconSize: 32,
                            inactiveColor: Colors.white,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${post.likesCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 20),

              // Comment Button
              IconButton(
                icon: const Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.white,
                  size: 32,
                ),
                onPressed: () {
                  context.push('/post-detail', extra: post);
                },
              ),
              Text(
                '${post.commentsCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Share Button
              IconButton(
                icon: const Icon(Icons.share, color: Colors.white, size: 32),
                onPressed: () {}, // Todo share
              ),
            ],
          ),
        ),

        // Bottom Info
        Positioned(
          left: 16,
          bottom: 24,
          right: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: (post.authorAvatarUrl != null)
                        ? CachedNetworkImageProvider(post.authorAvatarUrl!)
                        : null,
                    child: (post.authorAvatarUrl == null)
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    post.authorName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Follow Button
                  Consumer(
                    builder: (context, ref, child) {
                      final currentUser = ref.watch(currentUserProvider).value;
                      if (currentUser?.uid == post.authorId) {
                        return const SizedBox.shrink();
                      }

                      final isFollowingAsync = ref.watch(
                        isFollowingProvider(post.authorId),
                      );

                      return isFollowingAsync.when(
                        data: (isFollowing) => GestureDetector(
                          onTap: () async {
                            if (isFollowing) {
                              await ref
                                  .read(userRepositoryProvider)
                                  .unfollowUser(post.authorId);
                            } else {
                              await ref
                                  .read(userRepositoryProvider)
                                  .followUser(post.authorId);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white),
                              borderRadius: BorderRadius.circular(20),
                              color: isFollowing
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : Colors.transparent,
                            ),
                            child: Text(
                              isFollowing ? 'Following' : 'Follow',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                post.content,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
