import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:badges/badges.dart' as badges;
import '../../data/notification_repository.dart';
import '../notifications_screen.dart';

class NotificationIcon extends ConsumerWidget {
  const NotificationIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(userNotificationsProvider);

    return notificationsAsync.when(
      data: (notifications) {
        final unreadCount = notifications.where((n) => !n.isRead).length;

        return IconButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
          },
          icon: badges.Badge(
            showBadge: unreadCount > 0,
            badgeContent: Text(
              '$unreadCount',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
            child: const Icon(Icons.notifications),
          ),
        );
      },
      loading: () =>
          const IconButton(onPressed: null, icon: Icon(Icons.notifications)),
      error: (error, stack) =>
          const IconButton(onPressed: null, icon: Icon(Icons.notifications)),
    );
  }
}
