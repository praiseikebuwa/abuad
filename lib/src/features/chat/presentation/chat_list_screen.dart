import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../core/theme/app_colors.dart';
import '../data/chat_repository.dart';
import '../domain/chat_channel.dart';
import '../../user/data/user_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../stories/data/story_repository.dart';
import '../../stories/domain/story.dart';
import '../../stories/presentation/create_story_screen.dart';
import '../../stories/presentation/my_story_screen.dart';
import '../../stories/presentation/story_viewer_screen.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../../core/utils/url_validator.dart';
import '../../camera/presentation/camera_screen.dart';


class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';
  int _currentIndex = 0; // 0: Messages, 1: Stories/Discover

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  PopupMenuItem<String> _buildPopupMenuItem({
    required String value,
    required IconData icon,
    required String title,
    required bool isDark,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 42,
      child: Row(
        children: [
          Icon(
            icon,
            size: 19,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(chatRepositoryProvider);
    final channelsStream = repo.watchChannels();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1D) : Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF0A0F1D) : Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleSpacing: 18,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _currentIndex == 0 ? 'Messages' : 'Stories',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 28,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.8,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CapsuleSwitcher(
                  currentIndex: _currentIndex,
                  onChanged: (index) => setState(() => _currentIndex = index),
                  isDark: isDark,
                  isCompact: true,
                ),
                Theme(
                  data: Theme.of(context).copyWith(
                    popupMenuTheme: PopupMenuThemeData(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      surfaceTintColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                        ),
                      ),
                      elevation: 10,
                      shadowColor: Colors.black.withValues(alpha: 0.25),
                    ),
                  ),
                  child: PopupMenuButton<String>(
                    tooltip: 'More options',
                    padding: EdgeInsets.zero,
                    offset: const Offset(0, 48),
                    icon: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.04),
                        ),
                      ),
                      child: Icon(
                        Icons.more_vert_rounded,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        size: 20,
                      ),
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'new_chat':
                          context.push('/chat/user-search');
                          break;
                        case 'new_group':
                          context.push('/chat/create-group');
                          break;
                        case 'new_broadcast':
                          context.push('/chat/broadcast');
                          break;
                        case 'scanner':
                          context.push('/chat/scanner');
                          break;
                        case 'settings':
                          context.push('/chat/settings');
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      _buildPopupMenuItem(
                        value: 'new_chat',
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'New Chat',
                        isDark: isDark,
                      ),
                      _buildPopupMenuItem(
                        value: 'new_group',
                        icon: Icons.group_add_outlined,
                        title: 'New Group',
                        isDark: isDark,
                      ),
                      _buildPopupMenuItem(
                        value: 'new_broadcast',
                        icon: Icons.campaign_outlined,
                        title: 'New Broadcast',
                        isDark: isDark,
                      ),
                      _buildPopupMenuItem(
                        value: 'scanner',
                        icon: Icons.qr_code_scanner_rounded,
                        title: 'Scan QR Code',
                        isDark: isDark,
                      ),
                      const PopupMenuDivider(),
                      _buildPopupMenuItem(
                        value: 'settings',
                        icon: Icons.settings_outlined,
                        title: 'Chat Settings',
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Persistent Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(22),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: _currentIndex == 0
                      ? 'Search chats, groups, people...'
                      : 'Search stories, friends, shows...',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white38 : Colors.grey[400],
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: isDark ? Colors.white54 : Colors.grey[500],
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          child: Icon(
                            Icons.cancel_rounded,
                            size: 18,
                            color: isDark ? Colors.white54 : Colors.grey[400],
                          ),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          // Main View Content
          Expanded(
            child: _currentIndex == 1
                ? _StatusListView(isDark: isDark, searchQuery: _searchQuery)
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

                      return _buildChatView(allChannels, currentUserId, isDark);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'chat_list_snap_camera_btn',
        onPressed: () {
          HapticFeedback.mediumImpact();
          context.push(
            '/camera',
            extra: {
              'isForStory': false,
              'cameraContext': CameraContext.snap,
            },
          );
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        highlightElevation: 0,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.45),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
          ),
          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
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
      } else if (_selectedFilter == 'Chats') {
        if (c.type == 'group') return false;
      }

      // Hide empty 0-message direct channels when not searching
      final isGroup = c.type == 'group';
      final hasMessage = c.lastMessage.isNotEmpty &&
          (c.lastMessage['content']?.toString().trim().isNotEmpty ?? false);
      if (_searchQuery.isEmpty && !isGroup && !hasMessage) {
        return false;
      }

      if (_searchQuery.isEmpty) return true;

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

      // Channels with real messages come before empty ones
      final aHasMsg = a.lastMessage.isNotEmpty && (a.lastMessage['content']?.toString().trim().isNotEmpty ?? false);
      final bHasMsg = b.lastMessage.isNotEmpty && (b.lastMessage['content']?.toString().trim().isNotEmpty ?? false);
      if (aHasMsg && !bHasMsg) return -1;
      if (!aHasMsg && bHasMsg) return 1;

      return b.lastMessageTime.compareTo(a.lastMessageTime);
    });

    return Column(
      key: const ValueKey('chat_view'),
      children: [
        // Filter Pills Bar
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              _ModernFilterPill(
                label: 'All',
                isSelected: _selectedFilter == 'All',
                onTap: () => setState(() => _selectedFilter = 'All'),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _ModernFilterPill(
                label: 'Chats',
                isSelected: _selectedFilter == 'Chats',
                onTap: () => setState(() => _selectedFilter = 'Chats'),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _ModernFilterPill(
                label: 'Groups',
                isSelected: _selectedFilter == 'Groups',
                onTap: () => setState(() => _selectedFilter = 'Groups'),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _ModernFilterPill(
                label: 'Unread',
                hasNotificationDot: true,
                isSelected: _selectedFilter == 'Unread',
                onTap: () => setState(() => _selectedFilter = 'Unread'),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _ModernFilterPill(
                label: 'Mentions',
                isSelected: _selectedFilter == 'Mentions',
                onTap: () => setState(() => _selectedFilter = 'Mentions'),
                isDark: isDark,
              ),
            ],
          ),
        ),

        const SizedBox(height: 4),

        // Chat List
        Expanded(
          child: filteredChannels.isEmpty
              ? _EmptyState(
                  onStartConversation: () => context.push('/chat/user-search'),
                  isDark: isDark,
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: filteredChannels.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 82,
                    endIndent: 16,
                    color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                  ),
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


class _EmptyState extends StatelessWidget {
  final VoidCallback onStartConversation;
  final bool isDark;

  const _EmptyState({
    required this.onStartConversation,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 64,
            color: isDark ? Colors.white24 : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a new conversation with friends or groups',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white38 : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onStartConversation,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('New Message', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B49DF),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
        ],
      ),
    );
  }
}


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
            orElse: () => '',
          );

    final otherUserAsync = !isGroup && otherUserId != null && otherUserId.isNotEmpty
        ? ref.watch(userProvider(otherUserId))
        : null;

    final resolvedName = otherUserAsync?.value?.displayName.trim();
    final userHandle = otherUserAsync?.value?.handle.trim();
    final memberName = channel.memberNames[otherUserId]?.trim();
    final fallbackName = (channel.displayName != null && channel.displayName != 'Direct Message' && channel.displayName!.trim().isNotEmpty)
        ? channel.displayName!.trim()
        : null;

    final displayName = isGroup
        ? (channel.displayName ?? 'Untitled Group')
        : ((resolvedName != null && resolvedName.isNotEmpty)
            ? resolvedName
            : ((memberName != null && memberName.isNotEmpty)
                ? memberName
                : ((userHandle != null && userHandle.isNotEmpty)
                    ? '@$userHandle'
                    : (fallbackName ?? 'Student'))));

    final displayAvatar = isGroup
        ? channel.displayAvatarUrl
        : (otherUserAsync?.value?.avatarUrl ??
            channel.memberAvatars[otherUserId] ??
            channel.displayAvatarUrl);

    final isTyping = isGroup
        ? channel.typingUsers.values.any((v) => v == true)
        : (otherUserId != null ? (channel.typingUsers[otherUserId] ?? false) : false);

    final isOnline = otherUserAsync?.value?.status == 'online';
    final unreadCount = channel.unreadCounts[currentUserId] ?? 0;
    final isUnread = unreadCount > 0;
    final isPinned = channel.pinnedBy.contains(currentUserId);
    final isMuted = channel.id.contains('developer') || channel.displayName?.toLowerCase().contains('developer') == true;

    // Format Timestamp like "9:42 AM", "Yesterday", "Monday", "Just now"
    String formatTime(DateTime time) {
      final now = DateTime.now();
      final diff = now.difference(time);
      if (diff.inMinutes < 2) return 'Just now';
      if (now.day == time.day && now.month == time.month && now.year == time.year) {
        return DateFormat('h:mm a').format(time);
      }
      final yesterday = now.subtract(const Duration(days: 1));
      if (yesterday.day == time.day && yesterday.month == time.month && yesterday.year == time.year) {
        return 'Yesterday';
      }
      if (diff.inDays < 7) {
        return DateFormat('EEEE').format(time);
      }
      return DateFormat('MMM d').format(time);
    }

    // Get Message Preview line
    Widget buildMessagePreview() {
      if (isTyping) {
        return Text(
          isGroup ? '3 people are typing...' : 'typing...',
          style: const TextStyle(
            color: Color(0xFF6366F1),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        );
      }

      final msg = channel.lastMessage;
      if (msg.isEmpty) {
        return Text(
          'Tap to chat',
          style: TextStyle(
            color: isDark ? Colors.white38 : Colors.grey[400],
            fontSize: 14,
          ),
        );
      }

      final type = msg['type'] ?? 'text';
      final content = msg['content'] ?? '';
      final senderName = msg['sender_name'] ?? (isGroup ? 'Member' : '');

      String text = content;
      if (type == 'voice') {
        text = '🎙️ Voice message (0:14)';
      } else if (type == 'document' || content.contains('Document:')) {
        text = '📄 ${content.replaceFirst("📄 Document:", "").trim()}';
      } else if (type == 'image') {
        text = isGroup ? '$senderName: Check out the new UI [Image] 📸' : '📸 Photo';
      } else if (isGroup && senderName.isNotEmpty && !content.startsWith(senderName)) {
        text = '$senderName: $content';
      }

      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          color: isUnread
              ? (isDark ? Colors.white : const Color(0xFF0F172A))
              : (isDark ? Colors.white60 : const Color(0xFF475569)),
          fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
        ),
      );
    }

    final isArchived = channel.archivedBy.contains(currentUserId);

    return Slidable(
      key: ValueKey('slidable_${channel.id}'),
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.50,
        children: [
          SlidableAction(
            onPressed: (context) async {
              HapticFeedback.mediumImpact();
              await ref.read(chatRepositoryProvider).togglePinChannel(channel.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isPinned ? 'Chat unpinned' : 'Chat pinned to top 📌'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            backgroundColor: isPinned ? const Color(0xFF64748B) : const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            icon: isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
            label: isPinned ? 'Unpin' : 'Pin',
          ),
          SlidableAction(
            onPressed: (context) async {
              HapticFeedback.lightImpact();
              await ref.read(chatRepositoryProvider).markChannelAsRead(channel.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isUnread ? 'Marked as read' : 'Marked as unread'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            backgroundColor: isUnread ? const Color(0xFF10B981) : const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            icon: isUnread ? Icons.mark_chat_read_rounded : Icons.mark_chat_unread_rounded,
            label: isUnread ? 'Read' : 'Unread',
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.50,
        children: [
          SlidableAction(
            onPressed: (context) async {
              HapticFeedback.lightImpact();
              await ref.read(chatRepositoryProvider).toggleArchiveChannel(channel.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isArchived ? 'Chat unarchived' : 'Chat archived 📁'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            backgroundColor: const Color(0xFF8B5CF6),
            foregroundColor: Colors.white,
            icon: isArchived ? Icons.unarchive_rounded : Icons.archive_rounded,
            label: isArchived ? 'Unarchive' : 'Archive',
          ),
          SlidableAction(
            onPressed: (context) {
              _showDeleteConfirmation(context, ref, displayName);
            },
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
          ),
        ],
      ),
      child: InkWell(
        onTap: () => context.push('/chat/${channel.id}'),
        onLongPress: () => _showQuickActionsBottomSheet(context, ref, displayName, isPinned, isArchived, isUnread),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar Column
              _buildListAvatar(displayAvatar, displayName, isOnline, isGroup),
              const SizedBox(width: 14),

              // Content Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Row 1: Title & Pin/Mute
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        if (isOnline && !isGroup) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF22C55E),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                        if (isPinned) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.push_pin_rounded,
                            size: 14,
                            color: isDark ? Colors.white54 : Colors.grey[500],
                          ),
                        ],
                        if (isMuted) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.volume_off_rounded,
                            size: 14,
                            color: isDark ? Colors.white38 : Colors.grey[400],
                          ),
                        ],
                      ],
                    ),

                    // Row 2: Member count (if group)
                    if (isGroup) ...[
                      const SizedBox(height: 1.5),
                      Text(
                        '${channel.memberIds.isNotEmpty ? channel.memberIds.length : 128} members',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white38 : Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],

                    const SizedBox(height: 2.5),

                    // Row 3: Message preview
                    buildMessagePreview(),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Trailing Column: Timestamp & Badge / Checkmark
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatTime(channel.lastMessageTime),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                      color: isUnread
                          ? const Color(0xFF3B49DF)
                          : (isDark ? Colors.white38 : Colors.grey[400]),
                    ),
                  ),
                  const SizedBox(height: 5),
                  if (isUnread)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      constraints: const BoxConstraints(minWidth: 20),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    Icon(
                      Icons.done_all_rounded,
                      size: 16,
                      color: isDark ? Colors.white38 : Colors.grey[400],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, String displayName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Conversation',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        content: Text(
          'Are you sure you want to delete this chat with "$displayName"? All messages will be permanently removed.',
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xFF475569),
            fontSize: 14,
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(chatRepositoryProvider).deleteChannel(channel.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Chat with $displayName deleted'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showQuickActionsBottomSheet(
    BuildContext context,
    WidgetRef ref,
    String displayName,
    bool isPinned,
    bool isArchived,
    bool isUnread,
  ) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 16),
              ListTile(
                leading: Icon(
                  isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                ),
                title: Text(
                  isPinned ? 'Unpin Chat' : 'Pin to Top',
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(chatRepositoryProvider).togglePinChannel(channel.id);
                },
              ),
              ListTile(
                leading: Icon(
                  isUnread ? Icons.mark_chat_read_rounded : Icons.mark_chat_unread_rounded,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                ),
                title: Text(
                  isUnread ? 'Mark as Read' : 'Mark as Unread',
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(chatRepositoryProvider).markChannelAsRead(channel.id);
                },
              ),
              ListTile(
                leading: Icon(
                  isArchived ? Icons.unarchive_rounded : Icons.archive_rounded,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                ),
                title: Text(
                  isArchived ? 'Unarchive Chat' : 'Archive Chat',
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(chatRepositoryProvider).toggleArchiveChannel(channel.id);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                title: const Text('Delete Chat', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteConfirmation(context, ref, displayName);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListAvatar(String? displayAvatar, String displayName, bool isOnline, bool isGroup) {
    if (isGroup) {
      final avatars = (channel.memberAvatars.values.where((a) => a != null && a.isNotEmpty).cast<String>().toList());
      if (avatars.length >= 3) {
        return SizedBox(
          width: 50,
          height: 50,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                child: CircleAvatar(
                  radius: 14,
                  backgroundImage: NetworkImage(avatars[0]),
                  backgroundColor: const Color(0xFF6366F1),
                ),
              ),
              Positioned(
                right: 0,
                top: 2,
                child: CircleAvatar(
                  radius: 13,
                  backgroundImage: NetworkImage(avatars[1]),
                  backgroundColor: const Color(0xFF10B981),
                ),
              ),
              Positioned(
                left: 10,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: CircleAvatar(
                    radius: 13,
                    backgroundImage: NetworkImage(avatars[2]),
                    backgroundColor: const Color(0xFFF59E0B),
                  ),
                ),
              ),
            ],
          ),
        );
      } else if (displayAvatar != null && displayAvatar.isNotEmpty) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 25,
              backgroundImage: NetworkImage(displayAvatar),
              backgroundColor: const Color(0xFF1E293B),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const CircleAvatar(
                  radius: 10,
                  backgroundColor: Color(0xFF6366F1),
                  child: Icon(Icons.person, size: 12, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      }

      return Container(
        width: 50,
        height: 50,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            displayName.isNotEmpty ? displayName[0].toUpperCase() : 'G',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        UserAvatar(
          userId: '',
          avatarUrl: displayAvatar,
          displayName: displayName,
          radius: 25,
        ),
        if (isOnline)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0xFF0A0F1D) : Colors.white,
                  width: 2.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ModernFilterPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool hasNotificationDot;
  final VoidCallback onTap;
  final bool isDark;

  const _ModernFilterPill({
    required this.label,
    required this.isSelected,
    this.hasNotificationDot = false,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF3B49DF)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : const Color(0xFF475569)),
              ),
            ),
            if (hasNotificationDot) ...[
              const SizedBox(width: 4),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CapsuleSwitcher extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onChanged;
  final bool isDark;
  final bool isCompact;

  const _CapsuleSwitcher({
    required this.currentIndex,
    required this.onChanged,
    required this.isDark,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final width = isCompact ? 168.0 : 320.0;
    final height = isCompact ? 34.0 : 52.0;
    final padding = isCompact ? 3.0 : 4.0;
    final indicatorWidth = (width - (padding * 2)) / 2;
    final borderRadius = height / 2;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isCompact
            ? Colors.white.withValues(alpha: 0.15)
            : (isDark ? const Color(0xFF1A1A1A) : Colors.grey[200]),
        borderRadius: BorderRadius.circular(borderRadius),
        border: isCompact
            ? Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1)
            : null,
        boxShadow: isCompact
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Stack(
        children: [
          // Indicator
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            left: currentIndex == 0 ? padding : padding + indicatorWidth,
            top: padding,
            bottom: padding,
            child: Container(
              width: indicatorWidth,
              decoration: BoxDecoration(
                color: isCompact
                    ? AppColors.secondaryTeal
                    : const Color(0xFF2E7D32),
                borderRadius: BorderRadius.circular(borderRadius - padding),
                boxShadow: isCompact
                    ? [
                        BoxShadow(
                          color: AppColors.secondaryTeal.withValues(alpha: 0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
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
                          Icons.chat_bubble_outline_rounded,
                          color: currentIndex == 0
                              ? Colors.white
                              : (isCompact ? Colors.white70 : Colors.grey),
                          size: isCompact ? 14 : 18,
                        ),
                        SizedBox(width: isCompact ? 4 : 8),
                        Text(
                          'Chat',
                          style: TextStyle(
                            fontSize: isCompact ? 12 : 13,
                            fontWeight: FontWeight.bold,
                            color: currentIndex == 0
                                ? Colors.white
                                : (isCompact ? Colors.white70 : Colors.grey),
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
                          Icons.camera_outlined,
                          color: currentIndex == 1
                              ? Colors.white
                              : (isCompact ? Colors.white70 : Colors.grey),
                          size: isCompact ? 14 : 18,
                        ),
                        SizedBox(width: isCompact ? 4 : 8),
                        Text(
                          'Status',
                          style: TextStyle(
                            fontSize: isCompact ? 12 : 13,
                            fontWeight: FontWeight.bold,
                            color: currentIndex == 1
                                ? Colors.white
                                : (isCompact ? Colors.white70 : Colors.grey),
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
  final String? searchQuery;

  const _StatusListView({
    required this.isDark,
    this.searchQuery,
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
                                      const Color(0xFF66BB6A).withValues(alpha: 0.9),
                                      const Color(0xFF81C784),
                                    ]
                                  : [
                                      const Color(0xFFC0CA33).withValues(alpha: 0.9),
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
                                const Color(0xFF4CAF50).withValues(alpha: 0.7),
                              ]
                            : index % 3 == 1
                            ? [
                                const Color(0xFF9E9D24),
                                const Color(0xFFCDDC39).withValues(alpha: 0.7),
                              ]
                            : [
                                const Color(0xFFF9A825),
                                const Color(0xFFFBC02D).withValues(alpha: 0.7),
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
class _MyStoryItem extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = currentUserId != null ? ref.watch(userProvider(currentUserId!)) : null;
    final user = userAsync?.value ?? ref.watch(authRepositoryProvider).currentUser;

    return GestureDetector(
      onTap: () {
        if (hasStories && currentUserId != null) {
          final storiesGroupedAsync = ref.read(allStoriesGroupedProvider);
          final storiesGrouped = storiesGroupedAsync.value ?? {};
          _showMyStatusModal(context, storiesGrouped, currentUserId!);
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
                  userId: currentUserId ?? 'my_story',
                  avatarUrl: user?.avatarUrl,
                  displayName: user?.displayName,
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

  void _showMyStatusModal(
    BuildContext context,
    Map<String, List<Story>> storiesGrouped,
    String currentUserId,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_circle_fill, color: Color(0xFF00E5FF)),
                  ),
                  title: const Text('View My Status', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Watch your active status update'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StoryViewerScreen(
                          storiesGrouped: storiesGrouped,
                          initialUserId: currentUserId,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.insights_rounded, color: Color(0xFF8B5CF6)),
                  ),
                  title: const Text('My Status & Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('See viewers, likes & delete status'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MyStoryScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_circle_outline_rounded, color: Colors.green),
                  ),
                  title: const Text('Add New Status', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Share another photo or text update'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CreateStoryScreen()),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
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
              color: Colors.black.withValues(alpha: 0.12),
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
                        Colors.black.withValues(alpha: 0.2),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.6),
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
