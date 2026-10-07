import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/presentation/widgets/custom_snackbar.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../data/notification_repository.dart';
import '../domain/notification.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;
  String _selectedFilter = 'all'; // 'all', 'unread', 'likes', 'comments', 'mentions'

  void _toggleSelection(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
        _isSelectionMode = true;
      }
    });
  }

  void _enterSelectionMode(String id) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isSelectionMode = true;
      _selectedIds.add(id);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _selectAll(List<AppNotification> notifications) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedIds.addAll(notifications.map((n) => n.id));
    });
  }

  void _inverseSelection(List<AppNotification> notifications) {
    HapticFeedback.selectionClick();
    setState(() {
      final allIds = notifications.map((n) => n.id).toSet();
      final newSelection = allIds.difference(_selectedIds);
      _selectedIds.clear();
      _selectedIds.addAll(newSelection);
      if (_selectedIds.isEmpty) _isSelectionMode = false;
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notifications'),
        content: Text(
          'Are you sure you want to delete ${_selectedIds.length} notification${_selectedIds.length == 1 ? '' : 's'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final idsToDelete = _selectedIds.toList();
        _exitSelectionMode();
        await ref
            .read(notificationRepositoryProvider)
            .deleteNotifications(idsToDelete);
        if (mounted) {
          CustomSnackbar.show(
            context,
            message: '${idsToDelete.length} notification${idsToDelete.length == 1 ? '' : 's'} deleted',
          );
        }
      } catch (e) {
        if (mounted) {
          CustomSnackbar.show(
            context,
            message: 'Error deleting notifications: $e',
            isError: true,
          );
        }
      }
    }
  }

  Future<void> _clearAllNotifications() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text(
          'Are you sure you want to permanently clear all notifications? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(notificationRepositoryProvider).clearAllNotifications();
        if (mounted) {
          CustomSnackbar.show(context, message: 'All notifications cleared');
        }
      } catch (e) {
        if (mounted) {
          CustomSnackbar.show(
            context,
            message: 'Error clearing notifications: $e',
            isError: true,
          );
        }
      }
    }
  }

  void _handleNotificationTap(AppNotification notification) {
    if (_isSelectionMode) {
      _toggleSelection(notification.id);
      return;
    }

    HapticFeedback.lightImpact();

    // Mark as read immediately
    if (!notification.isRead) {
      ref.read(notificationRepositoryProvider).markAsRead(notification.id);
    }

    final relatedId = notification.relatedId;
    final senderId = notification.senderId;

    switch (notification.type) {
      case NotificationType.like:
      case NotificationType.comment:
      case NotificationType.repost:
      case NotificationType.followingPost:
        if (relatedId != null && relatedId.isNotEmpty) {
          context.push('/post/$relatedId');
        } else if (senderId.isNotEmpty) {
          context.push('/user/$senderId');
        }
        break;

      case NotificationType.follow:
      case NotificationType.unfollow:
      case NotificationType.mention:
      case NotificationType.storyUpdate:
        final targetUserId = (relatedId != null && relatedId.isNotEmpty)
            ? relatedId
            : senderId;
        if (targetUserId.isNotEmpty) {
          context.push('/user/$targetUserId');
        }
        break;

      case NotificationType.chat:
        if (relatedId != null && relatedId.isNotEmpty) {
          context.push('/chat/$relatedId');
        } else {
          context.push('/chat');
        }
        break;

      case NotificationType.sos:
        context.push('/map');
        break;

      case NotificationType.streakExpiring:
      case NotificationType.streakMissed:
        context.push('/profile');
        break;

      case NotificationType.system:
        if (relatedId != null && relatedId.isNotEmpty) {
          if (relatedId.startsWith('post_') || relatedId.length > 20) {
            context.push('/post/$relatedId');
          } else {
            context.push('/user/$relatedId');
          }
        }
        break;
    }
  }

  Widget _buildTypeBadge(NotificationType type) {
    IconData iconData;
    Color badgeColor;

    switch (type) {
      case NotificationType.like:
        iconData = Icons.favorite_rounded;
        badgeColor = const Color(0xFFFF2D55);
        break;
      case NotificationType.comment:
        iconData = Icons.chat_bubble_rounded;
        badgeColor = const Color(0xFF0A84FF);
        break;
      case NotificationType.repost:
        iconData = Icons.repeat_rounded;
        badgeColor = const Color(0xFF30D158);
        break;
      case NotificationType.follow:
        iconData = Icons.person_add_rounded;
        badgeColor = const Color(0xFFBF5AF2);
        break;
      case NotificationType.unfollow:
        iconData = Icons.person_remove_rounded;
        badgeColor = Colors.grey;
        break;
      case NotificationType.mention:
        iconData = Icons.alternate_email_rounded;
        badgeColor = const Color(0xFFFF9F0A);
        break;
      case NotificationType.chat:
        iconData = Icons.mark_chat_unread_rounded;
        badgeColor = const Color(0xFF64D2FF);
        break;
      case NotificationType.sos:
        iconData = Icons.warning_amber_rounded;
        badgeColor = const Color(0xFFFF453A);
        break;
      case NotificationType.streakExpiring:
      case NotificationType.streakMissed:
        iconData = Icons.local_fire_department_rounded;
        badgeColor = const Color(0xFFFF9500);
        break;
      case NotificationType.storyUpdate:
        iconData = Icons.history_edu_rounded;
        badgeColor = const Color(0xFF5E5CE6);
        break;
      case NotificationType.followingPost:
        iconData = Icons.dynamic_feed_rounded;
        badgeColor = const Color(0xFF0A84FF);
        break;
      case NotificationType.system:
        iconData = Icons.notifications_active_rounded;
        badgeColor = const Color(0xFF0A84FF);
        break;
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: badgeColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withValues(alpha: 0.4),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Icon(
        iconData,
        size: 11,
        color: Colors.white,
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, yyyy h:mm a').format(timestamp);
    }
  }

  List<AppNotification> _filterNotifications(List<AppNotification> list) {
    switch (_selectedFilter) {
      case 'unread':
        return list.where((n) => !n.isRead).toList();
      case 'likes':
        return list.where((n) => n.type == NotificationType.like).toList();
      case 'comments':
        return list.where((n) => n.type == NotificationType.comment).toList();
      case 'mentions':
        return list.where((n) => n.type == NotificationType.mention).toList();
      default:
        return list;
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(userNotificationsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode
            ? Text(
                '${_selectedIds.length} Selected',
                style: const TextStyle(fontWeight: FontWeight.bold),
              )
            : const Text(
                'Notifications',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _exitSelectionMode,
              )
            : null,
        actions: notificationsAsync.when(
          data: (notifications) {
            if (_isSelectionMode) {
              return [
                IconButton(
                  icon: const Icon(Icons.select_all_rounded),
                  tooltip: 'Select All',
                  onPressed: () => _selectAll(notifications),
                ),
                IconButton(
                  icon: const Icon(Icons.flip_rounded),
                  tooltip: 'Inverse Selection',
                  onPressed: () => _inverseSelection(notifications),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  tooltip: 'Delete Selected',
                  onPressed: _deleteSelected,
                ),
              ];
            }

            final unreadCount = notifications.where((n) => !n.isRead).length;

            return [
              if (unreadCount > 0)
                IconButton(
                  icon: const Icon(Icons.done_all_rounded),
                  tooltip: 'Mark all as read',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ref.read(notificationRepositoryProvider).markAllAsRead();
                    CustomSnackbar.show(context, message: 'All marked as read');
                  },
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (value) {
                  switch (value) {
                    case 'mark_all_read':
                      ref.read(notificationRepositoryProvider).markAllAsRead();
                      CustomSnackbar.show(context, message: 'All marked as read');
                      break;
                    case 'select_mode':
                      if (notifications.isNotEmpty) {
                        _enterSelectionMode(notifications.first.id);
                      }
                      break;
                    case 'clear_all':
                      _clearAllNotifications();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'mark_all_read',
                    child: Row(
                      children: [
                        Icon(Icons.done_all_rounded, size: 20),
                        SizedBox(width: 12),
                        Text('Mark all as read'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'select_mode',
                    child: Row(
                      children: [
                        Icon(Icons.checklist_rounded, size: 20),
                        SizedBox(width: 12),
                        Text('Select items'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'clear_all',
                    child: Row(
                      children: [
                        Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 20),
                        SizedBox(width: 12),
                        Text('Clear all notifications', style: TextStyle(color: Colors.redAccent)),
                      ],
                    ),
                  ),
                ],
              ),
            ];
          },
          loading: () => [],
          error: (_, _) => [],
        ),
      ),
      body: notificationsAsync.when(
        data: (allNotifications) {
          if (allNotifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications_none_rounded,
                      size: 40,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "When you get likes, comments, or mentions,\nthey'll show up here.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          }

          final notifications = _filterNotifications(allNotifications);

          return Column(
            children: [
              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _buildFilterChip('All', 'all', allNotifications.length),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'Unread',
                      'unread',
                      allNotifications.where((n) => !n.isRead).length,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'Likes',
                      'likes',
                      allNotifications.where((n) => n.type == NotificationType.like).length,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'Comments',
                      'comments',
                      allNotifications.where((n) => n.type == NotificationType.comment).length,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'Mentions',
                      'mentions',
                      allNotifications.where((n) => n.type == NotificationType.mention).length,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 0.5),

              // Notification List
              Expanded(
                child: notifications.isEmpty
                    ? Center(
                        child: Text(
                          'No $_selectedFilter notifications',
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => ref
                            .read(notificationRepositoryProvider)
                            .fetchNotifications(),
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          itemCount: notifications.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            thickness: 0.5,
                            color: isDark ? Colors.white10 : Colors.black12,
                          ),
                          itemBuilder: (context, index) {
                            final notification = notifications[index];
                            final isSelected = _selectedIds.contains(notification.id);

                            return Dismissible(
                              key: Key('notif_${notification.id}'),
                              direction: _isSelectionMode
                                  ? DismissDirection.none
                                  : DismissDirection.horizontal,
                              background: Container(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                color: Colors.redAccent.withValues(alpha: 0.85),
                                child: const Row(
                                  children: [
                                    Icon(Icons.delete_rounded, color: Colors.white, size: 22),
                                    SizedBox(width: 8),
                                    Text(
                                      'Delete',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              secondaryBackground: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                color: Colors.redAccent.withValues(alpha: 0.85),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Delete',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(Icons.delete_rounded, color: Colors.white, size: 22),
                                  ],
                                ),
                              ),
                              onDismissed: (direction) {
                                HapticFeedback.mediumImpact();
                                ref
                                    .read(notificationRepositoryProvider)
                                    .deleteNotification(notification.id);
                                CustomSnackbar.show(
                                  context,
                                  message: 'Notification removed',
                                );
                              },
                              child: Material(
                                color: isSelected
                                    ? theme.primaryColor.withValues(alpha: 0.15)
                                    : (!notification.isRead
                                        ? (isDark
                                            ? const Color(0xFF161F2E)
                                            : const Color(0xFFF0F6FF))
                                        : Colors.transparent),
                                child: InkWell(
                                  onTap: () => _handleNotificationTap(notification),
                                  onLongPress: () {
                                    if (!_isSelectionMode) {
                                      _enterSelectionMode(notification.id);
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 13,
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Leading Avatar with Type Badge
                                        Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            UserAvatar(
                                              userId: notification.senderId.isNotEmpty
                                                  ? notification.senderId
                                                  : 'user',
                                              avatarUrl: notification.senderAvatarUrl,
                                              displayName: notification.senderName.isNotEmpty
                                                  ? notification.senderName
                                                  : 'User',
                                              radius: 23,
                                              showStoryRing: false,
                                            ),
                                            Positioned(
                                              right: -2,
                                              bottom: -2,
                                              child: _buildTypeBadge(notification.type),
                                            ),
                                            if (isSelected)
                                              Positioned.fill(
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: theme.primaryColor.withValues(alpha: 0.7),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.check_rounded,
                                                    color: Colors.white,
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(width: 14),

                                        // Main Content
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      notification.title,
                                                      style: TextStyle(
                                                        fontWeight: notification.isRead
                                                            ? FontWeight.w600
                                                            : FontWeight.w800,
                                                        fontSize: 15,
                                                        color: isDark ? Colors.white : Colors.black87,
                                                      ),
                                                    ),
                                                  ),
                                                  Text(
                                                    _formatTimestamp(notification.timestamp),
                                                    style: TextStyle(
                                                      fontSize: 11.5,
                                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                notification.body,
                                                style: TextStyle(
                                                  fontSize: 13.5,
                                                  height: 1.3,
                                                  color: notification.isRead
                                                      ? (isDark ? Colors.grey[300] : Colors.grey[800])
                                                      : (isDark ? Colors.white : Colors.black),
                                                  fontWeight: notification.isRead
                                                      ? FontWeight.normal
                                                      : FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Trailing Unread Dot Indicator
                                        if (!notification.isRead && !_isSelectionMode)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 8, top: 4),
                                            child: Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: theme.primaryColor,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: theme.primaryColor.withValues(alpha: 0.5),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 1),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (e, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 40, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text('Failed to load notifications: $e'),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => ref
                    .read(notificationRepositoryProvider)
                    .fetchNotifications(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String key, int count) {
    final isSelected = _selectedFilter == key;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (count == 0 && key != 'all') {
      return const SizedBox.shrink();
    }

    return ChoiceChip(
      label: Text(
        count > 0 ? '$label ($count)' : label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected
              ? Colors.white
              : (isDark ? Colors.grey[300] : Colors.grey[800]),
        ),
      ),
      selected: isSelected,
      selectedColor: theme.primaryColor,
      backgroundColor: isDark ? const Color(0xFF1E242B) : const Color(0xFFEBF0F5),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? Colors.transparent
              : (isDark ? Colors.white12 : Colors.black12),
        ),
      ),
      onSelected: (selected) {
        if (selected) {
          HapticFeedback.selectionClick();
          setState(() {
            _selectedFilter = key;
          });
        }
      },
    );
  }
}
