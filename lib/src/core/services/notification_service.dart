import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../../core/router/app_router.dart';
import '../../features/notifications/domain/notification.dart';

// Top-level function for background handling
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you need to access Firebase services here, you might need:
  // await Firebase.initializeApp();
  debugPrint('Handling a background message ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  static const String _channelId = 'high_importance_channel';
  static const String _channelName = 'High Importance Notifications';
  static const String _channelDesc =
      'This channel is used for important notifications.';

  Future<void> initialize() async {
    // 1. Setup Local Notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS/macOS permissions are requested in requestPermission()
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
          macOS: initializationSettingsDarwin,
        );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleLocalNotificationTap(response);
      },
    );

    // 1.5 Initialise Timezone
    tz.initializeTimeZones();
    try {
      final dynamic timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      // Most timezone plugins return the ID as toString() or have a name/id property.
      // We'll try toString() as it's the safest bet for a string conversion.
      final String timeZoneName = timeZoneInfo.toString();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint('Could not get local timezone: $e');
      // Fallback to UTC if timezone lookup fails
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    // 2. Create Android Notification Channel
    final AndroidNotificationChannel androidChannel =
        AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.max,
        );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);

    // 3. Request Permissions & Setup FCM
    await _setupFCM(androidChannel);

    // 4. Setup Auth Listener for Token Refresh
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        _fcm.getToken().then((token) {
          if (token != null) _saveTokenToFirestore(token);
        });
      }
    });
  }

  Future<void> _setupFCM(AndroidNotificationChannel channel) async {
    // Request Permission
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted notification permission');

      // Get Token
      String? token = await _fcm.getToken();
      if (token != null) {
        _saveTokenToFirestore(token);
      }

      // Listen for Token Refresh
      _fcm.onTokenRefresh.listen(_saveTokenToFirestore);

      // Subscribe to global topic
      await _fcm.subscribeToTopic('all_users');

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        if (notification != null && android != null) {
          _showLocalNotification(message, channel);
        }
      });

      // Handle Background App Open
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageNavigation);

      // Handle Terminated State App Open
      _fcm.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          _pendingInitialMessage = message;
        }
      });
    } else {
      debugPrint('User declined or has not accepted notification permission');
    }
  }

  RemoteMessage? _pendingInitialMessage;

  void consumePendingInitialMessage() {
    if (_pendingInitialMessage != null) {
      _handleMessageNavigation(_pendingInitialMessage!);
      _pendingInitialMessage = null;
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
      debugPrint('FCM Token saved');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  Future<void> _showLocalNotification(
    RemoteMessage message,
    AndroidNotificationChannel channel,
  ) async {
    final notification = message.notification;
    final android = message.notification?.android;
    if (notification == null || android == null) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          icon: android.smallIcon,
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _handleMessageNavigation(RemoteMessage message) {
    debugPrint("Handling navigation for message: ${message.data}");
    final data = message.data;
    _navigateBasedOnData(data);
  }

  void _handleLocalNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final Map<String, dynamic> data = jsonDecode(response.payload!);
        _navigateBasedOnData(data);
      } catch (e) {
        debugPrint('Error decoding notification payload: $e');
      }
    }
  }

  void _navigateBasedOnData(Map<String, dynamic> data) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    final type = data['type'];
    final id = data['id']; // userId, channelId, postId etc.

    if ((type == 'chat' ||
            type == 'streakExpiring' ||
            type == 'streakMissed') &&
        id != null) {
      GoRouter.of(context).push('/chat/$id');
    } else if ((type == 'user' ||
            type == 'follower' ||
            type == 'follow' ||
            type == 'unfollow') &&
        id != null) {
      GoRouter.of(context).push('/user/$id');
    } else if ((type == 'post' ||
            type == 'storyUpdate' ||
            type == 'followingPost') &&
        id != null) {
      if (type == 'storyUpdate') {
        GoRouter.of(context).push('/stories/$id');
      } else {
        GoRouter.of(context).push('/post/$id');
      }
    }
  }

  // --- New Feature Methods ---

  /// Schedules a local notification to warn about streak expiry
  Future<void> scheduleStreakWarning({
    required String channelId,
    required String otherUserName,
    required DateTime expiryTime,
    int warningHoursBefore = 2,
  }) async {
    final scheduledDate = expiryTime.subtract(
      Duration(hours: warningHoursBefore),
    );
    if (scheduledDate.isBefore(DateTime.now())) return;

    final id =
        channelId.hashCode; // Unique ID for this channel's streak notification

    await _localNotifications.zonedSchedule(
      id,
      'Streak Expiring! 🔥',
      'Your streak with $otherUserName is about to expire in $warningHoursBefore hours. Send a snap now! ⏳',
      tz.TZDateTime.from(scheduledDate, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode({'type': 'streakExpiring', 'id': channelId}),
    );
  }

  /// Cancels a scheduled streak warning (e.g. if snap is sent)
  Future<void> cancelStreakWarning(String channelId) async {
    await _localNotifications.cancel(channelId.hashCode);
  }

  /// General helper to send an in-app notification record to Firestore
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
      final senderUid = senderId ?? _auth.currentUser?.uid ?? 'system';

      final docRef = _firestore
          .collection('users')
          .doc(recipientId)
          .collection('notifications')
          .doc();

      await docRef.set({
        'id': docRef.id,
        'recipient_id': recipientId,
        'sender_id': senderUid,
        'sender_name': senderName ?? 'ABUAD',
        'sender_avatar_url': senderAvatarUrl,
        'type': type.name,
        'title': title,
        'body': body,
        'related_id': data?['id'],
        'timestamp': FieldValue.serverTimestamp(),
        'is_read': false,
        'data': data,
      });
    } catch (e) {
      debugPrint('Error sending in-app notification: $e');
    }
  }

  // Helper handling purely local triggers (like from in-app events)
  Future<void> sendMentionNotification({
    required String targetUserId,
    required String mentionedByUserName,
    required String postId,
  }) async {
    // In a real app, this should be done via Cloud Functions sending an FCM message.
    // Writing to Firestore 'notifications' collection is a good fallback for "In-App Notification Center".
    try {
      await _firestore.collection('notifications').add({
        'user_id': targetUserId,
        'title': 'New Mention',
        'body': '$mentionedByUserName mentioned you in a post',
        'type': 'mention',
        'data': {'post_id': postId},
        'created_at': FieldValue.serverTimestamp(),
        'is_read': false,
      });
    } catch (e) {
      debugPrint('Error sending mention notification: $e');
    }
  }
}
