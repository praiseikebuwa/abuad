import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/verification_badge.dart';
import '../../../core/utils/url_validator.dart';
import '../../user/data/user_repository.dart';
import '../../feed/data/post_repository.dart';
import '../../feed/domain/post.dart';
import '../../feed/presentation/widgets/post_card.dart';
import '../data/search_history_service.dart';
import 'package:shimmer/shimmer.dart';


class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late TabController _tabController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                      : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),

          // Main Content
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildSearchHeader(isDark),

                // Content View (Discover or Search Results)
                Expanded(
                  child: _query.isEmpty
                      ? _buildDiscoverView(isDark)
                      : _buildSearchResultsView(isDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          // Glassmorphic Search Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.1),
                    width: 0.5,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      ref.read(searchHistoryProvider.notifier).addQuery(value.trim());
                    }
                  },
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Search Nest, people, groups...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 15,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      size: 22,
                    ),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.cancel_rounded, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ),

          // Categorized Search Tabs (Shown only when searching)
          if (_query.isNotEmpty) ...[
            const SizedBox(height: 8),
            Theme(
              data: Theme.of(context).copyWith(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: AppColors.secondaryTeal,
                labelColor: isDark ? Colors.white : Colors.black,
                unselectedLabelColor: Colors.grey,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(text: "Top"),
                  Tab(text: "Latest"),
                  Tab(text: "People"),
                  Tab(text: "Media"),
                ],
              ),
            ),
          ],

          if (_query.isEmpty) ...[
            const SizedBox(height: 12),
            // Quick Tags (Horizontal)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _TrendChip(
                    label: "🔥 Trending",
                    isDark: isDark,
                    onTap: () {
                      final q = "#trending";
                      setState(() {
                        _searchController.text = q;
                        _query = q;
                      });
                      ref.read(searchHistoryProvider.notifier).addQuery(q);
                    },
                  ),
                  _TrendChip(
                    label: "🎓 News",
                    isDark: isDark,
                    onTap: () {
                      final q = "#news";
                      setState(() {
                        _searchController.text = q;
                        _query = q;
                      });
                      ref.read(searchHistoryProvider.notifier).addQuery(q);
                    },
                  ),
                  _TrendChip(
                    label: "🏆 Sports",
                    isDark: isDark,
                    onTap: () {
                      final q = "#sports";
                      setState(() {
                        _searchController.text = q;
                        _query = q;
                      });
                      ref.read(searchHistoryProvider.notifier).addQuery(q);
                    },
                  ),
                  _TrendChip(
                    label: "🎭 Life",
                    isDark: isDark,
                    onTap: () {
                      final q = "#life";
                      setState(() {
                        _searchController.text = q;
                        _query = q;
                      });
                      ref.read(searchHistoryProvider.notifier).addQuery(q);
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDiscoverView(bool isDark) {
    return ListView(
      padding: const EdgeInsets.only(top: 8),
      children: [
        // Recent History
        _buildHistorySection(isDark),

        // Suggested Users Carousel
        const _SuggestedUsersCarousel(),

        const Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Trending Now",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                "What people are talking about",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),

        // Trending Tags Cloud
        _buildTrendingTags(isDark),

        const Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            "Discover Campus",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),

        // Masonry Grid for Posts
        const _DiscoverMasonryGrid(),

        const SizedBox(height: 100), // Bottom navigation space
      ],
    );
  }

  Widget _buildSearchResultsView(bool isDark) {
    return TabBarView(
      controller: _tabController,
      children: [
        _SearchResultsList(query: _query, filter: 'top'),
        _SearchResultsList(query: _query, filter: 'latest'),
        _PeopleSearchResults(query: _query),
        _SearchResultsList(query: _query, filter: 'media'),
      ],
    );
  }

  Widget _buildHistorySection(bool isDark) {
    final searchHistory = ref.watch(searchHistoryProvider);
    if (searchHistory.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Recent",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              GestureDetector(
                onTap: () => ref.read(searchHistoryProvider.notifier).clearHistory(),
                child: Text(
                  "Clear all",
                  style: TextStyle(
                    color: AppColors.secondaryTeal,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 36,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: searchHistory.length,
            itemBuilder: (context, index) {
              final query = searchHistory[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InputChip(
                  label: Text(query),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _searchController.text = query;
                      _query = query;
                    });
                    ref.read(searchHistoryProvider.notifier).addQuery(query);
                  },
                  onDeleted: () => ref.read(searchHistoryProvider.notifier).removeQuery(query),
                  deleteIcon: Icon(
                    Icons.close,
                    size: 14,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  side: BorderSide.none,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTrendingTags(bool isDark) {
    final trendingTagsAsync = ref.watch(trendingTagsProvider);

    return trendingTagsAsync.when(
      data: (tags) {
        if (tags.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text("No trending tags yet", style: TextStyle(color: Colors.grey, fontSize: 13)),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags.map((tagData) {
              final tag = tagData['tag'] as String;
              final count = tagData['count'] as int;
              final hashtag = tag.startsWith('#') ? tag : '#$tag';

              return InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _searchController.text = hashtag;
                    _query = hashtag;
                  });
                  ref.read(searchHistoryProvider.notifier).addQuery(hashtag);
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.secondaryTeal.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hashtag,
                        style: const TextStyle(
                          color: AppColors.secondaryTeal,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      if (count > 1) ...[
                        const SizedBox(width: 4),
                        Text(
                          "• $count",
                          style: TextStyle(
                            color: AppColors.secondaryTeal.withValues(alpha: 0.6),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(6, (i) => Shimmer.fromColors(
            baseColor: isDark ? Colors.white10 : Colors.black12,
            highlightColor: isDark ? Colors.white24 : Colors.black26,
            child: Container(
              width: 80 + (i * 10).toDouble(),
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          )),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _TrendChip extends StatelessWidget {
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _TrendChip({
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isDark
                ? Colors.white.withValues(alpha: 0.8)
                : Colors.black.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SuggestedUsersCarousel extends ConsumerWidget {
  const _SuggestedUsersCarousel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userRepo = ref.watch(userRepositoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            "Who to follow",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        SizedBox(
          height: 200,
          child: StreamBuilder<List<AppUser>>(
            stream: userRepo.watchPopularUsers(),
            builder: (context, snapshot) {
              final users = snapshot.data ?? [];
              if (users.isEmpty) return const SizedBox.shrink();

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return Container(
                    width: 140,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.05),
                      ),
                      boxShadow: isDark
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: Consumer(
                      builder: (context, ref, child) {
                        final isFollowing =
                            ref.watch(isFollowingProvider(user.uid)).value ??
                            false;
                        final currentUid = ref.watch(currentUserIdProvider);
                        final isMe = currentUid == user.uid;

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              children: [
                            UserAvatar(
                              userId: user.uid,
                              avatarUrl: user.avatarUrl,
                              displayName: user.displayName,
                              radius: 30,
                              showStoryRing: true,
                            ),
                                if (user.isVerified)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.1,
                                            ),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: VerificationBadge(
                                        type: user.verificationType,
                                        size: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              user.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              "@${user.handle}",
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            if (!isMe)
                              ElevatedButton(
                                onPressed: () {
                                  HapticFeedback.mediumImpact();
                                  if (isFollowing) {
                                    ref
                                        .read(userRepositoryProvider)
                                        .unfollowUser(user.uid);
                                  } else {
                                    ref
                                        .read(userRepositoryProvider)
                                        .followUser(user.uid);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isFollowing
                                      ? Colors.transparent
                                      : AppColors.secondaryTeal,
                                  foregroundColor: isFollowing
                                      ? AppColors.secondaryTeal
                                      : Colors.white,
                                  elevation: 0,
                                  minimumSize: const Size(double.infinity, 30),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: isFollowing
                                        ? const BorderSide(
                                            color: AppColors.secondaryTeal,
                                          )
                                        : BorderSide.none,
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                                child: Text(
                                  isFollowing ? "Following" : "Follow",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DiscoverMasonryGrid extends ConsumerWidget {
  const _DiscoverMasonryGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postRepo = ref.watch(postRepositoryProvider);
    return StreamBuilder<List<Post>>(
      stream: postRepo.watchSuggestedPosts(),
      builder: (context, snapshot) {
        final posts = snapshot.data ?? [];
        if (posts.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: MasonryGridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return _MasonryPostItem(post: post, index: index)
                  .animate(delay: (index * 50).ms)
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: 0.2, end: 0, curve: Curves.easeOutQuart);
            },
          ),
        );
      },
    );
  }
}

class _MasonryPostItem extends StatelessWidget {
  final Post post;
  final int index;

  const _MasonryPostItem({required this.post, required this.index});

  @override
  Widget build(BuildContext context) {
    final hasMedia = post.mediaUrl.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => context.push('/post/${post.id}'),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: AspectRatio(
            aspectRatio: (index % 3 == 0) ? 0.8 : 1.1, // Dynamic aspect ratio
            child: Stack(
              children: [
                // Background Content
                Positioned.fill(
                  child: (hasMedia && UrlValidator.isValidUrl(post.mediaUrl))
                      ? CachedNetworkImage(
                          imageUrl: post.mediaUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => _buildPlaceholder(isDark),
                          errorWidget: (context, url, error) => _buildPlaceholder(isDark),
                        )
                      : _buildTextBackground(isDark),
                ),

                // Glassmorphic Overlay & Shine Effect
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.6),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.4),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),

                // Diagonal Shine
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white.withValues(alpha: 0.05),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                        begin: const Alignment(-1.5, -1.0),
                        end: const Alignment(1.5, 1.0),
                        stops: const [0.45, 0.5, 0.55],
                      ),
                    ),
                  ),
                ),

                // Top Left: Content Type Icons
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(height: 8),
                        const Icon(
                          Icons.image_outlined,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Left: Relevance Bubble (Profile + Stats)
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            UserAvatar(
                              userId: post.authorId,
                              avatarUrl: post.authorAvatarUrl,
                              displayName: post.authorName,
                              radius: 12,
                              showStoryRing: false,
                              enableDefaultTap: false,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "popular",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom Right: Engagement Bubble (Heart + Count)
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.favorite_rounded,
                          color: Colors.pinkAccent,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatCount(post.likesCount),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF1E293B) : Colors.grey[200],
      child: Center(
        child: Icon(
          Icons.image_outlined,
          color: isDark ? Colors.white10 : Colors.black12,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildTextBackground(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.secondaryTeal.withOpacity(0.8),
            AppColors.secondaryTeal.withOpacity(0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          post.content,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}

String _formatCount(int count) {
  if (count >= 1000000) return "${(count / 1000000).toStringAsFixed(1)}M";
  if (count >= 1000) return "${(count / 1000).toStringAsFixed(1)}K";
  return count.toString();
}

class _SearchResultsList extends ConsumerWidget {
  final String query;
  final String filter;

  const _SearchResultsList({required this.query, required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postRepo = ref.watch(postRepositoryProvider);

    return StreamBuilder<List<Post>>(
      stream: postRepo.searchPosts(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SearchSkeleton();
        }

        var posts = snapshot.data ?? [];

        // Apply filters
        if (filter == 'top') {
          posts.sort((a, b) => b.likesCount.compareTo(a.likesCount));
        } else if (filter == 'media') {
          posts = posts.where((p) => p.mediaUrl.isNotEmpty).toList();
        }

        if (posts.isEmpty) {
          return _NoResultsView(query: query);
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8),
          itemCount: posts.length,
          itemBuilder: (context, index) => PostCard(post: posts[index]),
        );
      },
    );
  }
}

class _PeopleSearchResults extends ConsumerWidget {
  final String query;

  const _PeopleSearchResults({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userRepo = ref.watch(userRepositoryProvider);

    return StreamBuilder<List<AppUser>>(
      stream: userRepo.searchUsers(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SearchSkeleton();
        }

        final users = snapshot.data ?? [];

        if (users.isEmpty) {
          return _NoResultsView(query: query);
        }

        return ListView.separated(
          padding: const EdgeInsets.only(top: 8),
          itemCount: users.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final user = users[index];
            return ListTile(
              leading: UserAvatar(
                userId: user.uid,
                avatarUrl: user.avatarUrl,
                radius: 24,
              ),
              title: Row(
                children: [
                  Text(
                    user.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (user.isVerified) ...[
                    const SizedBox(width: 4),
                    VerificationBadge(type: user.verificationType, size: 14),
                  ],
                ],
              ),
              subtitle: Text(
                "@${user.handle}",
                style: const TextStyle(color: Colors.grey),
              ),
              trailing: Consumer(
                builder: (context, ref, child) {
                  final isFollowing =
                      ref.watch(isFollowingProvider(user.uid)).value ?? false;
                  final currentUid = ref.watch(currentUserIdProvider);
                  if (currentUid == user.uid) return const SizedBox.shrink();

                  return ElevatedButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      if (isFollowing) {
                        ref.read(userRepositoryProvider).unfollowUser(user.uid);
                      } else {
                        ref.read(userRepositoryProvider).followUser(user.uid);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFollowing
                          ? Colors.transparent
                          : AppColors.secondaryTeal,
                      foregroundColor: isFollowing
                          ? AppColors.secondaryTeal
                          : Colors.white,
                      elevation: 0,
                      side: isFollowing
                          ? const BorderSide(color: AppColors.secondaryTeal)
                          : null,
                      minimumSize: const Size(80, 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isFollowing ? "Following" : "Follow",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
              onTap: () => context.push('/user/${user.uid}'),
            );
          },
        );
      },
    );
  }
}

class _NoResultsView extends StatelessWidget {
  final String query;

  const _NoResultsView({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            "No results for '$query'",
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Try searching for something else",
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _SearchSkeleton extends StatelessWidget {
  const _SearchSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.builder(
      itemCount: 5,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 100,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
