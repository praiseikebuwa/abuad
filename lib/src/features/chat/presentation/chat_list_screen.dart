import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';

import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/verification_badge.dart';
import '../data/chat_repository.dart';
import '../domain/chat_channel.dart';
import '../../user/data/user_repository.dart';
import '../../stories/data/story_repository.dart';
import '../../stories/presentation/create_story_screen.dart';
import '../../stories/presentation/story_viewer_screen.dart';
import '../../stories/presentation/my_story_screen.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../data/chat_search_history_service.dart';
import 'package:toastification/toastification.dart';
import '../../../core/utils/url_validator.dart';


class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';
  int _currentIndex = 0; // 0: Chat, 1: Status

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(chatRepositoryProvider);
    final channelsStream = repo.watchChannels();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Chat and stories',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 24,
            color: Colors.white,
          ),
        ),
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.inkTealGradient),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white, size: 26),
            onSelected: (value) async {
              if (value == 'new_chat') context.push('/chat/user-search');
              if (value == 'new_group') context.push('/chat/create-group');
              if (value == 'chat_settings') context.push('/chat/settings');
              
              if (value == 'scan_qr') context.push('/chat/scanner');
              if (value == 'broadcast') context.push('/chat/broadcast');
              if (value == 'archived') setState(() => _selectedFilter = 'Archived');
              
              if (value == 'mark_all_read') {
                await ref.read(chatRepositoryProvider).markAllAsRead();
                if (mounted) {
                  toastification.show(
                    context: context,
                    title: const Text('All chats marked as read'),
                    autoCloseDuration: const Duration(seconds: 3),
                    type: ToastificationType.success,
                    style: ToastificationStyle.flatColored,
                  );
                }
              }
              
              if (value == 'clear_history') {
                await ref.read(chatSearchHistoryProvider.notifier).clearHistory();
                if (mounted) {
                  toastification.show(
                    context: context,
                    title: const Text('Search history cleared'),
                    autoCloseDuration: const Duration(seconds: 2),
                  );
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'scan_qr',
                child: ListTile(
                  leading: Icon(Icons.qr_code_scanner, color: AppColors.secondaryTeal),
                  title: const Text('Scan Profile QR'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'new_group',
                child: ListTile(
                  leading: Icon(Icons.group_add_outlined),
                  title: Text('New Group'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'new_chat',
                child: ListTile(
                  leading: Icon(Icons.person_add_outlined),
                  title: Text('New Chat'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'broadcast',
                child: ListTile(
                  leading: Icon(Icons.campaign_outlined),
                  title: Text('Broadcast Message'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'mark_all_read',
                child: ListTile(
                  leading: Icon(Icons.done_all),
                  title: Text('Mark All as Read'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'archived',
                child: ListTile(
                  leading: Icon(Icons.archive_outlined),
                  title: Text('Archived Chats'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'clear_history',
                child: ListTile(
                  leading: Icon(Icons.history_toggle_off),
                  title: Text('Clear Search History'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'chat_settings',
                child: ListTile(
                  leading: Icon(Icons.settings_outlined),
                  title: Text('Chat Settings'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Horizontal Navigation Switcher
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Center(
              child: _CapsuleSwitcher(
                currentIndex: _currentIndex,
                onChanged: (index) => setState(() => _currentIndex = index),
                isDark: isDark,
              ),
            ),
          ),
          
          if (_currentIndex == 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                onSubmitted: (val) => ref.read(chatSearchHistoryProvider.notifier).addQuery(val),
                decoration: InputDecoration(
                  hintText: 'Search chats, groups...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey[200],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          // Main View Content
          Expanded(
            child: _currentIndex == 1
                ? _StatusListView(
                    isDark: isDark,
                  )
                : StreamBuilder<List<ChatChannel>>(
                    stream: channelsStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      final allChannels = snapshot.data ?? [];
                      final currentUserId = repo.currentUserId;

                      if (allChannels.isEmpty) {
                        return _EmptyState(
                          onStartConversation: () =>
                              context.push('/chat/user-search'),
                          isDark: isDark,
                        );
                      }

                      return _buildChatView(allChannels, currentUserId, isDark);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_currentIndex == 0) {
            context.push('/chat/user-search');
          } else {
            _pickStoryImage(context);
          }
        },
        backgroundColor: AppColors.secondaryTeal,
        elevation: 4,
        child: Icon(
          _currentIndex == 0 ? Icons.chat_bubble_outline : Icons.camera_alt,
          color: Colors.white,
        ),
      ),
    );
  }

  Future<void> _pickStoryImage(BuildContext context) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final image = await picker.pickImage(source: source);
      if (image != null && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateStoryScreen(initialImagePath: image.path),
          ),
        );
      }
    }
  }

  Widget _buildChatView(
    List<ChatChannel> allChannels,
    String? currentUserId,
    bool isDark,
  ) {
    final filteredChannels = allChannels.where((c) {
      final isArchived = c.archivedBy.contains(currentUserId);
      if (_selectedFilter == 'Archived') {
        if (!isArchived) return false;
      } else {
        if (isArchived) return false;
      }

      if (_selectedFilter == 'Unread') {
        final unreadCount = c.unreadCounts[currentUserId] ?? 0;
        if (unreadCount == 0) return false;
      } else if (_selectedFilter == 'Groups') {
        if (c.type != 'group') return false;
      }

      if (_searchQuery.isEmpty) return true;

      final isGroup = c.type == 'group';
      final otherUserId = isGroup
          ? null
          : c.memberIds.firstWhere(
              (id) => id != currentUserId,
              orElse: () => '',
            );
      final name = isGroup
          ? (c.displayName ?? '')
          : (c.memberNames[otherUserId] ?? '');
      return name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    filteredChannels.sort((a, b) {
      final aPinned = a.pinnedBy.contains(currentUserId);
      final bPinned = b.pinnedBy.contains(currentUserId);
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;
      return b.lastMessageTime.compareTo(a.lastMessageTime);
    });

    return Column(
      key: const ValueKey('chat_view'),
      children: [
        // Filter Bar (Chips)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _FilterChip(
                label: 'All',
                isSelected: _selectedFilter == 'All',
                onTap: () => setState(() => _selectedFilter = 'All'),
                isDark: isDark,
              ),
              _FilterChip(
                label: 'Unread',
                isSelected: _selectedFilter == 'Unread',
                onTap: () => setState(() => _selectedFilter = 'Unread'),
                isDark: isDark,
              ),
              _FilterChip(
                label: 'Archived',
                isSelected: _selectedFilter == 'Archived',
                onTap: () => setState(() => _selectedFilter = 'Archived'),
                isDark: isDark,
              ),
              _FilterChip(
                label: 'Groups',
                isSelected: _selectedFilter == 'Groups',
                onTap: () => setState(() => _selectedFilter = 'Groups'),
                isDark: isDark,
              ),
              _FilterChip(
                label: '+',
                isSelected: false,
                onTap: () {},
                isDark: isDark,
              ),
            ],
          ),
        ),


        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text(
                'Messages',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),

        // Chat List
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: filteredChannels.length,
            itemBuilder: (context, index) {
              final channel = filteredChannels[index];
              return _SnapchatListItem(
                channel: channel,
                currentUserId: currentUserId,
                isDark: isDark,
              );
            },
          ),
        ),
      ],
    );
  }
}

// Capsule Switcher (Vertical Pill Toggle)
class _CapsuleSwitcher extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final bool isDark;

  const _CapsuleSwitcher({
    required this.currentIndex,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: 52,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[200],
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Indicator
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: currentIndex == 0 ? 4 : 164,
            top: 4,
            bottom: 4,
            child: Container(
              width: 152,
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32),
                borderRadius: BorderRadius.circular(22),
              ),
            ),
          ),
          // Items
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(0),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: currentIndex == 0 ? Colors.white : Colors.grey,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Chat',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: currentIndex == 0
                                ? Colors.white
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(1),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle_outlined,
                          color: currentIndex == 1 ? Colors.white : Colors.grey,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Status',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: currentIndex == 1
                                ? Colors.white
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Vertical Status List View
// Vertical Status List View
class _StatusListView extends ConsumerStatefulWidget {
  final bool isDark;

  const _StatusListView({
    super.key,
    required this.isDark,
  });

  @override
  ConsumerState<_StatusListView> createState() => _StatusListViewState();
}

class _StatusListViewState extends ConsumerState<_StatusListView> {
  @override
  Widget build(BuildContext context) {
    final storiesAsync = ref.watch(allStoriesGroupedProvider);
    final currentUserId = ref.watch(currentUserIdProvider);
    final followingAsync = ref.watch(followingProvider(currentUserId ?? ''));

    return storiesAsync.when(
      data: (storiesGrouped) {
        return followingAsync.when(
          data: (followingUsers) {
            final followingIds = followingUsers.map((u) => u.uid).toSet();
            final allStoryUserIds = storiesGrouped.keys.toList();

            // Following Stories: From users you follow
            final followingStoriesIds = allStoryUserIds
                .where((id) => followingIds.contains(id))
                .toList();

            // Discover Stories: From users you don't follow and not yourself
            final discoverStoriesIds = allStoryUserIds
                .where(
                  (id) => !followingIds.contains(id) && id != currentUserId,
                )
                .toList();

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Friends / My Stories Horizontal Section
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: Text(
                          'Friends',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 115,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: followingStoriesIds.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              final myStories = currentUserId != null
                                  ? storiesGrouped[currentUserId] ?? []
                                  : [];
                              final hasStories = myStories.isNotEmpty;
                              final firstStoryImageUrl =
                                  hasStories ? myStories.first.content : null;
                              
                              return _MyStoryItem(
                                isDark: widget.isDark,
                                hasStories: hasStories,
                                firstStoryImageUrl: firstStoryImageUrl,
                                currentUserId: currentUserId,
                              );
                            }
                            final userId = followingStoriesIds[index - 1];
                            final userStories = storiesGrouped[userId] ?? [];
                            if (userStories.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            final user = userStories.first;

                            return Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: Column(
                                children: [
                                  UserAvatar(
                                    userId: userId,
                                    avatarUrl: user.userAvatar,
                                    radius: 35,
                                    showStoryRing: true,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => StoryViewerScreen(
                                            storiesGrouped: storiesGrouped,
                                            initialUserId: userId,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: 75,
                                    child: Text(
                                      user.userName,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: widget.isDark
                                            ? Colors.grey[300]
                                            : Colors.grey[900],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Following Section (Horizontal Cards)
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Following',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: widget.isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 220,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: (followingStoriesIds.length > 5
                              ? 5
                              : followingStoriesIds.length),
                          itemBuilder: (context, index) {
                            final userId = followingStoriesIds[index];
                            final userStories = storiesGrouped[userId] ?? [];
                            final user = userStories.first;

                            return _StatusCard(
                              name: user.userName,
                              avatarUrl: user.userAvatar,
                              contentUrl: user.content,
                              isDark: widget.isDark,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => StoryViewerScreen(
                                      storiesGrouped: storiesGrouped,
                                      initialUserId: userId,
                                    ),
                                  ),
                                );
                              },
                              width: 140,
                              gradient: index % 2 == 0
                                  ? [
                                      const Color(0xFF66BB6A).withOpacity(0.9),
                                      const Color(0xFF81C784),
                                    ]
                                  : [
                                      const Color(0xFFC0CA33).withOpacity(0.9),
                                      const Color(0xFFDCE775),
                                    ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Discover Section (Grid)
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Discover',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final userId = discoverStoriesIds[index];
                      final userStories = storiesGrouped[userId] ?? [];
                      if (userStories.isEmpty) return const SizedBox.shrink();

                      final user = userStories.first;

                      return _StatusCard(
                        name: user.userName,
                        avatarUrl: user.userAvatar,
                        contentUrl: user.content,
                        storyCount: userStories.length,
                        isDark: widget.isDark,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StoryViewerScreen(
                                storiesGrouped: storiesGrouped,
                                initialUserId: userId,
                              ),
                            ),
                          );
                        },
                        gradient: index % 3 == 0
                            ? [
                                const Color(0xFF2E7D32),
                                const Color(0xFF4CAF50).withOpacity(0.7),
                              ]
                            : index % 3 == 1
                            ? [
                                const Color(0xFF9E9D24),
                                const Color(0xFFCDDC39).withOpacity(0.7),
                              ]
                            : [
                                const Color(0xFFF9A825),
                                const Color(0xFFFBC02D).withOpacity(0.7),
                              ],
                      );
                    }, childCount: discoverStoriesIds.length),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }
}

// My Story Item Widget
class _MyStoryItem extends StatelessWidget {
  final bool isDark;
  final bool hasStories;
  final String? firstStoryImageUrl;
  final String? currentUserId;

  const _MyStoryItem({
    required this.isDark,
    this.hasStories = false,
    this.firstStoryImageUrl,
    this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (hasStories) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyStoryScreen()),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateStoryScreen()),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                UserAvatar(
                  userId: currentUserId ?? 'my_story', // Dummy ID for My Story fallback if missing
                  avatarUrl: firstStoryImageUrl, // Current user image or story
                  radius: 35,
                  showStoryRing: hasStories,
                  enableDefaultTap: false,
                ),
                if (!hasStories)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? Colors.black : Colors.white,
                        width: 2,
                      ),
                    ),
                    child: const Icon(Icons.add, size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'My Story',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[400] : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Status Card Widget (Following/Discover)
class _StatusCard extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final String? contentUrl;
  final bool isDark;
  final VoidCallback onTap;
  final List<Color> gradient;
  final double? width;
  final int? storyCount;

  const _StatusCard({
    required this.name,
    this.avatarUrl,
    this.contentUrl,
    required this.isDark,
    required this.onTap,
    required this.gradient,
    this.width,
    this.storyCount,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: 12),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Story Content Image
            if (contentUrl != null &&
                contentUrl!.isNotEmpty &&
                UrlValidator.isValidUrl(contentUrl))
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: contentUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: Colors.black12),
                  errorWidget: (context, url, error) => const SizedBox.shrink(),
                ),
              ),

            // Darker overlay
            if (contentUrl != null && contentUrl!.isNotEmpty)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.2),
                        Colors.transparent,
                        Colors.black.withOpacity(0.6),
                      ],
                    ),
                  ),
                ),
              ),

            // Story Count in Center
            if (storyCount != null && storyCount! > 0)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: Text(
                    '$storyCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // User Info (Bottom)
            Positioned(
              left: 12,
              bottom: 12,
              right: 12,
              child: Row(
                children: [
                  UserAvatar(
                    userId: '', // ID not essential here as it's a fixed card
                    avatarUrl: avatarUrl,
                    radius: 16,
                    showStoryRing: false,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black45,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Filter Chip Widget
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1B4D3E) : const Color(0xFFE6F4EF))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (isDark ? const Color(0xFF2E7D32) : const Color(0xFF2E7D32))
                : (isDark ? Colors.white24 : Colors.grey[300]!),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? (isDark ? const Color(0xFFA5D6A7) : const Color(0xFF2E7D32))
                : (isDark ? Colors.grey[400] : Colors.grey[600]),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// Chat List Item
class _SnapchatListItem extends ConsumerWidget {
  final ChatChannel channel;
  final String? currentUserId;
  final bool isDark;

  const _SnapchatListItem({
    required this.channel,
    required this.currentUserId,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGroup = channel.type == 'group';

    final otherUserId = isGroup
        ? null
        : channel.memberIds.firstWhere(
            (id) => id != currentUserId,
            orElse: () => 'Unknown',
          );

    final displayName = isGroup
        ? (channel.displayName ?? 'Untitled Group')
        : (channel.memberNames[otherUserId] ?? 'Student');

    final displayAvatar = isGroup
        ? channel.displayAvatarUrl
        : channel.memberAvatars[otherUserId];

    final isTyping = !isGroup && otherUserId != null
        ? (channel.typingUsers[otherUserId] ?? false)
        : false;

    // Watch other user for real online status
    final otherUserAsync = !isGroup && otherUserId != null
        ? ref.watch(userProvider(otherUserId))
        : null;
    final isOnline = otherUserAsync?.value?.status == 'online';

    final unreadCount = channel.unreadCounts[currentUserId] ?? 0;
    final isUnread = unreadCount > 0;
    final lastMsgTime = channel.lastMessageTime;
    final isPinned = channel.pinnedBy.contains(currentUserId);

    // Get a nice preview text
    String getMessagePreview() {
      if (isTyping) return 'typing...';

      final msg = channel.lastMessage;
      if (msg.isEmpty) return 'Tap to chat';

      final type = msg['type'] ?? 'text';
      final content = msg['content'] ?? '';

      switch (type) {
        case 'image':
          return msg['is_snap'] == true ? '📸 Sent a snap' : '📷 Sent a photo';
        case 'voice':
          return '🎤 Voice message';
        case 'location':
          return '📍 Shared location';
        case 'giphy':
          return '💫 Sent a GIF';
        default:
          return content.isNotEmpty ? content : 'Tap to chat';
      }
    }

    return Slidable(
      key: ValueKey(channel.id),
      startActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) {
              ref
                  .read(chatRepositoryProvider)
                  .togglePinChannel(channel.id, !isPinned);
            },
            backgroundColor: AppColors.accentAmber,
            foregroundColor: AppColors.primaryInk,
            icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
            label: isPinned ? 'Unpin' : 'Pin',
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) {
              ref
                  .read(chatRepositoryProvider)
                  .toggleArchiveChannel(channel.id, true);
            },
            backgroundColor: const Color(0xFF7E57C2),
            foregroundColor: Colors.white,
            icon: Icons.archive_outlined,
            label: 'Archive',
          ),
          SlidableAction(
            onPressed: (context) async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Chat'),
                  content: const Text(
                    'Are you sure you want to delete this conversation? This cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                // If it's a group, maybe 'Leave'? If direct, just 'Archive' or 'Delete' local ref?
                // For now, use existing leaveGroup if it fits, or just archive.
                ref
                    .read(chatRepositoryProvider)
                    .toggleArchiveChannel(channel.id, true);
              }
            },
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: 'Delete',
          ),
        ],
      ),
      child: InkWell(
        onTap: () => context.push('/chat/${channel.id}'),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surfaceDarkElevated
                : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isUnread
                  ? AppColors.secondaryTeal.withOpacity(0.5)
                  : (isDark ? Colors.white12 : const Color(0xFFE8E1D7)),
              width: isUnread ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  UserAvatar(
                    userId: otherUserId ?? '',
                    avatarUrl: displayAvatar,
                    displayName: displayName,
                    radius: 28,
                    showStoryRing: true,
                    highlightColor: isUnread ? AppColors.secondaryTeal : null,
                  ),
                  if (isOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D664),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF1E1E1E)
                                : Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.primaryInk,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        if (!isGroup && otherUserId != null)
                          VerificationBadge(
                            type:
                                channel.verificationTypes[otherUserId] ??
                                'none',
                            size: 14,
                          ),
                        // Streak Display
                        if (channel.streakCount > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            '🔥 ${channel.streakCount}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (channel.streakExpiry != null &&
                              channel.streakExpiry!
                                      .difference(DateTime.now())
                                      .inHours <
                                  2) ...[
                            const SizedBox(width: 2),
                            const Text(
                              '⏳',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ],
                        if (isPinned)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.push_pin,
                              size: 14,
                              color: AppColors.secondaryTeal.withOpacity(0.7),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (isTyping) ...[
                          Text(
                            'typing...',
                            style: TextStyle(
                              color: AppColors.secondaryTeal,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ] else ...[
                          if (isUnread)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.secondaryTeal.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'NEW',
                                style: TextStyle(
                                  color: AppColors.secondaryTeal,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            )
                          else
                            Icon(
                              Icons.done_all,
                              size: 16,
                              color: isUnread
                                  ? AppColors.secondaryTeal
                                  : Colors.grey[400],
                            ),

                          const SizedBox(width: 6),

                          Flexible(
                            child: Text(
                              getMessagePreview(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isUnread
                                    ? (isDark
                                          ? Colors.white
                                          : AppColors.primaryInk)
                                    : (isDark
                                          ? Colors.grey[500]
                                          : Colors.grey[600]),
                                fontWeight: isUnread
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Far Right: Unread Badge & Time
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeago.format(lastMsgTime, locale: 'en_short'),
                    style: TextStyle(
                      color: isUnread
                          ? AppColors.secondaryTeal
                          : (isDark ? Colors.grey[600] : Colors.grey[500]),
                      fontSize: 12,
                      fontWeight: isUnread
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (unreadCount > 0)
                    Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: AppColors.secondaryTeal,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(
                          begin: const Offset(1, 1),
                          end: const Offset(1.1, 1.1),
                          duration: 1.seconds,
                        )
                  else
                    const SizedBox(height: 22),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.05, curve: Curves.easeOut);
  }
}

// Empty State
class _EmptyState extends StatelessWidget {
  final VoidCallback onStartConversation;
  final bool isDark;

  const _EmptyState({required this.onStartConversation, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: isDark ? Colors.grey[700] : Colors.grey[300],
          ),
          const SizedBox(height: 20),
          Text(
            "No chats yet",
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: onStartConversation,
            icon: const Icon(Icons.person_add),
            label: const Text("Start a Chat"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentAmber,
              foregroundColor: AppColors.primaryInk,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
