import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_storage_service.dart';

final imageUploadServiceProvider = Provider<ImageUploadService>((ref) {
  return ImageUploadService();
});

class ImageUploadService {
  final FirebaseStorageService _storageService = FirebaseStorageService();

  ImageUploadService();

  /// Pick an image from gallery or camera
  Future<XFile?> pickImage({ImageSource source = ImageSource.gallery}) async {
    final picker = ImagePicker();
    return await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
  }

  /// Upload image to Firebase Storage and return URL with dimensions
  Future<ImageUploadResult> uploadImage(XFile imageFile, {String? path}) async {
    try {
      // Upload to Firebase Storage
      final url = await _storageService.uploadImage(imageFile, path: path);

      // Firebase Storage doesn't return dimensions.
      // We return default dimensions or could decode image to get them if needed.
      return ImageUploadResult(url: url, width: 800, height: 600);
    } catch (e) {
      debugPrint('Image upload error: $e');
      rethrow;
    }
  }

  /// Upload audio to Firebase Storage
  Future<ImageUploadResult> uploadAudio(XFile audioFile, {String? path}) async {
    try {
      final url = await _storageService.uploadAudio(audioFile, path: path);
      // Audio doesn't have width/height, return defaults or 0
      return ImageUploadResult(url: url, width: 0, height: 0);
    } catch (e) {
      debugPrint('Audio upload error: $e');
      rethrow;
    }
  }
}

class ImageUploadResult {
  final String url;
  final double width;
  final double height;

  ImageUploadResult({
    required this.url,
    required this.width,
    required this.height,
  });
}
