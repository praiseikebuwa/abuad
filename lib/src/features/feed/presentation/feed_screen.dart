import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/post.dart' as domain;
import '../data/post_repository.dart';
import 'widgets/post_card.dart';
import 'widgets/feed_loading_skeleton.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'providers/feed_provider.dart';
import '../../notifications/data/notification_repository.dart';
import 'package:google_fonts/google_fonts.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  late final ScrollController _scrollController;
  bool _isScrolledDown = false;
  bool _showNewPostsPill = false;
  String? _lastTopPostId;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    final offset = _scrollController.offset;

    // Pagination trigger
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll - offset < 500) {
        // Load more when user is near the bottom
        ref.read(paginatedFeedProvider.notifier).loadMore();
      }
    }

    if (offset > 400 && !_isScrolledDown) {
      if (mounted) setState(() => _isScrolledDown = true);
    } else if (offset <= 400 && _isScrolledDown) {
      // Auto-hide pill if user scrolls back to top
      if (mounted) {
        setState(() {
          _isScrolledDown = false;
          _showNewPostsPill = false;
        });
      }
    }
  }

  void _scrollToTop() {
    HapticFeedback.lightImpact();
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.fastOutSlowIn,
    );
    if (mounted) setState(() => _showNewPostsPill = false);
  }

  void _showAccessibilitySheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Consumer(
        builder: (context, bottomRef, child) {
          final settings = bottomRef.watch(feedAccessibilityProvider);
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.accessibility),
                  title: const Text('Accessibility & Safe Preview'),
                  subtitle: const Text(
                    'Adjust text size and auto-generated summaries for new posts.',
                  ),
                ),
                SwitchListTile(
                  value: settings.largeFonts,
                  title: const Text('Larger fonts'),
                  subtitle: const Text('Bigger text throughout the feed.'),
                  onChanged: (_) => bottomRef
                      .read(feedAccessibilityProvider.notifier)
                      .toggleLargeFonts(),
                ),
                SwitchListTile(
                  value: settings.blindMode,
                  title: const Text('Blind-mode summary'),
                  subtitle: const Text(
                    'Show quick text-only previews for new posts.',
                  ),
                  onChanged: (_) => bottomRef
                      .read(feedAccessibilityProvider.notifier)
                      .toggleBlindMode(),
                ),
                SwitchListTile(
                  value: settings.highContrast,
                  title: const Text('High Contrast'),
                  subtitle: const Text('Enhance text and icon clarity.'),
                  onChanged: (_) => bottomRef
                      .read(feedAccessibilityProvider.notifier)
                      .toggleHighContrast(),
                ),
                SwitchListTile(
                  value: settings.reducedMotion,
                  title: const Text('Reduced Motion'),
                  subtitle: const Text('Minimize UI animations.'),
                  onChanged: (_) => bottomRef
                      .read(feedAccessibilityProvider.notifier)
                      .toggleReducedMotion(),
                ),
                SwitchListTile(
                  value: settings.dyslexicFont,
                  title: const Text('Dyslexic Friendly'),
                  subtitle: const Text('Swap to an easier-to-read font.'),
                  onChanged: (_) => bottomRef
                      .read(feedAccessibilityProvider.notifier)
                      .toggleDyslexicFont(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedChannel = ref.watch(feedChannelProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;


    final feedType = ref.watch(feedTypeProvider);
    final accessibilityState = ref.watch(feedAccessibilityProvider);
    final textScaler = accessibilityState.largeFonts
        ? const TextScaler.linear(1.15)
        : MediaQuery.textScalerOf(context);

    // Apply Accessibility Overrides
    var currentTheme = theme;
    if (accessibilityState.highContrast) {
      currentTheme = theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          primary: isDark ? Colors.white : Colors.black,
          onPrimary: isDark ? Colors.black : Colors.white,
          secondary: isDark ? Colors.white : Colors.black,
        ),
        textTheme: theme.textTheme.apply(
          bodyColor: isDark ? Colors.white : Colors.black,
          displayColor: isDark ? Colors.white : Colors.black,
        ),
      );
    }

    final fontFamily = accessibilityState.dyslexicFont
        ? GoogleFonts.lexend().fontFamily
        : theme.textTheme.bodyLarge?.fontFamily;

    if (accessibilityState.reducedMotion) {
      Animate.restartOnHotReload = true; // Not ideal for toggle, but let's use logic below
    }

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: textScaler,
        disableAnimations: accessibilityState.reducedMotion,
      ),
      child: Theme(
        data: currentTheme.copyWith(
          textTheme: currentTheme.textTheme.apply(fontFamily: fontFamily),
        ),
        child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            'ABUAD Feed',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: isDark
                  ? const Color.fromARGB(255, 0, 0, 0)
                  : const Color.fromARGB(255, 0, 0, 0),
            ),
          ),
          centerTitle: false,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: GestureDetector(
              onTap: () => context.push('/profile'),
              child: CircleAvatar(
                backgroundColor: const Color.fromARGB(
                  255,
                  8,
                  36,
                  161,
                ).withValues(alpha: 0.15),
                child: Icon(
                  Icons.person,
                  color: const Color.fromARGB(255, 0, 0, 0),
                  size: 20,
                ),
              ),
            ),
          ),
          actions: [
            Consumer(
              builder: (context, ref, child) {
                final notificationsAsync = ref.watch(userNotificationsProvider);
                final unreadCount = notificationsAsync.maybeWhen(
                  data: (n) => n.where((notif) => !notif.isRead).length,
                  orElse: () => 0,
                );

                return PopupMenuButton<String>(
                  icon: unreadCount > 0
                      ? Badge(
                          label: Text('$unreadCount'),
                          child: const Icon(
                            Icons.more_vert,
                            color: Color.fromARGB(255, 0, 0, 0),
                          ),
                        )
                      : const Icon(
                          Icons.more_vert,
                          color: Color.fromARGB(255, 0, 0, 0),
                        ),
                  onSelected: (value) {
                    if (value == 'notifications') {
                      context.push('/notifications');
                    } else if (value == 'settings') {
                      context.push('/settings');
                    } else if (value == 'accessibility') {
                      _showAccessibilitySheet();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'notifications',
                      child: Row(
                        children: [
                          Icon(
                            Icons.notifications_outlined,
                            size: 20,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          const SizedBox(width: 12),
                          const Text('Notifications'),
                          if (unreadCount > 0) ...[
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.error,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'settings',
                      child: Row(
                        children: [
                          Icon(
                            Icons.settings_outlined,
                            size: 20,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          const SizedBox(width: 12),
                          const Text('Settings'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'accessibility',
                      child: Row(
                        children: [
                          Icon(
                            Icons.accessibility_new,
                            size: 20,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          const SizedBox(width: 12),
                          const Text('Accessibility'),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? Colors.white10
                        : Colors.black.withValues(alpha: 0.05),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  _MainTabItem(
                    label: 'Following',
                    isSelected: feedType == FeedType.following,
                    onTap: () => ref
                        .read(feedTypeProvider.notifier)
                        .setType(FeedType.following),
                    isDark: isDark,
                  ),
                  _MainTabItem(
                    label: 'Discovery',
                    isSelected: feedType == FeedType.discovery,
                    onTap: () => ref
                        .read(feedTypeProvider.notifier)
                        .setType(FeedType.discovery),
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),
        ),
        body: Stack(
          children: [
            // Mesh Background Elements
            Positioned.fill(
              child: Container(color: theme.scaffoldBackgroundColor),
            ),
            RefreshIndicator(
              onRefresh: () async {
                HapticFeedback.mediumImpact();
                ref.invalidate(paginatedFeedProvider);
                await Future.delayed(const Duration(milliseconds: 800));
              },
              color: theme.colorScheme.primary,
              displacement: feedType == FeedType.discovery ? 70 : 10,
              child: Consumer(
                builder: (context, ref, child) {
                  final feedAsync = ref.watch(paginatedFeedProvider);

                  return feedAsync.when(
                    loading: () => const FeedLoadingSkeleton(),
                    error: (error, stack) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Something went wrong',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              ref.invalidate(paginatedFeedProvider);
                            },
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
                    data: (posts) {
                      // Pulse Logic: Detect new posts & handle tab switches
                      if (posts.isNotEmpty) {
                        final topId = posts.first.id;

                        if (_lastTopPostId == null) {
                          _lastTopPostId = topId;
                        } else if (topId != _lastTopPostId &&
                            _isScrolledDown &&
                            !_showNewPostsPill) {
                          // New post arrived and we are scrolled down!
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() => _showNewPostsPill = true);
                            }
                          });
                        } else if (!_isScrolledDown) {
                          // Update latest seen ID if at top
                          _lastTopPostId = topId;
                        }
                      }

                      if (posts.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                feedType == FeedType.following
                                    ? Icons.people_outline
                                    : Icons.feed_outlined,
                                size: 64,
                                color: isDark
                                    ? Colors.grey[700]
                                    : Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                feedType == FeedType.following
                                    ? 'No posts from people you follow'
                                    : (selectedChannel == 'all'
                                          ? 'No posts yet'
                                          : 'No posts in this channel'),
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                feedType == FeedType.following
                                    ? 'Follow more students to see their updates here!'
                                    : 'Be the first to post!',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey[600]
                                      : Colors.grey[500],
                                  fontSize: 14,
                                ),
                              ),
                              if (feedType == FeedType.following)
                                Padding(
                                  padding: const EdgeInsets.only(top: 24),
                                  child: ElevatedButton(
                                    onPressed: () => ref
                                        .read(feedTypeProvider.notifier)
                                        .setType(FeedType.discovery),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          theme.colorScheme.secondary,
                                      foregroundColor: AppColors.primaryInk,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    child: const Text('Discover People'),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }

                      // Feature 4: Inject system/event posts every 10 items
                      final injections = [
                        createInjectedEventPost(
                          title: '📅 Campus Events',
                          body:
                              'Check the Events tab for upcoming campus activities, lectures, and social events!',
                          channel: 'all',
                          injectAtIndex: 0,
                        ),
                      ];
                      final displayPosts = injectSystemPosts(posts, injections);

                      return Column(
                        children: [
                          // F1: Trending Topics Pill — Discovery mode only
                          if (feedType == FeedType.discovery)
                            const _TrendingPill(),
                          Expanded(
                            child: ListView.separated(
                              controller: _scrollController,
                              itemCount: displayPosts.length,
                              padding: EdgeInsets.only(
                                top: feedType == FeedType.discovery ? 65 : 12,
                              ),
                              separatorBuilder: (context, index) {
                                return Divider(
                                  height: 1,
                                  thickness: 0.5,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.05),
                                );
                              },
                              itemBuilder: (context, index) {
                                final post = displayPosts[index];
                                if (post.authorId == '__system__') {
                                  return _InjectedEventCard(post: post);
                                }
                                return PostCard(
                                  post: post,
                                  onVideoTap: () {
                                    final videoPosts = displayPosts
                                        .where(
                                          (p) =>
                                              p.mediaType ==
                                              domain.MediaType.video,
                                        )
                                        .toList();
                                    final videoIndex = videoPosts.indexOf(post);
                                    if (videoIndex != -1) {
                                      context.push(
                                        '/reels',
                                        extra: {
                                          'videos': videoPosts,
                                          'index': videoIndex,
                                        },
                                      );
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),

            // "New Posts" Pulse Indicator (Floating Pill)
            if (_showNewPostsPill)
              Positioned(
                top: feedType == FeedType.discovery ? 75 : 20,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: _scrollToTop,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child:
                            Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondaryTeal.withValues(
                                      alpha: 0.9,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.secondaryTeal
                                            .withValues(alpha: 0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(
                                        Icons.arrow_upward,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Latest Posts',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                .animate()
                                .scale(
                                  duration: 300.ms,
                                  curve: Curves.easeOutBack,
                                )
                                .fadeIn(),
                      ),
                    ),
                  ),
                ),
              ),
            // Discovery Specific Sub-Header (Categories - GLASS)
            if (feedType == FeedType.discovery)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor.withValues(
                          alpha: 0.7,
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          _TabItem(
                            label: 'For You',
                            id: 'all',
                            selectedId: selectedChannel,
                            isDark: isDark,
                            icon: Icons.auto_awesome,
                            activeColor: Colors.blueAccent,
                          ),
                          _TabItem(
                            label: 'Reels',
                            id: 'reels',
                            selectedId: selectedChannel,
                            isDark: isDark,
                            icon: Icons.movie_outlined,
                            activeColor: Colors.pinkAccent,
                          ),
                          _TabItem(
                            label: 'General',
                            id: 'general',
                            selectedId: selectedChannel,
                            isDark: isDark,
                            icon: Icons.public,
                            activeColor: AppColors.primaryInk,
                          ),
                          _TabItem(
                            label: 'Engineering',
                            id: 'engineering',
                            selectedId: selectedChannel,
                            isDark: isDark,
                            icon: Icons.engineering,
                            activeColor: Colors.blue,
                          ),
                          _TabItem(
                            label: 'Hostel',
                            id: 'hostel',
                            selectedId: selectedChannel,
                            isDark: isDark,
                            icon: Icons.home_work,
                            activeColor: Colors.orange,
                          ),
                          _TabItem(
                            label: 'Confessions',
                            id: 'confessions',
                            selectedId: selectedChannel,
                            isDark: isDark,
                            icon: Icons.visibility_off,
                            activeColor: Colors.deepPurple,
                          ),
                          _TabItem(
                            label: 'Freshers',
                            id: 'freshers',
                            selectedId: selectedChannel,
                            isDark: isDark,
                            icon: Icons.school,
                            activeColor: Colors.green,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        floatingActionButton: Padding(
          padding: EdgeInsets.only(
            bottom: 5 + MediaQuery.of(context).padding.bottom,
          ), // Lift above bottom nav
          child: FloatingActionButton(
            heroTag: 'feed_fab',
            onPressed: () {
              context.push(
                '/create-post',
                extra: {
                  'channelId': selectedChannel == 'all'
                      ? 'general'
                      : selectedChannel,
                },
              );
            },
            backgroundColor: theme.colorScheme.secondary,
            elevation: 7,
            shape: const CircleBorder(),
            child: const Icon(Icons.add, color: AppColors.primaryInk, size: 28),
          ),
        ),
      ),
      )
    );
  }
  }


// Channel Provider
final feedChannelProvider = NotifierProvider<FeedChannelNotifier, String>(
  FeedChannelNotifier.new,
);

class FeedChannelNotifier extends Notifier<String> {
  @override
  String build() => 'all';

  void setChannel(String channelId) {
    state = channelId;
  }
}

// Twitter-style Tab Item
class _TabItem extends ConsumerWidget {
  final String label;
  final String id;
  final String selectedId;
  final bool isDark;
  final IconData icon;
  final Color activeColor;

  const _TabItem({
    required this.label,
    required this.id,
    required this.selectedId,
    required this.isDark,
    required this.icon,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = id == selectedId;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        ref.read(feedChannelProvider.notifier).setChannel(id);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? activeColor : activeColor)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDark
                      ? Colors.white.withValues(alpha: 0.3)
                      : AppColors.primaryInk.withValues(alpha: 0.1)),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : (isDark
                        ? Colors.white70
                        : AppColors.primaryInk.withValues(alpha: 0.6)),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : AppColors.primaryInk),
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum FeedType { following, discovery }

final feedTypeProvider = NotifierProvider<FeedTypeNotifier, FeedType>(
  FeedTypeNotifier.new,
);

class FeedTypeNotifier extends Notifier<FeedType> {
  @override
  FeedType build() => FeedType.discovery;

  void setType(FeedType type) {
    state = type;
  }
}

class _MainTabItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _MainTabItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            const Spacer(),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? (isDark ? Colors.white : AppColors.primaryInk)
                    : (isDark
                          ? Colors.white38
                          : AppColors.primaryInk.withAlpha(102)),
              ),
            ),
            const Spacer(),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 3,
              width: isSelected ? 80 : 0,
              decoration: BoxDecoration(
                color: isDark ? Colors.white : AppColors.primaryInk,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
class _TrendingPill extends ConsumerWidget {
  const _TrendingPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final trendingAsync = ref.watch(trendingTagsProvider);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor.withValues(alpha: 0.6) : Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : AppColors.primaryInk.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black12,
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: trendingAsync.when(
        data: (tags) {
          final filtered = tags.where((entry) {
            final tag = entry['tag'] as String?;
            return tag != null && tag.trim().isNotEmpty;
          }).toList();

          if (filtered.isEmpty) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Trending topics will appear here soon',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            );
          }

          return SizedBox(
            height: 54,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (context, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final entry = filtered[index];
                final rawTag = (entry['tag'] as String).trim();
                final cleanedTag = rawTag.startsWith('#') ? rawTag : '#$rawTag';
                final tagSlug = cleanedTag.replaceAll('#', '');
                final count = entry['count'] as int? ?? 0;

                if (tagSlug.isEmpty) return const SizedBox.shrink();

                return _TrendingTopicChip(
                  tag: cleanedTag,
                  count: count,
                  isDark: isDark,
                  onTap: () {
                    final encoded = Uri.encodeComponent(tagSlug);
                    context.push('/hashtag/$encoded');
                  },
                );
              },
            ),
          );
        },
        loading: () => SizedBox(
          height: 54,
          child: Center(
            child: SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                color: theme.colorScheme.primary,
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.3,
                ),
                minHeight: 3,
              ),
            ),
          ),
        ),
        error: (error, stackTrace) => Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Unable to load trending topics',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }
}

class _TrendingTopicChip extends StatelessWidget {
  final String tag;
  final int count;
  final bool isDark;
  final VoidCallback onTap;

  const _TrendingTopicChip({
    required this.tag,
    required this.count,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = isDark
        ? AppColors.inkTealGradient
        : AppColors.goldGradient;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tag,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              if (count > 0)
                Text(
                  '$count posts',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Feature 4: Injected System/Event Banner Card
// Renders a native, non-tap-to-detail card for  Feed platform announcements.
// ──────────────────────────────────────────────────────────────────────────────
class _InjectedEventCard extends StatelessWidget {
  final domain.Post post;
  const _InjectedEventCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1A237E), const Color(0xFF0D47A1)]
                  : [const Color(0xFF1976D2), const Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1565C0).withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => context.push('/events'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.campaign_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.authorName,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            post.content.replaceAll('**', '').split('\n').first,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            post.content
                                .replaceAll('**', '')
                                .split('\n')
                                .skip(2)
                                .join(' '),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white.withValues(alpha: 0.7),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.15, end: 0, duration: 350.ms);
  }
}
