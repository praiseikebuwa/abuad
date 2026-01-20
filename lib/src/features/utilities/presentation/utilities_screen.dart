import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class UtilitiesScreen extends StatelessWidget {
  const UtilitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Campus Utilities')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildUtilityCard(
            context,
            icon: Icons.directions_bus,
            title: 'Shuttle Tracker',
            subtitle: 'Track campus shuttles in real-time',
            color: Colors.blue,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ShuttleTrackerScreen(),
                ),
              );
            },
          ),
          _buildUtilityCard(
            context,
            icon: Icons.emergency,
            title: 'SOS / Emergency',
            subtitle: 'Quick access to campus security',
            color: Colors.red,
            onTap: () {
              _showSOSDialog(context);
            },
          ),
          _buildUtilityCard(
            context,
            icon: Icons.restaurant_menu,
            title: 'Food Ordering',
            subtitle: 'Pre-order from campus cafeteria',
            color: Colors.orange,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FoodOrderingScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUtilityCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  void _showSOSDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Emergency Contact'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Campus Security: 0800-ABUAD-911'),
            const SizedBox(height: 8),
            const Text('Medical Emergency: 0800-HEALTH'),
            const SizedBox(height: 16),
            Text(
              'Your location will be shared with security.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              // In a real app, this would call emergency services
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Emergency alert sent to campus security'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: const Text('Call Security'),
          ),
        ],
      ),
    );
  }
}

// Shuttle Tracker Screen
class ShuttleTrackerScreen extends StatelessWidget {
  const ShuttleTrackerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shuttleLocation = const LatLng(7.6170, 5.2760);

    return Scaffold(
      appBar: AppBar(title: const Text('Shuttle Tracker')),
      body: FlutterMap(
        options: MapOptions(initialCenter: shuttleLocation, initialZoom: 15.0),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.abuad',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: shuttleLocation,
                width: 80,
                height: 80,
                child: const Column(
                  children: [
                    Icon(Icons.directions_bus, color: Colors.blue, size: 40),
                    Text(
                      'Shuttle 1',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Shuttle 1',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Next Stop: Engineering Complex',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16),
                const SizedBox(width: 4),
                Text(
                  'ETA: 5 minutes',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Food Ordering Screen
class FoodOrderingScreen extends StatelessWidget {
  const FoodOrderingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final menuItems = [
      {'name': 'Jollof Rice & Chicken', 'price': '1500', 'category': 'Main'},
      {'name': 'Fried Rice', 'price': '1200', 'category': 'Main'},
      {'name': 'Amala & Ewedu', 'price': '800', 'category': 'Local'},
      {'name': 'Pounded Yam', 'price': '1000', 'category': 'Local'},
      {'name': 'Meat Pie', 'price': '300', 'category': 'Snacks'},
      {'name': 'Soft Drink', 'price': '200', 'category': 'Drinks'},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Cafeteria Menu')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: menuItems.length,
        itemBuilder: (context, index) {
          final item = menuItems[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.orange.withOpacity(0.1),
                child: const Icon(Icons.restaurant, color: Colors.orange),
              ),
              title: Text(item['name']!),
              subtitle: Text(item['category']!),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₦${item['price']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${item['name']} added to cart')),
                );
              },
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: FilledButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Order Placed'),
                  content: const Text(
                    'Your order will be ready in 15 minutes.',
                  ),
                  actions: [
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
            child: const Text('Place Order'),
          ),
        ),
      ),
    );
  }
}
