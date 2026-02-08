import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BroadcastListener extends StatefulWidget {
  final Widget child;
  const BroadcastListener({super.key, required this.child});

  @override
  State<BroadcastListener> createState() => _BroadcastListenerState();
}

class _BroadcastListenerState extends State<BroadcastListener> {
  // Listen to broadcasts from the last 24 hours to avoid spamming old stuff
  late Stream<List<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = Supabase.instance.client
        .from('announcements')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(1)
        .map((data) => data.where((e) => e['active'] == true).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // Invisible listener
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
              final data = snapshot.data!.first;
              final id = data['id'];
              _checkAndShowAlert(id.toString(), data);
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Future<void> _checkAndShowAlert(String id, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final seenKey = 'seen_broadcast_$id';

    // Check if already seen
    if (prefs.getBool(seenKey) == true) return;

    // Passively wait for frame to be ready before showing dialog
    if (!mounted) return;

    // Mark as seen immediately so it doesn't pop up again
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
      barrierDismissible: type != 'urgent', // Force action for urgent?
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
