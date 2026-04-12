import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../features/feed/domain/post.dart';
import '../../features/chat/data/chat_repository.dart';
import '../../features/user/data/user_repository.dart';
import 'user_avatar.dart';

class ShareSheet extends ConsumerStatefulWidget {
  final Post post;

  const ShareSheet({super.key, required this.post});

  static void show(BuildContext context, Post post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShareSheet(post: post),
    );
  }

  @override
  ConsumerState<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<ShareSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final channelsAsync = ref.watch(chatChannelsProvider);
    final currentUser = ref.watch(currentUserProvider).value;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF171B22).withOpacity(0.85)
                    : Colors.white.withOpacity(0.9),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05),
                  width: 0.5,
                ),
              ),
              child: Column(
                children: [
                  // Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Share Post',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),

                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: 'Search people or chats...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                  ),

                  Expanded(
                    child: CustomScrollView(
                      controller: scrollController,
                      slivers: [
                        // Recent Chats
                        if (_searchQuery.isEmpty) ...[
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              child: Text(
                                'Recent Chats',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: 110,
                              child: channelsAsync.when(
                                data: (channels) => ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  scrollDirection: Axis.horizontal,
                                  itemCount: channels.length,
                                  itemBuilder: (context, index) {
                                    final channel = channels[index];
                                    final otherId = channel.memberIds.firstWhere(
                                      (id) => id != currentUser?.uid,
                                      orElse: () => '',
                                    );
                                    final name = channel.type == 'group'
                                        ? (channel.displayName ?? 'Group')
                                        : (channel.memberNames[otherId] ?? 'User');
                                    final avatar = channel.type == 'group'
                                        ? channel.displayAvatarUrl
                                        : channel.memberAvatars[otherId];

                                    return _ShareRecipientItem(
                                      name: name,
                                      avatarUrl: avatar,
                                      userId: otherId,
                                      onShare: () => _shareToChannel(channel.id),
                                    );
                                  },
                                ),
                                loading: () => const Center(child: CircularProgressIndicator()),
                                error: (_, __) => const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        ],

                        // Suggested / Search Results
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                            child: Text(
                              'Suggested',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        
                        _searchQuery.isEmpty 
                          ? ref.watch(followingProvider(currentUser?.uid ?? '')).when(
                              data: (following) => SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final user = following[index];
                                    return _ShareListTile(
                                      user: user,
                                      onShare: () => _shareToUser(user),
                                    );
                                  },
                                  childCount: following.length,
                                ),
                              ),
                              loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
                              error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                            )
                          : StreamBuilder<List<AppUser>>(
                              stream: ref.read(userRepositoryProvider).searchUsers(_searchQuery),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) return const SliverToBoxAdapter(child: SizedBox.shrink());
                                final users = snapshot.data!;
                                return SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final user = users[index];
                                      return _ShareListTile(
                                        user: user,
                                        onShare: () => _shareToUser(user),
                                      );
                                    },
                                    childCount: users.length,
                                  ),
                                );
                              },
                            ),
                      ],
                    ),
                  ),

                  // Bottom Actions
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _BottomActionButton(
                            icon: Icons.link,
                            label: 'Copy Link',
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: 'https://abuadapp.web.app/post/${widget.post.id}'));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Link copied to clipboard')),
                              );
                              Navigator.pop(context);
                            },
                          ),
                          _BottomActionButton(
                            icon: Icons.share,
                            label: 'More',
                            onTap: () {
                              Share.share(
                                'Check out this post on ABUAD Nest: https://abuadapp.web.app/post/${widget.post.id}',
                                subject: 'Share Post',
                              );
                              Navigator.pop(context);
                            },
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

  Future<void> _shareToChannel(String channelId) async {
    try {
      await ref.read(chatRepositoryProvider).sendMessage(
        channelId,
        'Shared a post with you',
        type: 'text',
        sharedPostId: widget.post.id,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shared successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing: $e')),
        );
      }
    }
  }

  Future<void> _shareToUser(AppUser user) async {
    try {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) return;
      
      final channelId = await ref.read(chatRepositoryProvider).createOrGetChannel(
        user.uid,
        otherUserName: user.displayName,
        otherUserAvatar: user.avatarUrl,
        currentUserName: currentUser.displayName,
        currentUserAvatar: currentUser.avatarUrl,
      );
      
      await _shareToChannel(channelId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class _ShareRecipientItem extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final String userId;
  final VoidCallback onShare;

  const _ShareRecipientItem({
    required this.name,
    this.avatarUrl,
    required this.userId,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GestureDetector(
        onTap: onShare,
        child: Column(
          children: [
            UserAvatar(
              userId: userId,
              avatarUrl: avatarUrl,
              radius: 30,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 70,
              child: Text(
                name.split(' ')[0],
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareListTile extends StatelessWidget {
  final AppUser user;
  final VoidCallback onShare;

  const _ShareListTile({required this.user, required this.onShare});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: UserAvatar(
        userId: user.uid,
        avatarUrl: user.avatarUrl,
        radius: 20,
      ),
      title: Text(
        user.displayName,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
      subtitle: Text('@${user.handle}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
      trailing: ElevatedButton(
        onPressed: onShare,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondaryTeal,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
          minimumSize: const Size(60, 32),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: const Text('Send', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }
}

class _BottomActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BottomActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
