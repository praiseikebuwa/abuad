import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/url_validator.dart';
import '../../feed/data/post_repository.dart';
import '../../feed/domain/post.dart';
import '../../feed/presentation/widgets/post_card.dart';
import '../../../shared/widgets/user_avatar.dart';

class HashtagScreen extends ConsumerStatefulWidget {
  final String tag;

  const HashtagScreen({super.key, required this.tag});

  @override
  ConsumerState<HashtagScreen> createState() => _HashtagScreenState();
}

class _HashtagScreenState extends ConsumerState<HashtagScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Post> _posts = [];
  bool _isLoading = true;
  bool _isFollowingTag = false;

  String get _cleanTag => widget.tag.replaceAll('#', '').trim();
  String get _hashtagDisplay => '#$_cleanTag';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTagState();
    _fetchHashtagPosts();
  }

  @override
  void didUpdateWidget(covariant HashtagScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tag != widget.tag) {
      _loadTagState();
      _fetchHashtagPosts();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTagState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final followedTags = prefs.getStringList('followed_hashtags') ?? [];
      if (mounted) {
        setState(() {
          _isFollowingTag = followedTags.contains(_cleanTag.toLowerCase());
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleFollowTag() async {
    HapticFeedback.mediumImpact();
    try {
      final prefs = await SharedPreferences.getInstance();
      final followedTags = prefs.getStringList('followed_hashtags') ?? [];
      final key = _cleanTag.toLowerCase();

      setState(() {
        if (_isFollowingTag) {
          followedTags.remove(key);
          _isFollowingTag = false;
        } else {
          followedTags.add(key);
          _isFollowingTag = true;
        }
      });

      await prefs.setStringList('followed_hashtags', followedTags);

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isFollowingTag
                  ? 'Now following $_hashtagDisplay'
                  : 'Unfollowed $_hashtagDisplay',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _fetchHashtagPosts() async {
    setState(() => _isLoading = true);
    try {
      final postRepo = ref.read(postRepositoryProvider);
      final results = await postRepo.searchPosts('#$_cleanTag');
      if (mounted) {
        setState(() {
          _posts = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Post> get _mediaPosts {
    return _posts.where((p) {
      return (p.mediaUrls.isNotEmpty) ||
          (p.mediaUrl.isNotEmpty &&
              p.mediaType != MediaType.none &&
              UrlValidator.isValidUrl(p.mediaUrl));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final trendingTagsAsync = ref.watch(trendingTagsProvider);

    // Compute trending rank if available
    int? trendingRank;
    trendingTagsAsync.whenData((tags) {
      for (int i = 0; i < tags.length; i++) {
        final t = (tags[i]['tag'] ?? tags[i]['name'] ?? '').toString().replaceAll('#', '').toLowerCase();
        if (t == _cleanTag.toLowerCase()) {
          trendingRank = i + 1;
          break;
        }
      }
    });

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/create-post', extra: {'initialText': '$_hashtagDisplay '});
        },
        backgroundColor: AppColors.primaryInk,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text(
          'Post $_hashtagDisplay',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 250,
              pinned: true,
              backgroundColor: theme.scaffoldBackgroundColor,
              elevation: 0,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    context.go('/search');
                  }
                },
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.share_outlined,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  onPressed: () {
                    // ignore: deprecated_member_use
                    Share.share(
                      'Check out what students are saying about $_hashtagDisplay on ABUAD Nest! https://abuadapp.com.ng/hashtag/$_cleanTag',
                      subject: 'Explore $_hashtagDisplay on ABUAD',
                    );
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              const Color(0xFF1E1B4B).withValues(alpha: 0.6),
                              const Color(0xFF0F172A),
                            ]
                          : [
                              AppColors.primaryInk.withValues(alpha: 0.08),
                              Colors.white,
                            ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              // Glowing Tag Icon
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(Icons.tag_rounded, color: Colors.white, size: 28),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _hashtagDisplay,
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.5,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          _isLoading
                                              ? 'Loading posts...'
                                              : '${_posts.length} ${_posts.length == 1 ? "post" : "posts"}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                                          ),
                                        ),
                                        if (trendingRank != null) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Text(
                                              '#$trendingRank Trending',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFFF59E0B),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Follow Tag Button
                              OutlinedButton(
                                onPressed: _toggleFollowTag,
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: _isFollowingTag
                                      ? (isDark ? Colors.white12 : Colors.grey[200])
                                      : AppColors.primaryInk,
                                  foregroundColor: _isFollowingTag
                                      ? (isDark ? Colors.white : Colors.black87)
                                      : Colors.white,
                                  side: BorderSide(
                                    color: _isFollowingTag
                                        ? Colors.transparent
                                        : AppColors.primaryInk,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                ),
                                child: Text(
                                  _isFollowingTag ? 'Following' : 'Follow',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          // Related Trending Tags Carousel
                          trendingTagsAsync.when(
                            data: (allTags) {
                              final related = allTags.where((t) {
                                final name = (t['tag'] ?? t['name'] ?? '').toString().replaceAll('#', '').toLowerCase();
                                return name != _cleanTag.toLowerCase();
                              }).take(6).toList();

                              if (related.isEmpty) return const SizedBox.shrink();

                              return SizedBox(
                                height: 30,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: related.length,
                                  itemBuilder: (context, index) {
                                    final tagItem = related[index];
                                    final name = (tagItem['tag'] ?? tagItem['name'] ?? '').toString();
                                    final cleanRel = name.replaceAll('#', '').trim();
                                    return GestureDetector(
                                      onTap: () => context.push('/hashtag/$cleanRel'),
                                      child: Container(
                                        margin: const EdgeInsets.only(right: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Text(
                                          '#$cleanRel',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? const Color(0xFF818CF8) : AppColors.primaryInk,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                            loading: () => const SizedBox.shrink(),
                            error: (_, _) => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: theme.scaffoldBackgroundColor,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: AppColors.primaryInk,
                    indicatorWeight: 3,
                    labelColor: isDark ? Colors.white : Colors.black87,
                    unselectedLabelColor: Colors.grey,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    tabs: [
                      Tab(text: 'Media Grid (${_mediaPosts.length})'),
                      Tab(text: 'All Posts (${_posts.length})'),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildMediaGrid(isDark),
                  _buildRecentPostsFeed(isDark),
                ],
              ),
      ),
    );
  }

  Widget _buildMediaGrid(bool isDark) {
    final mediaList = _mediaPosts;

    if (mediaList.isEmpty) {
      return _buildEmptyState(
        icon: Icons.photo_library_outlined,
        title: 'No media posts yet',
        subtitle: 'Photos and videos tagged $_hashtagDisplay will appear here.',
      );
    }

    return MasonryGridView.count(
      crossAxisCount: 3,
      mainAxisSpacing: 3,
      crossAxisSpacing: 3,
      padding: const EdgeInsets.all(4),
      itemCount: mediaList.length,
      itemBuilder: (context, index) {
        final post = mediaList[index];
        final isVideo = post.mediaType == MediaType.video;
        final imageUrl = post.mediaUrls.isNotEmpty ? post.mediaUrls.first : post.mediaUrl;

        return GestureDetector(
          onTap: () => context.push('/post/${post.id}', extra: post),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: (index % 5 == 0) ? 0.8 : 1.0,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      child: const Icon(Icons.broken_image_rounded, size: 24, color: Colors.grey),
                    ),
                  ),
                  if (isVideo)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14),
                      ),
                    ),
                  if (post.mediaUrls.length > 1)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.collections_rounded, color: Colors.white, size: 14),
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, Colors.black87],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.favorite_rounded, size: 11, color: Colors.white70),
                              const SizedBox(width: 3),
                              Text(
                                '${post.likesCount}',
                                style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          UserAvatar(
                            userId: post.authorId,
                            avatarUrl: post.authorAvatarUrl,
                            displayName: post.authorName,
                            radius: 8,
                            showStoryRing: false,
                            enableDefaultTap: false,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentPostsFeed(bool isDark) {
    if (_posts.isEmpty) {
      return _buildEmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'No posts with $_hashtagDisplay',
        subtitle: 'Be the first to start a conversation with this hashtag!',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: _posts.length,
      itemBuilder: (context, index) {
        final post = _posts[index];
        return PostCard(post: post);
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                context.push('/create-post', extra: {'initialText': '$_hashtagDisplay '});
              },
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: Text('Post $_hashtagDisplay'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryInk,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
