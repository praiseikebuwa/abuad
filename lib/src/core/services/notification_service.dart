import 'dart:async';
import 'package:flutter/material.dart';
import 'api_client.dart';
import '../../features/notifications/domain/notification.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  Future<void> initialize() async {
    debugPrint('🔔 NotificationService initialized (Native Backend Notifications)');
  }

  Future<void> consumePendingInitialMessage() async {}

  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    debugPrint('📢 Local Notification: $title - $body');
  }

  Future<void> sendInAppNotification({
    required String recipientId,
    required String title,
    required String body,
    required NotificationType type,
    Map<String, dynamic>? data,
    String? senderId,
    String? senderName,
    String? senderAvatarUrl,
  }) async {
    try {
      await ApiClient.post('/utilities/notifications', {
        'recipientId': recipientId,
        'title': title,
        'body': body,
        'type': type.name,
      });
    } catch (e) {
      debugPrint('Error sending in-app notification: $e');
    }
  }

  Future<void> sendMentionNotification({
    required String targetUserId,
    required String mentionedByUserName,
    required String postId,
  }) async {
    try {
      await ApiClient.post('/utilities/notifications', {
        'recipientId': targetUserId,
        'title': 'New Mention',
        'body': '$mentionedByUserName mentioned you in a post',
        'type': 'mention',
        'data': {'postId': postId},
      });
    } catch (e) {
      debugPrint('Error sending mention notification: $e');
    }
  }
}
