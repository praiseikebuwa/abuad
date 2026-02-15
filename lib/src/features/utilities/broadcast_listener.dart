import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BroadcastListener extends StatefulWidget {
  final Widget child;
  const BroadcastListener({super.key, required this.child});

  @override
  State<BroadcastListener> createState() => _BroadcastListenerState();
}

class _BroadcastListenerState extends State<BroadcastListener> {
  StreamSubscription<QuerySnapshot>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = FirebaseFirestore.instance
        .collection('announcements')
        .where('active', isEqualTo: true)
        .orderBy('created_at', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            final doc = snapshot.docs.first;
            final data = doc.data(); // Ensure correct type for data
            _checkAndShowAlert(doc.id, data);
          }
        });
  }

  @override
  void dispose() {
    _subscription?.cancel();
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
