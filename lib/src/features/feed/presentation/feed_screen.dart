import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
      backgroundColor: isDark ? const Color(0xFF000000) : Colors.white,
      appBar: AppBar(
        title: Text(
          'ABUAD Nest',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: isDark ? Colors.white : const Color(0xFF0D47A1),
          ),
        ),
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        backgroundColor: isDark ? const Color(0xFF000000) : Colors.white,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () => context.push('/profile'),
            child: CircleAvatar(
              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              child: Icon(
                Icons.person,
                color: theme.colorScheme.primary,
                size: 20,
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: isDark ? Colors.white : Colors.black87,
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
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
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
      body: RefreshIndicator(
        onRefresh: () async {
          // Invalidate and refresh posts
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
                      onPressed: () {
                        // Trigger refresh
                      },
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              );
            }

            var posts = snapshot.data ?? [];

            // Filter by channel
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
              padding: EdgeInsets.zero,
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push(
            '/create-post',
            extra: selectedChannel == 'all' ? 'general' : selectedChannel,
          );
        },
        backgroundColor: theme.colorScheme.primary,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
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

    return GestureDetector(
      onTap: () {
        ref.read(feedChannelProvider.notifier).setChannel(id);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? (isDark ? Colors.white : Colors.black87)
                    : (isDark ? Colors.grey[500] : Colors.grey[600]),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 4,
              width: isSelected ? 40 : 0,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
