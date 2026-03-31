import 'dart:async';
// import 'dart:math' as math; // Removed unused import
// import 'dart:ui' as ui; // Removed unused import

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../user/data/user_repository.dart';

enum MapStyle {
  normal('Normal', 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
  satellite(
    'Satellite',
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
  ),
  terrain('Terrain', 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png'),
  hybrid('Hybrid', 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png');

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
  static const double hueRed = 0.0;
  static const double hueOrange = 30.0;
  static const double hueYellow = 60.0;
  static const double hueGreen = 120.0;
  static const double hueCyan = 180.0;
  static const double hueAzure = 210.0;
  static const double hueBlue = 240.0;
  static const double hueViolet = 270.0;
  static const double hueMagenta = 300.0;
  static const double hueRose = 330.0;

  final String title;
  final LatLng point;
  final LocationCategory category;
  final double hue;
  final List<String>? rooms;

  MapMarkerData({
    required this.title,
    required this.point,
    required this.category,
    required this.hue,
    this.rooms,
  });
}

class MapReport {
  final LatLng point;
  final String title;
  final String description;
  final String type; // e.g. 'Traffic', 'Security', 'Maintenance'
  final DateTime timestamp;

  MapReport({
    required this.point,
    required this.title,
    required this.description,
    required this.type,
    required this.timestamp,
  });
}

class Shuttle {
  final String id;
  final String name;
  final LatLng position;
  final int capacity;
  final int currentPassengers;
  final String status; // 'Moving', 'Stopped', 'Full'

  Shuttle({
    required this.id,
    required this.name,
    required this.position,
    required this.capacity,
    required this.currentPassengers,
    required this.status,
  });
}

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  // ABUAD Coordinates (Real confirmed location)
  final _initialCenter = const LatLng(7.60250, 5.30610);
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionSub;
  LatLng? _currentPosition;
  Position? _latestPosition;
  bool _isLoadingLocation = false;
  bool _isTracking = false;
  bool _followUser = true;
  MapStyle _currentMapStyle =
      MapStyle.normal; // Changed from hybrid to normal for better reliability
  LocationCategory _selectedCategory = LocationCategory.all;
  MapMarkerData? _selectedDestination;
  double? _distanceToDestinationMeters;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<LatLng> _routePoints = []; // New: In-app navigation route
  final List<MapReport> _userReports = [
    // Pre-populating with some mock reports for Phase 4 demo
    MapReport(
      point: const LatLng(7.6035, 5.3055),
      title: 'Road Blocked',
      description: 'Construction work near College of Law.',
      type: 'Maintenance',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ];
  final List<Shuttle> _shuttles = [
    Shuttle(
      id: 'S1',
      name: 'Campus Shuttle 1',
      position: const LatLng(7.6010, 5.3085),
      capacity: 30,
      currentPassengers: 12,
      status: 'Moving',
    ),
    Shuttle(
      id: 'S2',
      name: 'Campus Shuttle 2',
      position: const LatLng(7.6045, 5.3065),
      capacity: 30,
      currentPassengers: 28,
      status: 'Stopped',
    ),
  ];
  bool _showShuttles = true;
  // Set<Marker> _markers = {}; // Removed unused field

  // Define Markers Data
  final List<MapMarkerData> _allMarkersData = [
    MapMarkerData(
      title: 'Senate Building',
      point: const LatLng(7.60250, 5.30610),
      category: LocationCategory.academic,
      hue: MapMarkerData.hueBlue,
      rooms: [
        'Vice Chancellor\'s Office',
        'Registry',
        'Bursary',
        'Senate Chamber',
      ],
    ),
    MapMarkerData(
      title: 'Engineering',
      point: const LatLng(7.59950, 5.30910),
      category: LocationCategory.academic,
      hue: MapMarkerData.hueGreen,
      rooms: [
        'Lecture Theatre 1',
        'Mechanical Lab',
        'Electrical Lab',
        'Dean\'s Office',
      ],
    ),
    MapMarkerData(
      title: 'Afe Babalola Hospital',
      point: const LatLng(7.60450, 5.30310),
      category: LocationCategory.health,
      hue: MapMarkerData.hueRed,
      rooms: ['Emergency Ward', 'Pharmacy', 'Diagnostic Center', 'ICU'],
    ),
    MapMarkerData(
      title: 'Cafeteria 1',
      point: const LatLng(7.59750, 5.30510),
      category: LocationCategory.food,
      hue: MapMarkerData.hueOrange,
    ),
    MapMarkerData(
      title: 'Law Library',
      point: const LatLng(7.60100, 5.30760),
      category: LocationCategory.academic,
      hue: MapMarkerData.hueViolet,
    ),
    MapMarkerData(
      title: 'Sports Complex',
      point: const LatLng(7.59850, 5.30360),
      category: LocationCategory.sports,
      hue: MapMarkerData.hueCyan,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startLiveLocation();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _startLiveLocation() async {
    await _getCurrentLocation();

    _positionSub?.cancel();
    _positionSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 3,
          ),
        ).listen(
          (position) {
            if (!mounted) return;
            final point = LatLng(position.latitude, position.longitude);
            setState(() {
              _latestPosition = position;
              _currentPosition = point;
              _isTracking = true;
            });
            _updateDistanceToSelected();

            if (_followUser) {
              _mapController.move(point, _mapController.camera.zoom);
            }

            // Sync to Firestore if tracking is active
            if (_isTracking) {
              ref
                  .read(userRepositoryProvider)
                  .updateUserLocation(position.latitude, position.longitude);
            }
          },
          onError: (error) {
            if (!mounted) return;
            setState(() => _isTracking = false);
            _showToast('Live location tracking stopped');
          },
        );
  }

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
      debugPrint('MapScreen: Fetching current position...');
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 8));

      debugPrint(
        'MapScreen: Position fetched: ${position.latitude}, ${position.longitude}',
      );
      setState(() {
        _latestPosition = position;
        _currentPosition = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });
      _updateDistanceToSelected();

      if (_currentPosition != null) {
        _mapController.move(_currentPosition!, 17.0);
      }
    } on TimeoutException {
      debugPrint('MapScreen: Location fetch timed out');
      if (mounted) {
        _showToast("Location request timed out. Using default center.");
      }
      setState(() => _isLoadingLocation = false);
    } catch (e) {
      debugPrint('MapScreen: Error getting location: $e');
      if (mounted) _showToast("Error getting location: $e");
      setState(() => _isLoadingLocation = false);
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _toggleFollowMode() {
    setState(() => _followUser = !_followUser);
    if (_followUser && _currentPosition != null) {
      _mapController.move(_currentPosition!, 17.0);
    }
  }

  void _updateDistanceToSelected() {
    if (_currentPosition == null || _selectedDestination == null) {
      _distanceToDestinationMeters = null;
      return;
    }
    _distanceToDestinationMeters = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _selectedDestination!.point.latitude,
      _selectedDestination!.point.longitude,
    );
  }

  String _distanceLabel(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  Future<void> _launchMaps(double lat, double lng) async {
    final googleMapsUrl = _currentPosition == null
        ? Uri.parse(
            'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
          )
        : Uri.parse(
            'https://www.google.com/maps/dir/?api=1&origin=${_currentPosition!.latitude},${_currentPosition!.longitude}&destination=$lat,$lng&travelmode=walking',
          );
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) _showToast('Could not launch maps');
    }
  }

  void _showReportDetails(MapReport report) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    report.type == 'Security' ? Icons.warning : Icons.info,
                    color: report.type == 'Security'
                        ? Colors.red
                        : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    report.type,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: report.type == 'Security'
                          ? Colors.red
                          : Colors.orange,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${DateTime.now().difference(report.timestamp).inMinutes}m ago',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                report.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(report.description),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReportDialog() {
    String title = '';
    String description = '';
    String selectedType = 'Traffic';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Report Campus Issue'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButton<String>(
                      value: selectedType,
                      isExpanded: true,
                      items: ['Traffic', 'Security', 'Maintenance', 'Other']
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (v) => setDialogState(() => selectedType = v!),
                    ),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Focus (e.g. Road Blocked)',
                      ),
                      onChanged: (v) => title = v,
                    ),
                    TextField(
                      decoration: const InputDecoration(labelText: 'Details'),
                      maxLines: 2,
                      onChanged: (v) => description = v,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (title.isNotEmpty && _currentPosition != null) {
                      setState(() {
                        _userReports.add(
                          MapReport(
                            point: _currentPosition!,
                            title: title,
                            description: description,
                            type: selectedType,
                            timestamp: DateTime.now(),
                          ),
                        );
                      });
                      Navigator.pop(context);
                      _showToast(
                        'Report submitted. Thank you for helping ABUAD!',
                      );
                    } else {
                      _showToast(
                        'Please provide a title and ensure location is active.',
                      );
                    }
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _calculateRoute(MapMarkerData destination) {
    if (_currentPosition == null) {
      _showToast("Current location unknown. Cannot calculate route.");
      return;
    }

    // Mocking an in-app routing logic for ABUAD Campus
    // In a real production app, this would integrate with OSRM, GraphHopper, or Google Directions API
    setState(() {
      _routePoints = [
        _currentPosition!,
        // Generate a simple intermediate point to simulate following a path/road
        LatLng(
          (_currentPosition!.latitude + destination.point.latitude) / 2 +
              0.0001,
          (_currentPosition!.longitude + destination.point.longitude) / 2 -
              0.0001,
        ),
        destination.point,
      ];
    });
  }

  void _showShuttleDetails(Shuttle shuttle) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final percent = (shuttle.currentPassengers / shuttle.capacity) * 100;
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.directions_bus,
                      color: AppColors.secondaryTeal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shuttle.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Status: ${shuttle.status}',
                        style: TextStyle(
                          color: shuttle.status == 'Moving'
                              ? Colors.green
                              : Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Occupancy',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: shuttle.currentPassengers / shuttle.capacity,
                  minHeight: 12,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    percent > 90 ? Colors.red : AppColors.secondaryTeal,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${shuttle.currentPassengers} / ${shuttle.capacity} passengers (${percent.toStringAsFixed(0)}%)',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondaryTeal,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLocationDetails(MapMarkerData data) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Map Hue back to a color for UI (approximate)
    Color color = Colors.blue;
    if (data.hue == MapMarkerData.hueRed) {
      color = Colors.red;
    } else if (data.hue == MapMarkerData.hueGreen) {
      color = Colors.green;
    } else if (data.hue == MapMarkerData.hueOrange) {
      color = Colors.orange;
    } else if (data.hue == MapMarkerData.hueViolet) {
      color = Colors.purple;
    } else if (data.hue == MapMarkerData.hueCyan) {
      color = Colors.cyan;
    }

    setState(() {
      _selectedDestination = data;
      _updateDistanceToSelected();
    });

    _mapController.move(data.point, 18.0);

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
                    colors: [color, color.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
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
                  color: color.withValues(alpha: 0.1),
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
              if (_distanceToDestinationMeters != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Distance: ${_distanceLabel(_distanceToDestinationMeters!)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (data.rooms != null && data.rooms!.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Building Directory',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 90,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: data.rooms!.length,
                    itemBuilder: (context, index) {
                      return Container(
                        width: 130,
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.white10 : Colors.black12,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.meeting_room, size: 18, color: color),
                            const SizedBox(height: 6),
                            Text(
                              data.rooms![index],
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (_routePoints.isEmpty) {
                          _calculateRoute(data);
                        } else {
                          setState(() => _routePoints = []);
                        }
                        Navigator.pop(context);
                      },
                      icon: Icon(
                        _routePoints.isEmpty
                            ? Icons.route_rounded
                            : Icons.layers_clear_rounded,
                      ),
                      label: Text(
                        _routePoints.isEmpty ? 'Show Route' : 'Clear Route',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _launchMaps(data.point.latitude, data.point.longitude);
                      },
                      icon: const Icon(Icons.directions),
                      label: const Text('Directions'),
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
                          : style == MapStyle.hybrid
                          ? Icons.layers
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
              const Divider(),
              SwitchListTile(
                title: const Text('Show Shuttles'),
                secondary: const Icon(
                  Icons.directions_bus_rounded,
                  color: AppColors.secondaryTeal,
                ),
                value: _showShuttles,
                onChanged: (val) {
                  setState(() => _showShuttles = val);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  List<Marker> _buildMarkers(List<AppUser> otherUsers, String? curUid) {
    final List<Marker> markers = [];

    // 1. Campus Markers
    final filteredData = _selectedCategory == LocationCategory.all
        ? _allMarkersData
        : _allMarkersData
              .where((m) => m.category == _selectedCategory)
              .toList();

    for (var data in filteredData) {
      // Filter by Search Query
      if (_searchQuery.isNotEmpty) {
        if (!data.title.toLowerCase().contains(_searchQuery) &&
            !data.category.label.toLowerCase().contains(_searchQuery)) {
          continue;
        }
      }

      Color markerColor = Colors.blue;
      if (data.hue == MapMarkerData.hueRed) {
        markerColor = Colors.red;
      } else if (data.hue == MapMarkerData.hueGreen) {
        markerColor = Colors.green;
      } else if (data.hue == MapMarkerData.hueOrange) {
        markerColor = Colors.orange;
      } else if (data.hue == MapMarkerData.hueViolet) {
        markerColor = Colors.purple;
      } else if (data.hue == MapMarkerData.hueCyan) {
        markerColor = Colors.cyan;
      }

      markers.add(
        Marker(
          point: data.point,
          width: 80,
          height: 80,
          child: GestureDetector(
            onTap: () => _showLocationDetails(data),
            child: Icon(Icons.location_on, color: markerColor, size: 40),
          ),
        ),
      );
    }

    // 2. User Markers
    for (var user in otherUsers) {
      if (user.uid != curUid && user.latitude != null) {
        markers.add(
          Marker(
            point: LatLng(user.latitude!, user.longitude!),
            width: 80,
            height: 80,
            child: const Icon(
              Icons.person_pin_circle,
              color: Colors.purple,
              size: 40,
            ),
          ),
        );
      }
    }

    // 3. Report Markers
    for (var report in _userReports) {
      markers.add(
        Marker(
          point: report.point,
          width: 60,
          height: 60,
          child: GestureDetector(
            onTap: () => _showReportDetails(report),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Icon(
                report.type == 'Security'
                    ? Icons.warning_rounded
                    : report.type == 'Traffic'
                    ? Icons.traffic_rounded
                    : Icons.info_outline,
                color: report.type == 'Security' ? Colors.red : Colors.orange,
                size: 24,
              ),
            ),
          ),
        ),
      );
    }

    // 4. Shuttle Markers
    if (_showShuttles) {
      for (var shuttle in _shuttles) {
        markers.add(
          Marker(
            point: shuttle.position,
            width: 70,
            height: 70,
            child: GestureDetector(
              onTap: () => _showShuttleDetails(shuttle),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryTeal,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.directions_bus_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.secondaryTeal),
                    ),
                    child: Text(
                      '${shuttle.currentPassengers}/${shuttle.capacity}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondaryTeal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return markers;
  }

  List<MapMarkerData> get _nearbyPlaces {
    final filteredData = _selectedCategory == LocationCategory.all
        ? _allMarkersData
        : _allMarkersData
              .where((m) => m.category == _selectedCategory)
              .toList();

    if (_currentPosition == null) {
      return filteredData.take(5).toList();
    }

    final sorted = [...filteredData]
      ..sort((a, b) {
        final da = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          a.point.latitude,
          a.point.longitude,
        );
        final db = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          b.point.latitude,
          b.point.longitude,
        );
        return da.compareTo(db);
      });
    return sorted.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final otherUsers = ref.watch(usersLocationsProvider).value ?? [];
    final currentUid = ref.watch(currentUserIdProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Campus Map',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.layers_outlined),
            onPressed: _showMapStyleSheet,
            tooltip: 'Map Style',
          ),
          const SizedBox(width: 8),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                isDark
                    ? Colors.black.withValues(alpha: 0.8)
                    : Colors.white.withValues(alpha: 0.9),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 16.5,
              onMapReady: () {
                debugPrint('MapScreen: onMapReady successfully');
                if (_currentPosition != null && _followUser) {
                  _mapController.move(_currentPosition!, 17.0);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _currentMapStyle.urlTemplate,
                userAgentPackageName: 'com.pronown.abuad',
                subdomains: const ['a', 'b', 'c'],
              ),
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: const [
                      LatLng(7.6070, 5.3015),
                      LatLng(7.6070, 5.3105),
                      LatLng(7.5980, 5.3105),
                      LatLng(7.5980, 5.3015),
                    ],
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderColor: Colors.blue.withValues(alpha: 0.3),
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
              if (_selectedDestination != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints.isNotEmpty
                          ? _routePoints
                          : (_currentPosition != null
                                ? [
                                    _currentPosition!,
                                    _selectedDestination!.point,
                                  ]
                                : []),
                      color: _routePoints.isNotEmpty
                          ? AppColors.secondaryTeal
                          : AppColors.secondaryTeal.withValues(alpha: 0.5),
                      strokeWidth: 4,
                    ),
                  ],
                ),
              MarkerLayer(markers: _buildMarkers(otherUsers, currentUid)),
            ],
          ),

          // 🔍 New: Search Bar
          Positioned(
            top: 70,
            left: 16,
            right: 16,
            child: SafeArea(
              top: false,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1F2937) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() => _searchQuery = value.toLowerCase());
                  },
                  decoration: InputDecoration(
                    hintText: 'Search campus...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[500],
                      fontSize: 15,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Filters
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: LocationCategory.values.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
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
                                    color: AppColors.primaryInk.withValues(
                                      alpha: 0.4,
                                    ),
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
          ),

          // Location Status
          Positioned(
            top: 148,
            left: 16,
            right: 16,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.55)
                      : Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isTracking ? Icons.gps_fixed : Icons.gps_not_fixed,
                      size: 18,
                      color: _isTracking
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _currentPosition == null
                            ? 'Getting your location...'
                            : 'Live: ${_currentPosition!.latitude.toStringAsFixed(5)}, ${_currentPosition!.longitude.toStringAsFixed(5)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_latestPosition != null)
                      Text(
                        '${((_latestPosition!.speed) * 3.6).clamp(0, 300).toStringAsFixed(0)} km/h',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Nearby Places List (moved down)
          Positioned(
            left: 12,
            right: 12,
            bottom:
                -110 +
                MediaQuery.of(context).padding.bottom, // Closer to Bottom Nav
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
                child: SizedBox(
                  height: 76,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    scrollDirection: Axis.horizontal,
                    itemCount: _nearbyPlaces.length,
                    separatorBuilder: (_, separatorIndex) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) =>
                        _buildPlaceItem(_nearbyPlaces[index], isDark),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFABs(theme, isDark),
    );
  }

  Widget _buildPlaceItem(MapMarkerData place, bool isDark) {
    Color color = Colors.blue;
    if (place.hue == MapMarkerData.hueRed) {
      color = Colors.red;
    } else if (place.hue == MapMarkerData.hueGreen) {
      color = Colors.green;
    } else if (place.hue == MapMarkerData.hueOrange) {
      color = Colors.orange;
    } else if (place.hue == MapMarkerData.hueViolet) {
      color = Colors.purple;
    } else if (place.hue == MapMarkerData.hueCyan) {
      color = Colors.cyan;
    }

    final distance = _currentPosition == null
        ? null
        : Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            place.point.latitude,
            place.point.longitude,
          );
    return InkWell(
      onTap: () => _showLocationDetails(place),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 210,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(place.category.icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    place.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    distance == null
                        ? place.category.label
                        : '${place.category.label} · ${_distanceLabel(distance)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.directions, size: 18),
              onPressed: () =>
                  _launchMaps(place.point.latitude, place.point.longitude),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFABs(ThemeData theme, bool isDark) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: 105.0 + MediaQuery.of(context).padding.bottom,
      ), // Clears List + Bottom Nav
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'map_follow_fab',
            onPressed: _toggleFollowMode,
            backgroundColor: _followUser
                ? const Color(0xFF16A34A)
                : theme.cardTheme.color,
            foregroundColor: _followUser ? Colors.white : theme.iconTheme.color,
            tooltip: _followUser ? 'Following location' : 'Follow my location',
            child: Icon(_followUser ? Icons.gps_fixed : Icons.gps_not_fixed),
          ),
          const SizedBox(height: 10),

          // Zoom buttons
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
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1,
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
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom - 1,
                    );
                  },
                ),
              ],
            ),
          ),
          // Report Issue Button
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: FloatingActionButton.small(
              heroTag: 'map_report_fab',
              onPressed: _showReportDialog,
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: const Icon(Icons.add_alert_rounded, color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),

          // SOS Button
          Container(
            decoration: BoxDecoration(
              color: Colors.red[600],
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: FloatingActionButton.small(
              heroTag: 'map_sos_fab',
              onPressed: () {
                _showToast('SOS Alert Sent! Dispatching Security...');
              },
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: const Icon(Icons.emergency, color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: FloatingActionButton(
              heroTag: 'map_location_fab',
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
    );
  }
}
