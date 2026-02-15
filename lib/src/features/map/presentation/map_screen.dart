import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../user/data/user_repository.dart';

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
  MapStyle _currentMapStyle = MapStyle.satellite;
  LocationCategory _selectedCategory = LocationCategory.all;
  MapMarkerData? _selectedDestination;
  double? _distanceToDestinationMeters;

  // Define Markers Data
  final List<MapMarkerData> _allMarkersData = [
    MapMarkerData(
      title: 'Senate Building',
      point: const LatLng(7.60250, 5.30610),
      category: LocationCategory.academic,
      color: const Color(0xFF3B82F6),
    ),
    MapMarkerData(
      title: 'Engineering',
      point: const LatLng(7.59950, 5.30910),
      category: LocationCategory.academic,
      color: const Color(0xFF10B981),
    ),
    MapMarkerData(
      title: 'Afe Babalola Hospital',
      point: const LatLng(7.60450, 5.30310),
      category: LocationCategory.health,
      color: const Color(0xFFEF4444),
    ),
    MapMarkerData(
      title: 'Cafeteria 1',
      point: const LatLng(7.59750, 5.30510),
      category: LocationCategory.food,
      color: const Color(0xFFF59E0B),
    ),
    MapMarkerData(
      title: 'Law Library',
      point: const LatLng(7.60100, 5.30760),
      category: LocationCategory.academic,
      color: const Color(0xFF8B5CF6),
    ),
    MapMarkerData(
      title: 'Sports Complex',
      point: const LatLng(7.59850, 5.30360),
      category: LocationCategory.sports,
      color: const Color(0xFF06B6D4),
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
              _mapController.move(
                point,
                math.max(_mapController.camera.zoom, 17.0),
              );
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
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      setState(() {
        _latestPosition = position;
        _currentPosition = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });
      _updateDistanceToSelected();
      _mapController.move(
        _currentPosition!,
        math.max(_mapController.camera.zoom, 17.0),
      );
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

  void _toggleFollowMode() {
    setState(() => _followUser = !_followUser);
    if (_followUser && _currentPosition != null) {
      _mapController.move(
        _currentPosition!,
        math.max(_mapController.camera.zoom, 17.0),
      );
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

  void _showLocationDetails(MapMarkerData data) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = data.color ?? theme.primaryColor;
    setState(() {
      _selectedDestination = data;
      _updateDistanceToSelected();
    });
    _mapController.move(data.point, math.max(_mapController.camera.zoom, 17.0));

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
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.route),
                      label: const Text('Preview'),
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
        height: 110,
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
                      color: color.withValues(alpha: 0.5),
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
                      colors: [color, color.withValues(alpha: 0.8)],
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
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Text(
                  data.title,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  // Markers for other users (Snap Map Style)
  List<Marker> _buildUserMarkers(List<AppUser> users, {String? curUid}) {
    return users.where((u) => u.uid != curUid && u.latitude != null).map((
      user,
    ) {
      return Marker(
        point: LatLng(user.latitude!, user.longitude!),
        width: 60,
        height: 60,
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 20,
                backgroundImage: user.avatarUrl != null
                    ? NetworkImage(user.avatarUrl!)
                    : null,
                child: user.avatarUrl == null
                    ? Text(user.displayName[0].toUpperCase())
                    : null,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                user.displayName.split(' ')[0],
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
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
                    ? Colors.black.withValues(alpha: 0.8)
                    : Colors.white.withValues(alpha: 0.9),
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
                flags: InteractiveFlag.all, // Enable all including rotate
              ),
              onPositionChanged: (_, hasGesture) {
                if (hasGesture && _followUser) {
                  setState(() => _followUser = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _currentMapStyle.urlTemplate,
                userAgentPackageName: 'com.example.abuad',
                subdomains: const ['a', 'b', 'c'],
              ),
              if (_currentPosition != null && _selectedDestination != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [_currentPosition!, _selectedDestination!.point],
                      strokeWidth: 4,
                      color: AppColors.secondaryTeal.withValues(alpha: 0.9),
                      borderStrokeWidth: 1.5,
                      borderColor: _isTracking
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              // Campus Zone Polygon
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: [
                      LatLng(7.6070, 5.3015),
                      LatLng(7.6070, 5.3105),
                      LatLng(7.5980, 5.3105),
                      LatLng(7.5980, 5.3015),
                    ],
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderStrokeWidth: 2,
                    borderColor: Colors.blue.withValues(alpha: 0.3),
                    label: "ABUAD Campus",
                    labelStyle: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              MarkerLayer(
                markers: [
                  ..._markers,
                  ..._buildUserMarkers(
                    otherUsers,
                    curUid: ref.watch(currentUserIdProvider),
                  ),
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
                              color: AppColors.info.withValues(alpha: 0.2),
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
                                    color: Colors.blue.withValues(alpha: 0.5),
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
                    itemBuilder: (context, index) {
                      final place = _nearbyPlaces[index];
                      final color = place.color ?? theme.colorScheme.primary;
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
                            color: isDark
                                ? Colors.white10
                                : const Color(0xFFF7F7F7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: color.withValues(alpha: 0.3),
                            ),
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
                                child: Icon(
                                  place.category.icon,
                                  color: color,
                                  size: 18,
                                ),
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
                                        color: isDark
                                            ? Colors.grey[300]
                                            : Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.directions, size: 18),
                                onPressed: () => _launchMaps(
                                  place.point.latitude,
                                  place.point.longitude,
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
          ),
        ],
      ),
      floatingActionButton: Padding(
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
              foregroundColor: _followUser
                  ? Colors.white
                  : theme.iconTheme.color,
              tooltip: _followUser
                  ? 'Following location'
                  : 'Follow my location',
              child: Icon(_followUser ? Icons.gps_fixed : Icons.gps_not_fixed),
            ),
            const SizedBox(height: 10),
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
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
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
      ),
    );
  }
}
