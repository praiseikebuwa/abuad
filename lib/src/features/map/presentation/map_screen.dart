import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Approximate ABUAD Coordinates
  final _initialCenter = const LatLng(7.6180, 5.2750);

  final List<Marker> _markers = [
    Marker(
      point: const LatLng(7.6180, 5.2750),
      width: 60,
      height: 60,
      child: const Column(
        children: [
          Icon(Icons.location_city, color: Colors.blue, size: 40),
          Text(
            'Senate',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              backgroundColor: Colors.white,
            ),
          ),
        ],
      ),
    ),
    Marker(
      point: const LatLng(7.6150, 5.2780),
      width: 60,
      height: 60,
      child: const Column(
        children: [
          Icon(Icons.school, color: Colors.green, size: 40),
          Text(
            'Engineering',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              backgroundColor: Colors.white,
            ),
          ),
        ],
      ),
    ),
    Marker(
      point: const LatLng(7.6200, 5.2720),
      width: 60,
      height: 60,
      child: const Column(
        children: [
          Icon(Icons.local_hospital, color: Colors.red, size: 40),
          Text(
            'Teaching Hospital',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              backgroundColor: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
    Marker(
      point: const LatLng(7.6130, 5.2740),
      width: 60,
      height: 60,
      child: const Column(
        children: [
          Icon(Icons.restaurant, color: Colors.orange, size: 40),
          Text(
            'Cafeteria',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              backgroundColor: Colors.white,
            ),
          ),
        ],
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Map'),
        actions: [IconButton(icon: const Icon(Icons.layers), onPressed: () {})],
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: _initialCenter,
          initialZoom: 15.0,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.abuad',
            // Using OSM for now. For premium feel, we could use Mapbox if we had keys.
          ),
          MarkerLayer(markers: _markers),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: Colors.white,
        child: const Icon(Icons.my_location, color: Colors.black),
      ),
    );
  }
}
