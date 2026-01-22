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

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ABUAD Nest',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF0D47A1),
          ),
        ),
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () => context.push('/profile'),
            child: const CircleAvatar(
              backgroundImage: AssetImage('assets/images/logo.png'),
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _ChannelChip(
                  label: 'All',
                  id: 'all',
                  selectedId: selectedChannel,
                ),
                _ChannelChip(
                  label: 'General',
                  id: 'general',
                  selectedId: selectedChannel,
                ),
                _ChannelChip(
                  label: 'Engineering',
                  id: 'engineering',
                  selectedId: selectedChannel,
                ),
                _ChannelChip(
                  label: 'Hostel Life',
                  id: 'hostel',
                  selectedId: selectedChannel,
                ),
                _ChannelChip(
                  label: 'Confessions',
                  id: 'confessions',
                  selectedId: selectedChannel,
                ),
                _ChannelChip(
                  label: 'Freshers',
                  id: 'freshers',
                  selectedId: selectedChannel,
                ),
              ],
            ),
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _SocialFeatureCard(
                          title: 'Events',
                          icon: Icons.calendar_month,
                          color: Colors.orange,
                          onTap: () => context.push('/events'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _SocialFeatureCard(
                          title: 'Groups',
                          icon: Icons.groups,
                          color: Colors.purple,
                          onTap: () => context.push('/groups'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _SocialFeatureCard(
                          title: 'Resources',
                          icon: Icons.library_books,
                          color: Colors.teal,
                          onTap: () => context.push('/resources'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: SizedBox()), // Placeholder for balance
                    ],
                  ),
                ],
              ),
            ),
          ),
          StreamBuilder<List<domain.Post>>(
            stream: repo.watchPosts(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(child: FeedLoadingSkeleton());
              }
              if (snapshot.hasError) {
                return SliverFillRemaining(
                  child: Center(child: Text('Error: ${snapshot.error}')),
                );
              }

              var posts = snapshot.data ?? [];

              // Local Filtering (Ideally this moves to repo query)
              if (selectedChannel != 'all') {
                posts = posts
                    .where((p) => p.channelId == selectedChannel)
                    .toList();
              }

              if (posts.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 50.0),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.feed_outlined,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            selectedChannel == 'all'
                                ? 'No posts yet. Be the first to post!'
                                : 'No posts in #${selectedChannel.capitalize()}.',
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final post = posts[index];
                  return Column(
                    children: [
                      PostCard(post: post),
                      Divider(height: 1, thickness: 1, color: Colors.grey[100]),
                    ],
                  );
                }, childCount: posts.length),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Pass selected channel to create screen
          context.push(
            '/create-post',
            extra: selectedChannel == 'all' ? 'general' : selectedChannel,
          );
        },
        backgroundColor: Theme.of(context).primaryColor,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// Simple Notifier Provider for Channel Filter
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

class _ChannelChip extends ConsumerWidget {
  final String label;
  final String id;
  final String selectedId;

  const _ChannelChip({
    required this.label,
    required this.id,
    required this.selectedId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = id == selectedId;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) {
          ref.read(feedChannelProvider.notifier).setChannel(id);
        },
        backgroundColor: Colors.grey[100],
        selectedColor: const Color(0xFF0D47A1).withOpacity(0.1),
        labelStyle: TextStyle(
          color: isSelected ? const Color(0xFF0D47A1) : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? const Color(0xFF0D47A1) : Colors.transparent,
          ),
        ),
        showCheckmark: false,
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

class _SocialFeatureCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SocialFeatureCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
