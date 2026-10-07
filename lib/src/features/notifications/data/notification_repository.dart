import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';
import '../domain/notification.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final repo = NotificationRepository();
  ref.onDispose(() => repo.dispose());
  return repo;
});

final userNotificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.watchNotifications();
});

class NotificationRepository {
  final _controller = StreamController<List<AppNotification>>.broadcast();
  List<AppNotification> _cachedNotifications = [];
  bool _hasFetched = false;

  NotificationRepository([dynamic _]);

  String? get currentUserId => null;

  Stream<List<AppNotification>> watchNotifications() {
    // Emit current cache immediately if available
    if (_hasFetched) {
      scheduleMicrotask(() {
        if (!_controller.isClosed) {
          _controller.add(List.unmodifiable(_cachedNotifications));
        }
      });
    }
    // Fetch fresh from backend
    fetchNotifications();
    return _controller.stream;
  }

  Future<List<AppNotification>> fetchNotifications() async {
    try {
      final response = await ApiClient.get('/utilities/notifications');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          _cachedNotifications = (data['data'] as List)
              .map((x) => AppNotification.fromMap(x as Map<String, dynamic>))
              .toList();
          _hasFetched = true;
          if (!_controller.isClosed) {
            _controller.add(List.unmodifiable(_cachedNotifications));
          }
          return _cachedNotifications;
        }
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    }
    if (!_hasFetched && !_controller.isClosed) {
      _controller.add([]);
    }
    return _cachedNotifications;
  }

  Future<void> sendNotification({
    required String recipientId,
    required String senderId,
    required String senderName,
    String? senderAvatarUrl,
    required NotificationType type,
    required String title,
    required String body,
    String? relatedId,
  }) async {
    if (recipientId.isEmpty || recipientId == senderId) {
      return;
    }
    try {
      await ApiClient.post('/utilities/notifications', {
        'recipientId': recipientId,
        'senderId': senderId,
        'senderName': senderName,
        'senderAvatarUrl': senderAvatarUrl,
        'title': title,
        'body': body,
        'type': type.name,
        'relatedId': relatedId,
      });
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  Future<void> markAsRead(String notificationId) async {
    // Optimistic update
    final index = _cachedNotifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _cachedNotifications[index] = _cachedNotifications[index].copyWith(isRead: true);
      if (!_controller.isClosed) {
        _controller.add(List.unmodifiable(_cachedNotifications));
      }
    }
    try {
      await ApiClient.patch('/utilities/notifications/$notificationId/read', {});
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    // Optimistic update
    _cachedNotifications = _cachedNotifications
        .map((n) => n.copyWith(isRead: true))
        .toList();
    if (!_controller.isClosed) {
      _controller.add(List.unmodifiable(_cachedNotifications));
    }
    try {
      await ApiClient.patch('/utilities/notifications/read-all', {});
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    // Optimistic update
    _cachedNotifications.removeWhere((n) => n.id == notificationId);
    if (!_controller.isClosed) {
      _controller.add(List.unmodifiable(_cachedNotifications));
    }
    try {
      await ApiClient.delete('/utilities/notifications/$notificationId');
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  Future<void> deleteNotifications(List<String> notificationIds) async {
    final idSet = notificationIds.toSet();
    _cachedNotifications.removeWhere((n) => idSet.contains(n.id));
    if (!_controller.isClosed) {
      _controller.add(List.unmodifiable(_cachedNotifications));
    }
    try {
      await ApiClient.delete('/utilities/notifications', {'ids': notificationIds});
    } catch (e) {
      debugPrint('Error deleting notifications: $e');
    }
  }

  Future<void> clearAllNotifications() async {
    _cachedNotifications.clear();
    if (!_controller.isClosed) {
      _controller.add([]);
    }
    try {
      await ApiClient.delete('/utilities/notifications', {});
    } catch (e) {
      debugPrint('Error clearing all notifications: $e');
    }
  }

  void dispose() {
    _controller.close();
  }
}
