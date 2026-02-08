import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';

enum MapStyle {
  streets('Streets', 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
  satellite(
    'Satellite',
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
  ),
  dark(
    'Dark',
    'https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}{r}.png',
  ),
  terrain('Terrain', 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png');

  final String label;
  final String urlTemplate;
  const MapStyle(this.label, this.urlTemplate);
}

enum LocationCategory {
  all('All', Icons.map),
  academic('Academic', Icons.school),
  food('Food', Icons.restaurant),
  hostel('Hostels', Icons.house),
  sports('Sports', Icons.sports_soccer),
  health('Health', Icons.local_hospital),
  other('Other', Icons.place);

  final String label;
  final IconData icon;
  const LocationCategory(this.label, this.icon);
}

class MapMarkerData {
  final String title;
  final LatLng point;
  final LocationCategory category;
  final Color? color;

  MapMarkerData({
    required this.title,
    required this.point,
    required this.category,
    this.color,
  });
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // ABUAD Coordinates
  final _initialCenter = const LatLng(7.6180, 5.2750);
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  bool _isLoadingLocation = false;
  MapStyle _currentMapStyle = MapStyle.satellite;
  LocationCategory _selectedCategory = LocationCategory.all;

  // Define Markers Data
  final List<MapMarkerData> _allMarkersData = [
    MapMarkerData(
      title: 'Senate Building',
      point: const LatLng(7.6180, 5.2750),
      category: LocationCategory.academic,
      color: const Color(0xFF3B82F6),
    ),
    MapMarkerData(
      title: 'Engineering',
      point: const LatLng(7.6150, 5.2780),
      category: LocationCategory.academic,
      color: const Color(0xFF10B981),
    ),
    MapMarkerData(
      title: 'Afe Babalola Hospital',
      point: const LatLng(7.6200, 5.2720),
      category: LocationCategory.health,
      color: const Color(0xFFEF4444),
    ),
    MapMarkerData(
      title: 'Cafeteria 1',
      point: const LatLng(7.6130, 5.2740),
      category: LocationCategory.food,
      color: const Color(0xFFF59E0B),
    ),
    MapMarkerData(
      title: 'Law Library',
      point: const LatLng(7.6165, 5.2765),
      category: LocationCategory.academic,
      color: const Color(0xFF8B5CF6),
    ),
    MapMarkerData(
      title: 'Sports Complex',
      point: const LatLng(7.6140, 5.2725),
      category: LocationCategory.sports,
      color: const Color(0xFF06B6D4),
    ),
  ];

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) _showToast("Location services are disabled.");
      setState(() => _isLoadingLocation = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) _showToast("Location permissions are denied");
        setState(() => _isLoadingLocation = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) _showToast("Location permissions are permanently denied");
      setState(() => _isLoadingLocation = false);
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });
      _mapController.move(_currentPosition!, 17.0);
    } catch (e) {
      if (mounted) _showToast("Error getting location: $e");
      setState(() => _isLoadingLocation = false);
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _launchMaps(double lat, double lng) async {
    final googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) _showToast('Could not launch maps');
    }
  }

  void _showLocationDetails(MapMarkerData data) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = data.color ?? theme.primaryColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Icon and Title
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(data.category.icon, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 16),

              Text(
                data.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  data.category.label,
                  style: TextStyle(
                    fontSize: 14,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _launchMaps(data.point.latitude, data.point.longitude);
                  },
                  icon: const Icon(Icons.directions),
                  label: const Text('Get Directions'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMapStyleSheet() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Map Style',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              ...MapStyle.values.map((style) {
                final isSelected = style == _currentMapStyle;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Icon(
                      style == MapStyle.satellite
                          ? Icons.satellite_alt
                          : style == MapStyle.dark
                          ? Icons.dark_mode
                          : style == MapStyle.terrain
                          ? Icons.terrain
                          : Icons.map,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : (isDark ? Colors.grey[500] : Colors.grey[700]),
                    ),
                    title: Text(
                      style.label,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : (isDark ? Colors.grey[800]! : Colors.grey[300]!),
                      ),
                    ),
                    onTap: () {
                      setState(() => _currentMapStyle = style);
                      Navigator.pop(context);
                    },
                  ),
                );
              }),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  // --- Markers Logic ---
  List<Marker> get _markers {
    final filteredData = _selectedCategory == LocationCategory.all
        ? _allMarkersData
        : _allMarkersData
              .where((m) => m.category == _selectedCategory)
              .toList();

    return filteredData.map((data) {
      final color = data.color ?? Colors.red;
      return Marker(
        point: data.point,
        width: 80,
        height: 80,
        child: GestureDetector(
          onTap: () => _showLocationDetails(data),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // 3D-style marker
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Icon(
                    data.category.icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // Label
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  data.title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Campus Map',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                isDark
                    ? Colors.black.withOpacity(0.8)
                    : Colors.white.withOpacity(0.9),
                Colors.transparent,
              ],
            ),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              shape: BoxShape.circle,
              boxShadow: AppColors.softShadow,
            ),
            child: IconButton(
              icon: const Icon(Icons.layers),
              onPressed: _showMapStyleSheet,
              tooltip: 'Map Style',
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 16.5,
              minZoom: 13.0,
              maxZoom: 19.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onTap: (_, __) {
                // Close any open overlays if needed
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _currentMapStyle.urlTemplate,
                userAgentPackageName: 'com.example.abuad',
                subdomains: const ['a', 'b', 'c'],
              ),
              MarkerLayer(
                markers: [
                  ..._markers,
                  if (_currentPosition != null)
                    Marker(
                      point: _currentPosition!,
                      width: 80,
                      height: 80,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Pulsing effect for current location
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.info.withOpacity(0.2),
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF3B82F6),
                                    Color(0xFF2563EB),
                                  ],
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.5),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.navigation,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Category Chips (New Feature)
          Positioned(
            top: 100, // Below AppBar
            left: 0,
            right: 0,
            child: SafeArea( // Ensure it doesn't get cut off by notch
              top: false,
              child: SizedBox(
                height: 40,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: LocationCategory.values.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final category = LocationCategory.values[index];
                  final isSelected = _selectedCategory == category;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = category),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryInk
                            : theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? Colors.transparent
                              : (isDark
                                    ? AppColors.borderDark
                                    : AppColors.borderLight),
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primaryInk.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : [],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            category.icon,
                            size: 16,
                            color: isSelected
                                ? Colors.white
                                : theme.iconTheme.color,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            category.label,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : theme.textTheme.bodyMedium?.color,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        )
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 50.0), // Lift above bottom nav
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Zoom controls
          Container(
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppColors.softShadow,
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    final currentZoom = _mapController.camera.zoom;
                    _mapController.move(
                      _mapController.camera.center,
                      currentZoom + 1,
                    );
                  },
                ),
                Container(
                  height: 1,
                  width: 30,
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () {
                    final currentZoom = _mapController.camera.zoom;
                    _mapController.move(
                      _mapController.camera.center,
                      currentZoom - 1,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Location button
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: _getCurrentLocation,
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: _isLoadingLocation
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.my_location, color: Colors.white),
            ),
          ),
        ],
      ),
      )
    );
  }
}
