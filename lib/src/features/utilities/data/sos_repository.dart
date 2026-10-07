import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_client.dart';

class SOSAlert {
  final String id;
  final String userId;
  final String userName;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String status;

  SOSAlert({
    required this.id,
    required this.userId,
    required this.userName,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.status = 'active',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
    };
  }
}

class SOSRepository {
  SOSRepository([dynamic _]);

  Future<void> sendSOS({
    required String userId,
    required String userName,
    required double lat,
    required double lng,
  }) async {
    await ApiClient.post('/utilities/sos', {
      'latitude': lat,
      'longitude': lng,
      'message': 'EMERGENCY SOS ALERT from $userName',
    });
  }
}

final sosRepositoryProvider = Provider<SOSRepository>((ref) {
  return SOSRepository();
});
