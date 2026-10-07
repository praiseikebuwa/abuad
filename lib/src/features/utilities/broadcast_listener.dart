import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/api_client.dart';

class BroadcastListener extends StatefulWidget {
  final Widget child;
  const BroadcastListener({super.key, required this.child});

  @override
  State<BroadcastListener> createState() => _BroadcastListenerState();
}

class _BroadcastListenerState extends State<BroadcastListener> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchBroadcasts();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _fetchBroadcasts());
  }

  Future<void> _fetchBroadcasts() async {
    if (!ApiClient.isAuthenticated) return;
    try {
      final response = await ApiClient.get('/announcements');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List && (data['data'] as List).isNotEmpty) {
          final first = (data['data'] as List).first;
          _checkAndShowAlert(first['id'] ?? '1', first as Map<String, dynamic>);
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  Future<void> _checkAndShowAlert(String id, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final seenKey = 'seen_broadcast_$id';

    if (prefs.getBool(seenKey) == true) return;
    if (!mounted) return;

    await prefs.setBool(seenKey, true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showBroadcastDialog(context, data);
    });
  }

  void _showBroadcastDialog(BuildContext context, Map<String, dynamic> data) {
    final type = data['type'] ?? 'info';
    Color color;
    IconData icon;
    String titlePrefix;

    switch (type) {
      case 'urgent':
        color = Colors.red;
        icon = Icons.warning_rounded;
        titlePrefix = "URGENT";
        break;
      case 'warning':
        color = Colors.orange;
        icon = Icons.info_outline;
        titlePrefix = "NOTICE";
        break;
      case 'info':
      default:
        color = Colors.blue;
        icon = Icons.notifications_active;
        titlePrefix = "UPDATE";
        break;
    }

    showDialog(
      context: context,
      barrierDismissible: type != 'urgent',
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                data['title'] ?? '$titlePrefix System Message',
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data['body'] ?? '', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            Text(
              "Sent by Admin",
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              "Dismiss",
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
