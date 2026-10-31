import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/post.dart' as domain;
import 'widgets/post_card.dart';
import 'widgets/people_you_may_know_carousel.dart';
import 'widgets/feed_loading_skeleton.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'providers/feed_provider.dart';
import '../../notifications/data/notification_repository.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../advertisements/data/advertisement_repository.dart';
import '../../advertisements/presentation/widgets/sponsored_ad_card.dart';
import '../../audio_spaces/presentation/controllers/audio_room_controller.dart';
import '../../audio_spaces/presentation/widgets/live_space_feed_card.dart';

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
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Consumer(
        builder: (context, bottomRef, child) {
          final settings = bottomRef.watch(feedAccessibilityProvider);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
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
                ),
              ),
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
          titleSpacing: 16,
          automaticallyImplyLeading: false,
          centerTitle: false,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Row(
            children: [
              Text(
                'ABUAD',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const Spacer(),
              _CompactTabItem(
                label: 'Following',
                isSelected: feedType == FeedType.following,
                onTap: () => ref
                    .read(feedTypeProvider.notifier)
                    .setType(FeedType.following),
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              _CompactTabItem(
                label: 'Discovery',
                isSelected: feedType == FeedType.discovery,
                onTap: () => ref
                    .read(feedTypeProvider.notifier)
                    .setType(FeedType.discovery),
                isDark: isDark,
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.podcasts_rounded, color: Color(0xFF7C4DFF)),
              tooltip: 'Live Audio Spaces',
              onPressed: () => context.push('/spaces'),
            ),
            Consumer(
              builder: (context, ref, child) {
                final notificationsAsync = ref.watch(userNotificationsProvider);
                final adsEnabled = ref.watch(adsEnabledProvider);
                final unreadCount = notificationsAsync.maybeWhen(
                  data: (n) => n.where((notif) => !notif.isRead).length,
                  orElse: () => 0,
                );

                return PopupMenuButton<String>(
                  icon: unreadCount > 0
                      ? Badge(
                          label: Text('$unreadCount'),
                          child: Icon(
                            Icons.more_vert,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        )
                      : Icon(
                          Icons.more_vert,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                  onSelected: (value) {
                    if (value == 'spaces') {
                      context.push('/spaces');
                    } else if (value == 'notifications') {
                      context.push('/notifications');
                    } else if (value == 'advertisements') {
                      context.push('/advertisements');
                    } else if (value == 'settings') {
                      context.push('/settings');
                    } else if (value == 'accessibility') {
                      _showAccessibilitySheet();
                    }
                  },
                  itemBuilder: (context) => [
                    if (adsEnabled)
                      PopupMenuItem(
                        value: 'advertisements',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.campaign_outlined,
                              size: 20,
                              color: Color(0xFF00E5FF),
                            ),
                            const SizedBox(width: 12),
                            const Text('Advertise / Promo'),
                          ],
                        ),
                      ),
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
                      value: 'spaces',
                      child: Row(
                        children: [
                          Icon(
                            Icons.podcasts_rounded,
                            size: 20,
                            color: Color(0xFF7C4DFF),
                          ),
                          const SizedBox(width: 12),
                          const Text('Live Audio Spaces'),
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
                await ref.read(paginatedFeedProvider.notifier).refresh();
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

                      // Filter by selected channel/category in discovery mode
                      List<domain.Post> channelPosts = posts;
                      if (feedType == FeedType.discovery && selectedChannel != 'all') {
                        if (selectedChannel == 'reels') {
                          channelPosts = posts.where((p) =>
                            p.mediaType == domain.MediaType.video ||
                            p.mediaUrl.toLowerCase().contains('.mp4') ||
                            p.mediaUrl.toLowerCase().contains('.mov') ||
                            p.mediaUrl.toLowerCase().contains('.webm') ||
                            p.mediaUrl.toLowerCase().contains('/videos/') ||
                            p.hashtags.any((h) => h.toLowerCase().contains('reel') || h.toLowerCase().contains('video'))
                          ).toList();
                        } else {
                          channelPosts = posts.where((p) {
                            final ch = selectedChannel.toLowerCase();
                            return p.channelId.toLowerCase() == ch ||
                                p.hashtags.any((h) => h.toLowerCase().contains(ch)) ||
                                p.content.toLowerCase().contains('#$ch');
                          }).toList();
                        }
                      }

                      if (channelPosts.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (selectedChannel == 'confessions')
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.4), width: 2),
                                  ),
                                  child: const Text('🎭', style: TextStyle(fontSize: 48)),
                                )
                              else
                                Icon(
                                  selectedChannel == 'reels'
                                      ? Icons.movie_outlined
                                      : (feedType == FeedType.following
                                          ? Icons.people_outline
                                          : Icons.feed_outlined),
                                  size: 64,
                                  color: isDark
                                      ? Colors.grey[700]
                                      : Colors.grey[300],
                                ),
                              const SizedBox(height: 16),
                              Text(
                                selectedChannel == 'confessions'
                                    ? 'No Confessions Yet'
                                    : (selectedChannel == 'reels'
                                        ? 'No video reels yet'
                                        : (feedType == FeedType.following
                                            ? 'No posts from people you follow'
                                            : (selectedChannel == 'all'
                                                ? 'No posts yet'
                                                : 'No posts in $selectedChannel'))),
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : Colors.black87,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (selectedChannel == 'confessions') ...[
                                const Text(
                                  '100% Anonymous • Share your secrets, campus crushes & raw thoughts.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.purpleAccent, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Your identity is completely hidden from all other students.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    context.push('/create-post', extra: {'channelId': 'confessions'});
                                  },
                                  icon: const Text('🎭', style: TextStyle(fontSize: 16)),
                                  label: const Text('Write Secret Confession', style: TextStyle(fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurpleAccent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    elevation: 6,
                                  ),
                                ),
                              ] else if (selectedChannel == 'reels') ...[
                                const Text(
                                  'Explore immersive full-screen campus videos & reels',
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () => context.push('/reels'),
                                  icon: const Icon(Icons.play_circle_fill_rounded),
                                  label: const Text('Open Reels Viewer'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.pinkAccent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  feedType == FeedType.following
                                      ? 'Follow more students to see their updates here!'
                                      : 'Be the first to post in this channel!',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.grey[600]
                                        : Colors.grey[500],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
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
                      final displayPosts = injectSystemPosts(channelPosts, injections);

                      final isLoadingMore = ref.watch(isLoadingMoreProvider);
                      final feedAds = ref.watch(feedAdsProvider).value ?? [];

                      return Column(
                        children: [
                          Expanded(
                            child: ListView.separated(
                              controller: _scrollController,
                              itemCount: displayPosts.length + (isLoadingMore ? 1 : 0),
                              padding: EdgeInsets.only(
                                top: feedType == FeedType.discovery ? 65 : 12,
                                bottom: 80,
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
                                // Prefetch next batch when user gets within 4 items of the bottom
                                if (index >= displayPosts.length - 4) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    ref.read(paginatedFeedProvider.notifier).loadMore();
                                  });
                                }

                                if (index == displayPosts.length) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                                    child: Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                final activeRooms = ref.watch(audioRoomsProvider).value?.where((r) => r.isLive).toList() ?? [];
                                final liveSpaceWidget = (index == 0 && activeRooms.isNotEmpty)
                                    ? LiveSpaceFeedCard(room: activeRooms.first)
                                    : null;

                                final post = displayPosts[index];
                                final showPeopleCarousel = index == 2 || (index > 2 && index % 10 == 2);

                                final postWidget = post.authorId == '__system__'
                                    ? _InjectedEventCard(post: post)
                                    : PostCard(
                                        post: post,
                                        onVideoTap: () {
                                          final videoPosts = displayPosts
                                              .where(
                                                (p) =>
                                                    p.mediaType ==
                                                        domain.MediaType.video ||
                                                    p.mediaUrl.toLowerCase().contains('.mp4') ||
                                                    p.mediaUrl.toLowerCase().contains('.mov') ||
                                                    p.mediaUrl.toLowerCase().contains('.webm') ||
                                                    p.mediaUrl.toLowerCase().contains('.m3u8') ||
                                                    p.id == post.id,
                                              )
                                              .toList();
                                          final videoIndex = videoPosts.indexWhere(
                                            (p) => p.id == post.id,
                                          );
                                          context.push(
                                            '/reels',
                                            extra: {
                                              'videos': videoPosts.isNotEmpty
                                                  ? videoPosts
                                                  : [post],
                                              'initialIndex':
                                                  videoIndex >= 0 ? videoIndex : 0,
                                            },
                                          );
                                        },
                                      );

                                final showAd = ref.watch(adsEnabledProvider) &&
                                    feedAds.isNotEmpty &&
                                    (index > 0 && index % 6 == 3);
                                final adWidget = showAd
                                    ? SponsoredAdCard(
                                        ad: feedAds[(index ~/ 6) % feedAds.length],
                                      )
                                    : null;

                                if (liveSpaceWidget != null || showPeopleCarousel || showAd) {
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      if (liveSpaceWidget != null) liveSpaceWidget,
                                      postWidget,
                                      if (showAd && adWidget != null) adWidget,
                                      if (showPeopleCarousel)
                                        const PeopleYouMayKnowCarousel(),
                                    ],
                                  );
                                }

                                return postWidget;
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
                      child: Row(
                        children: [
                          Expanded(
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
                          IconButton(
                            icon: Icon(
                              Icons.search_rounded,
                              color: isDark ? Colors.white70 : Colors.black87,
                              size: 22,
                            ),
                            onPressed: () {
                              context.push('/search');
                            },
                          ),
                          const SizedBox(width: 4),
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
        HapticFeedback.selectionClick();
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

class _CompactTabItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _CompactTabItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isDark ? Colors.white : AppColors.primaryInk;
    final inactiveColor = isDark
        ? Colors.white38
        : AppColors.primaryInk.withValues(alpha: 0.4);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2.5,
              width: isSelected ? 28 : 0,
              decoration: BoxDecoration(
                color: activeColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



// ──────────────────────────────────────────────────────────────────────────────

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
