import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload an image to Firebase Storage
  /// Returns the public URL
  Future<String> uploadImage(XFile file, {String? path}) async {
    try {
      debugPrint('📤 Uploading file to Firebase Storage: ${file.name}');

      final fileExt = file.name.split('.').last;
      String filePath;

      if (path != null) {
        if (path.endsWith('/')) {
          final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
          filePath = '$path$fileName';
        } else {
          filePath = path;
        }
      } else {
        // Default/Fallback (Likely unauthorized)
        final fileName = '${DateTime.now().toIso8601String()}.$fileExt';
        filePath = 'uploads/$fileName';
      }

      final storageRef = _storage.ref().child(filePath);

      TaskSnapshot snapshot;
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'picked_file_path': file.path},
      );

      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        snapshot = await storageRef.putData(bytes, metadata);
      } else {
        snapshot = await storageRef.putFile(File(file.path), metadata);
      }

      final publicUrl = await snapshot.ref.getDownloadURL();

      debugPrint('✅ Upload successful: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('❌ Firebase Storage Upload Error: $e');
      rethrow;
    }
  }

  /// Upload raw image bytes to Firebase Storage
  Future<String> uploadImageBytes(Uint8List bytes, String path) async {
    try {
      debugPrint('📤 Uploading image bytes to Firebase Storage...');

      String filePath;
      if (path.endsWith('/')) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        filePath = '$path$fileName';
      } else {
        filePath = path;
      }

      final storageRef = _storage.ref().child(filePath);
      final snapshot = await storageRef.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final publicUrl = await snapshot.ref.getDownloadURL();

      debugPrint('✅ Upload successful: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('❌ Firebase Storage Byte Upload Error: $e');
      rethrow;
    }
  }

  // ... (previous code)

  /// Upload a video to Firebase Storage
  /// Returns the public URL
  Future<String> uploadVideo(XFile file, {String? path}) async {
    // ... (existing implementation)
    try {
      debugPrint('📤 Uploading video to Firebase Storage: ${file.name}');

      final fileExt = file.name.split('.').last;
      String filePath;

      if (path != null) {
        if (path.endsWith('/')) {
          final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
          filePath = '$path$fileName';
        } else {
          filePath = path;
        }
      } else {
        final fileName = '${DateTime.now().toIso8601String()}.$fileExt';
        filePath = 'videos/$fileName';
      }

      final storageRef = _storage.ref().child(filePath);

      TaskSnapshot snapshot;
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        snapshot = await storageRef.putData(
          bytes,
          SettableMetadata(contentType: 'video/$fileExt'),
        );
      } else {
        snapshot = await storageRef.putFile(
          File(file.path),
          SettableMetadata(contentType: 'video/$fileExt'),
        );
      }

      final publicUrl = await snapshot.ref.getDownloadURL();

      debugPrint('✅ Video Upload successful: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('❌ Firebase Storage Video Upload Error: $e');
      rethrow;
    }
  }

  /// Upload audio to Firebase Storage
  Future<String> uploadAudio(XFile file, {String? path}) async {
    try {
      debugPrint('📤 Uploading audio to Firebase Storage: ${file.name}');

      final fileExt = file.name.split('.').last;
      String filePath;

      if (path != null) {
        if (path.endsWith('/')) {
          final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
          filePath = '$path$fileName';
        } else {
          filePath = path;
        }
      } else {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        filePath = 'audio/$fileName';
      }

      final storageRef = _storage.ref().child(filePath);

      // Determine content type
      String contentType = 'audio/mpeg'; // Default
      if (fileExt == 'm4a') contentType = 'audio/mp4';
      if (fileExt == 'mp3') contentType = 'audio/mpeg';
      if (fileExt == 'wav') contentType = 'audio/wav';
      if (fileExt == 'aac') contentType = 'audio/aac';

      TaskSnapshot snapshot;
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        snapshot = await storageRef.putData(
          bytes,
          SettableMetadata(contentType: contentType),
        );
      } else {
        snapshot = await storageRef.putFile(
          File(file.path),
          SettableMetadata(contentType: contentType),
        );
      }

      final publicUrl = await snapshot.ref.getDownloadURL();

      debugPrint('✅ Audio Upload successful: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('❌ Firebase Storage Audio Upload Error: $e');
      rethrow;
    }
  }
}
