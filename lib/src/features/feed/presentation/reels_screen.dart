import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/post_repository.dart';
import '../../user/data/user_repository.dart';
import '../domain/post.dart';
import 'widgets/tiktok_reel_page.dart';
import 'providers/reel_controller_provider.dart';

enum ReelFeedMode { following, forYou }

final reelsProvider = StreamProvider.family<List<Post>, ({ReelFeedMode mode, String? userId})>((ref, args) {
  final repo = ref.watch(postRepositoryProvider);
  if (args.mode == ReelFeedMode.following) {
    final userId = args.userId;
    if (userId == null) return Stream<List<Post>>.value(const []);
    return repo.watchFollowingPosts(userId, limit: 30).map(
      (posts) => posts.where((post) => post.mediaType.name == 'video').toList(),
    );
  }
  return repo.watchVideoPosts(limit: 30);
});

class ReelsScreen extends ConsumerStatefulWidget {
  final List<Post> videos;
  final int initialIndex;

  const ReelsScreen({
    super.key,
    required this.videos,
    this.initialIndex = 0,
  });

  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends ConsumerState<ReelsScreen> {
  late final PageController _pageController;
  int _currentIndex = 0;
  bool _hasInitialized = false;
  int _lastPostsLength = -1;
  ReelFeedMode _feedMode = ReelFeedMode.forYou;

  @override
  void initState() {
    super.initState();
    final maxIndex = widget.videos.isEmpty ? 0 : widget.videos.length - 1;
    _currentIndex = widget.videos.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, maxIndex);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void didUpdateWidget(covariant ReelsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.videos.length != oldWidget.videos.length) {
      _syncIndexWithPosts(widget.videos);
      _hasInitialized = false;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _syncIndexWithPosts(List<Post> posts) {
    if (_lastPostsLength == posts.length) return;
    _lastPostsLength = posts.length;

    final maxIndex = posts.isEmpty ? 0 : posts.length - 1;
    final nextIndex = _currentIndex.clamp(0, maxIndex);
    _currentIndex = nextIndex;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients || posts.isEmpty) return;
      _pageController.jumpToPage(nextIndex);
    });
  }

  Widget _buildViewer(List<Post> posts) {
    if (posts.isEmpty) {
      return const Center(
        child: Text('No videos found', style: TextStyle(color: Colors.white)),
      );
    }

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          physics: const BouncingScrollPhysics(),
          allowImplicitScrolling: true,
          itemCount: posts.length,
          onPageChanged: (index) {

            setState(() => _currentIndex = index);
            // Trigger preloading for the active and upcoming videos
            ref.read(reelControllerProvider.notifier).updateConfig(index, posts);
          },
          itemBuilder: (context, index) {
            final post = posts[index];
            return TikTokReelPage(
              post: post,
              isActive: index == _currentIndex,
            );
          },
        ),
        Positioned(
          left: 12,
          right: 12,
          top: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentIndex + 1}/${posts.length}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _buildFeedToggle(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeedToggle() {
    final isFollowing = _feedMode == ReelFeedMode.following;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleChip(
            label: 'Following',
            selected: isFollowing,
            onTap: () => _switchMode(ReelFeedMode.following),
          ),
          _buildToggleChip(
            label: 'For You',
            selected: !isFollowing,
            onTap: () => _switchMode(ReelFeedMode.forYou),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  void _switchMode(ReelFeedMode mode) {
    if (_feedMode == mode) return;
    setState(() {
      _feedMode = mode;
      _currentIndex = 0;
      _hasInitialized = false;
      _lastPostsLength = -1;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.jumpToPage(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final videos = widget.videos;
    final currentUserId = ref.watch(currentUserIdProvider);
    final reelsAsync = ref.watch(reelsProvider((mode: _feedMode, userId: currentUserId)));
    _syncIndexWithPosts(videos);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: videos.isNotEmpty
          ? _buildViewer(videos)
          : reelsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              error: (error, _) => Center(
                child: Text(
                  'Error loading reels: $error',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              data: (posts) {
                _syncIndexWithPosts(posts);

                // Initial preloading if this is the first data load
                if (posts.isNotEmpty && !_hasInitialized) {
                  _hasInitialized = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      ref.read(reelControllerProvider.notifier).updateConfig(_currentIndex, posts);
                    }
                  });
                }

                return _buildViewer(posts);
              },
            ),
    );
  }
}
