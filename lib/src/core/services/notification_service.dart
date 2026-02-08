import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> initialize() async {
    _setupLocalNotifications();
    _listenForNotifications();
  }

  void _setupLocalNotifications() {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    _localNotifications.initialize(initializationSettings);
  }

  void _listenForNotifications() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(1)
        .listen((List<Map<String, dynamic>> data) {
          if (data.isNotEmpty) {
            final notification = data.first;
            // Basic check to avoid showing old notifications on restart
            // In a real app, you might want a 'read' or 'delivered' flag status check
            final createdAt = DateTime.parse(notification['created_at']);
            if (createdAt.isAfter(
              DateTime.now().subtract(const Duration(seconds: 10)),
            )) {
              _showLocalNotification(
                title: notification['title'] ?? 'New Notification',
                body: notification['body'] ?? '',
              );
            }
          }
        });
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'high_importance_channel', // id
          'High Importance Notifications', // title
          importance: Importance.max,
          priority: Priority.high,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    // Use a random ID or hash of the body/title
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      platformChannelSpecifics,
    );
  }
}
