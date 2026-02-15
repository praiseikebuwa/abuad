import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class HandleService {
  final FirebaseFirestore _firestore;

  HandleService(this._firestore);

  /// Generates a unique handle based on the provided [baseName].
  /// If [baseName] is already taken, appends a 4-digit random number.
  /// If that is also taken, retries with a new number until a unique handle is found.
  Future<String> generateUniqueHandle(String baseName) async {
    // 1. Sanitize baseName (lowercase, remove special chars, trim)
    String handle = baseName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '')
        .trim();

    if (handle.isEmpty) {
      handle = 'user';
    }

    // 2. Check if the sanitized base handle is available
    if (await _isHandleAvailable(handle)) {
      return handle;
    }

    // 3. If taken, append random suffixes until unique
    final random = Random();
    while (true) {
      final suffix = (1000 + random.nextInt(9000)).toString(); // 1000-9999
      final candidateHandle = '$handle$suffix';
      if (await _isHandleAvailable(candidateHandle)) {
        return candidateHandle;
      }
    }
  }

  Future<bool> _isHandleAvailable(String handle) async {
    final snapshot = await _firestore
        .collection('users')
        .where('handle', isEqualTo: handle)
        .limit(1)
        .get();
    return snapshot.docs.isEmpty;
  }
}
