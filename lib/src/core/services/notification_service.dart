import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';

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

    if (type == 'chat' && id != null) {
      GoRouter.of(context).push('/chat/$id');
    } else if ((type == 'user' || type == 'follower') && id != null) {
      GoRouter.of(context).push('/user/$id');
    } else if (type == 'post' && id != null) {
      GoRouter.of(context).push('/post/$id');
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
