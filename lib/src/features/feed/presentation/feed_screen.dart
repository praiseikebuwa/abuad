import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../data/post_repository.dart';
import '../../user/data/user_repository.dart';
import '../domain/post.dart' as domain;
import 'widgets/post_card.dart';
import 'widgets/feed_loading_skeleton.dart';
import '../../notifications/presentation/widgets/notification_icon.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(postRepositoryProvider);
    final selectedChannel = ref.watch(feedChannelProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final blockedUsersAsync = ref.watch(blockedUsersProvider);
    final blockedUserIds = blockedUsersAsync.value ?? [];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'ABUAD Nest',
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
            onTap: () => context.go('/profile'),
            child: CircleAvatar(
              backgroundColor: const Color.fromARGB(
                255,
                8,
                36,
                161,
              ).withOpacity(0.15),
              child: Icon(
                Icons.person,
                color: const Color.fromARGB(255, 0, 0, 0),
                size: 20,
              ),
            ),
          ),
        ),
        actions: [
          const NotificationIcon(),
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: const Color.fromARGB(255, 0, 0, 0),
            ),
            onPressed: () => context.push('/settings'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white12 : Colors.white24,
                  width: 1,
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
      body: Stack(
        children: [
          // Mesh Background Elements
          Positioned.fill(
            child: Container(color: theme.scaffoldBackgroundColor),
          ),
          // Top Right Mesh
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondaryTeal.withValues(
                  alpha: isDark ? 0.2 : 0.15,
                ),
              ),
            ).animate().fadeIn(duration: 1000.ms),
          ),
          // Bottom Left Mesh
          Positioned(
            bottom: 100,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryInk.withValues(
                  alpha: isDark ? 0.3 : 0.1,
                ),
              ),
            ).animate().fadeIn(duration: 1200.ms),
          ),
          // Subtle Center Mesh
          Positioned(
            top: 200,
            right: 100,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentAmber.withValues(
                  alpha: isDark ? 0.05 : 0.03,
                ),
              ),
            ).animate().fadeIn(duration: 1500.ms),
          ),
          // Backdrop Filter for Mesh Blur
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: Colors.transparent),
            ),
          ),
          RefreshIndicator(
            onRefresh: () async {
              await Future.delayed(const Duration(seconds: 1));
            },
            color: theme.colorScheme.primary,
            child: StreamBuilder<List<domain.Post>>(
              stream: selectedChannel == 'all'
                  ? repo.watchPosts(blockedUserIds: blockedUserIds)
                  : selectedChannel == 'reels'
                  ? repo.watchVideoPosts(blockedUserIds: blockedUserIds)
                  : repo.watchChannelPosts(
                      selectedChannel,
                      blockedUserIds: blockedUserIds,
                    ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const FeedLoadingSkeleton();
                }
                if (snapshot.hasError) {
                  return Center(
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
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {},
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  );
                }

                final posts = snapshot.data ?? [];

                if (posts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.feed_outlined,
                          size: 64,
                          color: isDark ? Colors.grey[700] : Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          selectedChannel == 'all'
                              ? 'No posts yet'
                              : 'No posts in this channel',
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to post!',
                          style: TextStyle(
                            color: isDark ? Colors.grey[600] : Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: posts.length,
                  padding: const EdgeInsets.only(top: 12),
                  separatorBuilder: (context, index) {
                    return Divider(
                      height: 1,
                      thickness: 0.5,
                      color: isDark ? Colors.white10 : Colors.black12,
                    );
                  },
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return PostCard(post: post);
                  },
                );
              },
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
              extra: selectedChannel == 'all' ? 'general' : selectedChannel,
            );
          },
          backgroundColor: theme.colorScheme.secondary,
          elevation: 7,
          shape: const CircleBorder(),
          child: const Icon(Icons.add, color: AppColors.primaryInk, size: 28),
        ),
      ),
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
