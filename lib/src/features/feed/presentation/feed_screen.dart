import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../data/post_repository.dart';
import '../domain/post.dart' as domain;
import 'widgets/post_card.dart';
import 'widgets/feed_loading_skeleton.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(postRepositoryProvider);
    final selectedChannel = ref.watch(feedChannelProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'ABUAD Nest',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: isDark ? Colors.white : Colors.white,
          ),
        ),
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.inkTealGradient,
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () => context.push('/profile'),
            child: CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.15),
              child: Icon(
                Icons.person,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: Colors.white,
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
                ),
                _TabItem(
                  label: 'General',
                  id: 'general',
                  selectedId: selectedChannel,
                  isDark: isDark,
                ),
                _TabItem(
                  label: 'Engineering',
                  id: 'engineering',
                  selectedId: selectedChannel,
                  isDark: isDark,
                ),
                _TabItem(
                  label: 'Hostel',
                  id: 'hostel',
                  selectedId: selectedChannel,
                  isDark: isDark,
                ),
                _TabItem(
                  label: 'Confessions',
                  id: 'confessions',
                  selectedId: selectedChannel,
                  isDark: isDark,
                ),
                _TabItem(
                  label: 'Freshers',
                  id: 'freshers',
                  selectedId: selectedChannel,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(color: theme.scaffoldBackgroundColor),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 140,
              decoration: const BoxDecoration(
                gradient: AppColors.inkTealGradient,
              ),
            ),
          ),
          RefreshIndicator(
            onRefresh: () async {
              await Future.delayed(const Duration(seconds: 1));
            },
            color: theme.colorScheme.primary,
            child: StreamBuilder<List<domain.Post>>(
              stream: repo.watchPosts(),
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

                var posts = snapshot.data ?? [];

                if (selectedChannel != 'all') {
                  posts = posts
                      .where((p) => p.channelId == selectedChannel)
                      .toList();
                }

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
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    thickness: 1,
                    color: isDark ? Colors.grey[900] : Colors.grey[200],
                  ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push(
            '/create-post',
            extra: selectedChannel == 'all' ? 'general' : selectedChannel,
          );
        },
        backgroundColor: theme.colorScheme.secondary,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: AppColors.primaryInk, size: 28),
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

  const _TabItem({
    required this.label,
    required this.id,
    required this.selectedId,
    required this.isDark,
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
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.18)
              : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? Colors.white54 : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
