import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SOSAlert {
  final String id;
  final String userId;
  final String userName;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String status; // active, resolved

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
      'timestamp': FieldValue.serverTimestamp(),
      'status': status,
    };
  }
}

class SOSRepository {
  final FirebaseFirestore _firestore;

  SOSRepository(this._firestore);

  Future<void> sendSOS({
    required String userId,
    required String userName,
    required double lat,
    required double lng,
  }) async {
    final docRef = _firestore.collection('sos_alerts').doc();
    final alert = SOSAlert(
      id: docRef.id,
      userId: userId,
      userName: userName,
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
    );
    await docRef.set(alert.toMap());
  }
}

final sosRepositoryProvider = Provider<SOSRepository>((ref) {
  return SOSRepository(FirebaseFirestore.instance);
});
