import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/notification_repository.dart';
import '../domain/notification.dart';
import 'package:intl/intl.dart';
import '../../../core/presentation/widgets/custom_snackbar.dart';
import '../../../shared/widgets/user_avatar.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

  void _toggleSelection(String id) {
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
    setState(() {
      _selectedIds.addAll(notifications.map((n) => n.id));
    });
  }

  void _inverseSelection(List<AppNotification> notifications) {
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
          'Are you sure you want to delete ${_selectedIds.length} notifications?',
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
      try {
        await ref
            .read(notificationRepositoryProvider)
            .deleteNotifications(_selectedIds.toList());
        if (mounted) {
          CustomSnackbar.show(context, message: 'Notifications deleted');
          _exitSelectionMode();
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

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(userNotificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('${_selectedIds.length} Selected')
            : const Text('Notifications'),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              )
            : null,
        actions: notificationsAsync.when(
          data: (notifications) {
            if (_isSelectionMode) {
              return [
                IconButton(
                  icon: const Icon(Icons.select_all),
                  tooltip: 'Select All',
                  onPressed: () => _selectAll(notifications),
                ),
                IconButton(
                  icon: const Icon(Icons.flip),
                  tooltip: 'Inverse Selection',
                  onPressed: () => _inverseSelection(notifications),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete Selected',
                  onPressed: _deleteSelected,
                ),
              ];
            }
            return [
              if (notifications.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.done_all),
                  tooltip: 'Mark all as read',
                  onPressed: () {
                    for (final n in notifications) {
                      if (!n.isRead) {
                        ref
                            .read(notificationRepositoryProvider)
                            .markAsRead(n.id);
                      }
                    }
                  },
                ),
            ];
          },
          loading: () => [],
          error: (_, __) => [],
        ),
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(child: Text('No notifications yet'));
          }

          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final isSelected = _selectedIds.contains(notification.id);

              return ListTile(
                leading: Stack(
                  children: [
                  UserAvatar(
                    userId: notification.senderId,
                    avatarUrl: notification.senderAvatarUrl,
                    displayName: notification.senderName,
                    radius: 20,
                    showStoryRing: true,
                  ),
                    if (isSelected)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
                title: Text(
                  notification.title,
                  style: TextStyle(
                    fontWeight: notification.isRead
                        ? FontWeight.normal
                        : FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notification.body),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat.yMMMd().add_jm().format(
                        notification.timestamp,
                      ),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                tileColor: isSelected
                    ? Colors.blue.withValues(alpha: 0.1)
                    : (notification.isRead
                          ? null
                          : Colors.blue.withValues(alpha: 0.05)),
                onTap: () {
                  if (_isSelectionMode) {
                    _toggleSelection(notification.id);
                  } else {
                    // Mark as read
                    if (!notification.isRead) {
                      ref
                          .read(notificationRepositoryProvider)
                          .markAsRead(notification.id);
                    }
                    // Navigate based on type
                    // Navigate based on type
                    final relatedId = notification.relatedId;
                    switch (notification.type) {
                      case NotificationType.chat:
                        if (relatedId != null) context.push('/chat/$relatedId');
                        break;
                      case NotificationType.like:
                      case NotificationType.comment:
                      case NotificationType.repost:
                        if (relatedId != null) context.push('/post/$relatedId');
                        break;
                      case NotificationType.follow:
                      case NotificationType.mention:
                      case NotificationType.storyUpdate:
                        if (relatedId != null) {
                          context.push('/user/$relatedId');
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
                        break;
                      case NotificationType.unfollow:
                        if (relatedId != null) {
                          context.push('/user/$relatedId');
                        }
                        break;
                      case NotificationType.followingPost:
                        if (relatedId != null) {
                          context.push('/post/$relatedId');
                        }
                        break;
                    }
                  }
                },
                onLongPress: () {
                  if (!_isSelectionMode) {
                    _enterSelectionMode(notification.id);
                  }
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, stack) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
