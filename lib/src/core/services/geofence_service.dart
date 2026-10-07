import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final geofenceServiceProvider = Provider((ref) => GeofenceService());

class GeofenceService {
  /// Set to true during testing mode to bypass campus geofence restrictions
  static const bool bypassGeofenceForTesting = true;

  // ABUAD Campus (Approx. Central Coordinates)
  static const double abuadLat = 7.6033;
  static const double abuadLng = 5.3047;
  static const double validRadiusMeters = 2000.0; // 2km radius

  /// Checks if the user is currently within the ABUAD campus geofence.
  Future<bool> isWithinABUAD() async {
    if (bypassGeofenceForTesting) {
      return true;
    }

    try {
      final position = await _getCurrentPosition();

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        abuadLat,
        abuadLng,
      );

      return distance <= validRadiusMeters;
    } catch (e) {
      return true; // Fail-open during testing if location permissions/services fail
    }
  }

  /// Handles location permission and returns current position.
  Future<Position> _getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'Location services are disabled.';
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Location permissions are denied.';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw 'Location permissions are permanently denied.';
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }
}
