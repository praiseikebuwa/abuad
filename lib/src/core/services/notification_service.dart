import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:toastification/toastification.dart';
import 'api_client.dart';
import '../../features/notifications/domain/notification.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  static const String channelId = 'abuad_alerts_v2';
  static const String channelName = 'ABUAD Alerts & Notifications';
  static const String channelDescription =
      'Realtime alerts, direct messages, academic notices, and campus announcements';

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Android Initialization Settings
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS / Darwin Initialization Settings
      final darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      final initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('🔔 Notification clicked: ${response.payload}');
        },
      );

      // Create Android Notification Channel
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        const androidChannel = AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        );

        await androidImplementation.createNotificationChannel(androidChannel);

        // Request permissions on Android 13+
        await androidImplementation.requestNotificationsPermission();
      }

      _isInitialized = true;
      debugPrint('🔔 FlutterLocalNotificationsPlugin initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize FlutterLocalNotificationsPlugin: $e');
    }
  }

  Future<void> consumePendingInitialMessage() async {
    try {
      final details =
          await _notificationsPlugin.getNotificationAppLaunchDetails();
      if (details != null && details.didNotificationLaunchApp) {
        debugPrint(
            '🔔 App launched from notification: ${details.notificationResponse?.payload}');
      }
    } catch (_) {}
  }

  /// Displays OS-level notification banner + in-app toastification popup
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String? type,
  }) async {
    final notificationId =
        DateTime.now().millisecondsSinceEpoch.remainder(100000);

    // 1. Dispatch OS-Level System Notification
    try {
      const androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(''),
        playSound: true,
        enableVibration: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('System local notification show error: $e');
    }

    // 2. Dispatch In-App Heads-Up Toastification Banner
    try {
      toastification.show(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        description: Text(
          body,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12.5),
        ),
        type: (type == 'urgent' || type == 'sos')
            ? ToastificationType.error
            : ((type == 'warning')
                ? ToastificationType.warning
                : ToastificationType.info),
        style: ToastificationStyle.flatColored,
        autoCloseDuration: const Duration(seconds: 5),
        alignment: Alignment.topCenter,
        direction: TextDirection.ltr,
        animationDuration: const Duration(milliseconds: 300),
        showProgressBar: true,
        applyBlurEffect: true,
      );
    } catch (e) {
      debugPrint('Toastification notification error: $e');
    }
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
