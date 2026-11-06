import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/campus_landmark.dart';
import 'widgets/ai_campus_navigator_sheet.dart';
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
  bool _isLoadingLocation = false;
  bool _isTracking = false;
  bool _followUser = true;
  MapStyle _currentMapStyle = MapStyle.normal;
  CampusLandmark? _selectedLandmark;

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
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
      ),
    ).listen(
      (position) {
        if (!mounted) return;
        final point = LatLng(position.latitude, position.longitude);
        setState(() {
          _currentPosition = point;
          _isTracking = true;
        });

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
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 8));

      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _isLoadingLocation = false;
        });

        if (_currentPosition != null) {
          _mapController.move(_currentPosition!, 17.0);
        }
      }
    } catch (e) {
      if (mounted) {
        _showToast("Error getting location: $e");
        setState(() => _isLoadingLocation = false);
      }
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
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Map Style',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: MapStyle.values.map((style) {
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
                            ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                          ),
                        ),
                        onTap: () {
                          setState(() => _currentMapStyle = style);
                          Navigator.pop(context);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  List<Marker> _buildMarkers(List<AppUser> otherUsers, String? curUid) {
    final List<Marker> markers = [];

    // 1. Current User Marker
    if (_currentPosition != null) {
      markers.add(
        Marker(
          point: _currentPosition!,
          width: 60,
          height: 60,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.secondaryTeal.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.secondaryTeal, width: 2),
            ),
            child: const Center(
              child: Icon(Icons.my_location, color: AppColors.secondaryTeal, size: 24),
            ),
          ),
        ),
      );
    }

    // 2. Friend/Following Markers
    for (var user in otherUsers) {
      if (user.uid != curUid && user.latitude != null && user.longitude != null) {
        markers.add(
          Marker(
            point: LatLng(user.latitude!, user.longitude!),
            width: 50,
            height: 50,
            child: GestureDetector(
              onTap: () => _showToast('${user.displayName} is here'),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.purple, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: user.avatarUrl != null
                      ? Image.network(user.avatarUrl!, fit: BoxFit.cover)
                      : const Icon(Icons.person, color: Colors.purple, size: 30),
                ),
              ),
            ),
          ),
        );
      }
    }

    // Add ABUAD Campus Landmark Pins
    for (final landmark in CampusLandmark.all) {
      final isSelected = _selectedLandmark?.id == landmark.id;
      markers.add(
        Marker(
          point: landmark.position,
          width: isSelected ? 44 : 36,
          height: isSelected ? 44 : 36,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _selectedLandmark = landmark);
              _mapController.move(landmark.position, 17.5);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: landmark.category.color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.yellowAccent : Colors.white,
                  width: isSelected ? 2.5 : 1.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                landmark.category.icon,
                size: isSelected ? 20 : 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final otherUsers = ref.watch(usersLocationsProvider).value ?? [];
    final currentUid = ref.watch(currentUserIdProvider);

    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    context.go('/');
                  }
                },
              )
            : null,
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
                if (_currentPosition != null && _followUser) {
                  _mapController.move(_currentPosition!, 17.0);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _currentMapStyle.urlTemplate,
                userAgentPackageName: 'com.pronown.abuad',
              ),
              MarkerLayer(markers: _buildMarkers(otherUsers, currentUid)),
            ],
          ),

          if (_selectedLandmark != null) _buildLandmarkDetailCard(theme, isDark),
          _buildFABs(theme, isDark),
          _buildAiNavigatorFab(theme, isDark),
        ],
      ),
    );
  }

  Widget _buildFABs(ThemeData theme, bool isDark) {
    return Positioned(
      right: 16,
      bottom: 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Follow Me Toggle
          FloatingActionButton.small(
            heroTag: 'map_follow_fab',
            onPressed: _toggleFollowMode,
            backgroundColor: _followUser ? AppColors.secondaryTeal : theme.cardTheme.color,
            foregroundColor: _followUser ? Colors.white : theme.iconTheme.color,
            tooltip: 'Follow location',
            child: Icon(_followUser ? Icons.gps_fixed : Icons.gps_not_fixed),
          ),
          const SizedBox(height: 12),

          // Zoom Controls
          Container(
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                ),
              ],
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black12,
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
                  color: isDark ? Colors.white10 : Colors.black12,
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
          const SizedBox(height: 12),

          // My Location Button
          FloatingActionButton(
            heroTag: 'map_location_fab',
            onPressed: _getCurrentLocation,
            backgroundColor: AppColors.accentGold,
            foregroundColor: Colors.white,
            child: _isLoadingLocation
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }

  Widget _buildAiNavigatorFab(ThemeData theme, bool isDark) {
    return Positioned(
      left: 16,
      bottom: 24,
      child: FloatingActionButton.extended(
        heroTag: 'map_ai_navigator_fab',
        onPressed: () {
          HapticFeedback.mediumImpact();
          AiCampusNavigatorSheet.show(
            context: context,
            userPosition: _currentPosition,
            onSelectLandmark: (landmark) {
              setState(() => _selectedLandmark = landmark);
              _mapController.move(landmark.position, 17.5);
            },
          );
        },
        icon: const Icon(
          Icons.auto_awesome_rounded,
          color: Colors.white,
          size: 18,
        ),
        label: const Text(
          'AI Navigator',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
        ),
        backgroundColor: const Color(0xFF6366F1),
        elevation: 4,
      ),
    );
  }

  Widget _buildLandmarkDetailCard(ThemeData theme, bool isDark) {
    if (_selectedLandmark == null) return const SizedBox.shrink();
    final landmark = _selectedLandmark!;

    double distance = 0;
    if (_currentPosition != null) {
      distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        landmark.position.latitude,
        landmark.position.longitude,
      );
    }
    final minutes = distance > 0 ? (distance / 80).ceil() : 0;
    final walkText = distance > 0
        ? '$minutes min walk (${distance.toStringAsFixed(0)}m)'
        : 'At campus core';

    return Positioned(
      left: 16,
      right: 16,
      bottom: 84,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18181B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: landmark.category.color.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: landmark.category.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    landmark.category.icon,
                    size: 20,
                    color: landmark.category.color,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        landmark.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${landmark.category.label} • $walkText',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryTeal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _selectedLandmark = null),
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF27272A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 14,
                    color: Color(0xFF6366F1),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      landmark.aiGuideTip,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: landmark.category.color.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    icon: Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 15,
                      color: landmark.category.color,
                    ),
                    label: Text(
                      'Ask AI Guide',
                      style: TextStyle(
                        color: landmark.category.color,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () {
                      context.push('/ai');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: landmark.category.color,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 0,
                    ),
                    icon: const Icon(
                      Icons.center_focus_strong_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Center Pin',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      _mapController.move(landmark.position, 18.0);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}
