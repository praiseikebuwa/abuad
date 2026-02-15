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
// import '../../stories/presentation/widgets/story_widgets.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(chatRepositoryProvider);
    final channelsStream = repo.watchChannels();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Chat',
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
        leading: IconButton(
          icon: const Icon(
            Icons.settings_outlined,
            color: Colors.white,
            size: 26,
          ),
          onPressed: () => context.push('/settings'),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.add_circle_outline,
              color: Colors.white,
              size: 26,
            ),
            onSelected: (value) {
              if (value == 'new_chat') context.push('/chat/user-search');
              if (value == 'new_group') context.push('/chat/create-group');
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'new_chat',
                child: ListTile(
                  leading: Icon(Icons.person_add_outlined),
                  title: Text('New Chat'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'new_group',
                child: ListTile(
                  leading: Icon(Icons.group_add_outlined),
                  title: Text('New Group'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<List<ChatChannel>>(
        stream: channelsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            );
          }

          final channels = snapshot.data ?? [];

          if (channels.isEmpty) {
            return _EmptyState(
              onStartConversation: () => context.push('/chat/user-search'),
              isDark: isDark,
            );
          }

          return Column(
            children: [
              // Status Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  'Status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ),
              // Stories Row
              Consumer(
                builder: (context, ref, child) {
                  final storiesAsync = ref.watch(allStoriesGroupedProvider);
                  final currentUserId = ref.watch(currentUserIdProvider);

                  return storiesAsync.when(
                    data: (storiesGrouped) {
                      final storyUserIds = storiesGrouped.keys.toList();

                      return Container(
                        height: 108,
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.surfaceDarkElevated
                              : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? Colors.white12
                                : const Color(0xFFE8E1D7),
                          ),
                        ),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: storyUserIds.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return _CameraStoryItem(
                                isDark: isDark,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const CreateStoryScreen(),
                                    ),
                                  );
                                },
                              );
                            }

                            final userId = storyUserIds[index - 1];
                            final userStories = storiesGrouped[userId] ?? [];

                            final hasStory = userStories.isNotEmpty;
                            final userName = hasStory
                                ? userStories.first.userName
                                : 'Unknown';
                            final userAvatar = hasStory
                                ? userStories.first.userAvatar
                                : null;

                            final unviewedStory =
                                currentUserId != null &&
                                userStories.any(
                                  (s) => !s.hasViewed(currentUserId),
                                );

                            return _StoryItem(
                              name: userName,
                              avatarUrl: userAvatar,
                              hasStory: hasStory,
                              hasUnviewedStory: unviewedStory,
                              isDark: isDark,
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
                            );
                          },
                        ),
                      );
                    },
                    loading: () => Container(
                      height: 100,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(),
                    ),
                    error: (error, stackTrace) => const SizedBox(height: 100),
                  );
                },
              ),

              // Divider
              Divider(
                height: 1,
                thickness: 1,
                color: isDark ? Colors.white12 : Colors.grey[300],
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
                  itemCount: channels.length,
                  itemBuilder: (context, index) {
                    final channel = channels[index];
                    return _SnapchatListItem(
                      channel: channel,
                      currentUserId: repo.currentUserId,
                      isDark: isDark,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Camera Story Item
class _CameraStoryItem extends StatelessWidget {
  final bool isDark;
  final VoidCallback? onTap;
  const _CameraStoryItem({required this.isDark, this.onTap});

  Future<void> _openCamera(BuildContext context) async {
    if (onTap != null) {
      onTap!();
      return;
    }
    // ... default implementation ...
    final ImagePicker picker = ImagePicker();

    try {
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        // TODO: Upload as story
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Story camera feature coming soon')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openCamera(context),
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: AppColors.amberGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt,
                color: AppColors.primaryInk,
                size: 28,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'My Status',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey[400] : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Story Item
class _StoryItem extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final bool hasStory;
  final bool hasUnviewedStory;
  final bool isDark;
  final VoidCallback onTap;

  const _StoryItem({
    required this.name,
    this.avatarUrl,
    required this.hasStory,
    required this.hasUnviewedStory,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: hasStory
                    ? Border.all(
                        color: hasUnviewedStory
                            ? AppColors.accentAmber
                            : Colors.grey,
                        width: 2.5,
                      )
                    : null,
              ),
              child: Padding(
                padding: const EdgeInsets.all(2.0),
                child: CircleAvatar(
                  backgroundColor: Colors.grey[300],
                  backgroundImage: avatarUrl != null
                      ? CachedNetworkImageProvider(avatarUrl!)
                      : null,
                  child: avatarUrl == null
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 65,
              child: Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey[400] : Colors.black87,
                ),
              ),
            ),
          ],
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
        : false; // TODO: Implement group typing

    final isOnline = !isGroup; // Online status only for direct chats for now

    final unreadCount = channel.unreadCounts[currentUserId] ?? 0;
    final isUnread = unreadCount > 0;
    final lastMsgTime = channel.lastMessageTime;

    return InkWell(
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
                ? AppColors.accentAmber.withOpacity(0.3)
                : (isDark ? Colors.white12 : const Color(0xFFE8E1D7)),
            width: isUnread ? 1.5 : 1,
          ),
          boxShadow: isUnread && !isDark
              ? [
                  BoxShadow(
                    color: AppColors.accentAmber.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Avatar with online indicator and Streak badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: isUnread
                        ? Border.all(color: AppColors.accentAmber, width: 2.5)
                        : null,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isUnread ? 2.0 : 0),
                    child: displayAvatar != null && displayAvatar.isNotEmpty
                        ? CircleAvatar(
                            backgroundImage: CachedNetworkImageProvider(
                              displayAvatar,
                            ),
                          )
                        : CircleAvatar(
                            backgroundColor: isGroup
                                ? AppColors.secondaryTeal.withOpacity(0.2)
                                : Colors.grey[300],
                            child: isGroup
                                ? const Icon(
                                    Icons.groups,
                                    color: AppColors.secondaryTeal,
                                  )
                                : Text(
                                    displayName.isNotEmpty
                                        ? displayName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                          ),
                  ),
                ),
                // Online indicator
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
                          color: isDark ? AppColors.surfaceDark : Colors.white,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                if (!isGroup && otherUserId != null)
                  Consumer(
                    builder: (context, ref, _) {
                      final otherUserAsync = ref.watch(
                        userProvider(otherUserId),
                      );
                      return otherUserAsync.when(
                        data: (user) {
                          if (user == null || user.streakCount == 0) {
                            return const SizedBox();
                          }
                          return Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.surfaceDark
                                      : Colors.white,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    "🔥",
                                    style: TextStyle(fontSize: 8),
                                  ),
                                  Text(
                                    "${user.streakCount}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        loading: () => const SizedBox(),
                        error: (error, stack) => const SizedBox(),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.primaryInk,
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (!isGroup && otherUserId != null)
                        VerificationBadge(
                          type:
                              channel.verificationTypes[otherUserId] ?? 'none',
                          size: 14,
                        ),
                      if (isUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentAmber,
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
                              color: AppColors.accentAmber.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'New',
                              style: TextStyle(
                                color: AppColors.accentAmber,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          )
                        else
                          Icon(
                            Icons.done_all,
                            size: 16,
                            color: Colors.grey[400],
                          ),

                        const SizedBox(width: 6),

                        Flexible(
                          child: Text(
                            isUnread ? 'New Message' : 'Tap to chat',
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
                        Text(
                          ' • ${timeago.format(lastMsgTime, locale: 'en_short')}',
                          style: TextStyle(
                            color: isDark ? Colors.grey[600] : Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.1, curve: Curves.easeOut);
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
