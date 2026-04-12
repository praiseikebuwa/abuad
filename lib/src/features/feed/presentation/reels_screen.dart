import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/post_repository.dart';
import '../domain/post.dart';
import 'widgets/tiktok_reel_page.dart';

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
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
          itemCount: posts.length,
          onPageChanged: (index) {
            setState(() => _currentIndex = index);
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
          top: 32,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '/ videos',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(postRepositoryProvider);
    final videos = widget.videos;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: videos.isNotEmpty
          ? _buildViewer(videos)
          : StreamBuilder<List<Post>>(
              stream: repo.watchVideoPosts(limit: 30),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading reels: ', style: const TextStyle(color: Colors.white)),
                  );
                }

                final posts = snapshot.data ?? [];
                return _buildViewer(posts);
              },
            ),
    );
  }
}
