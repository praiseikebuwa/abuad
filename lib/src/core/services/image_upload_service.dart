import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cloud_storage_service.dart';

final imageUploadServiceProvider = Provider<ImageUploadService>((ref) {
  return ImageUploadService();
});

/// Service for picking and uploading media files to Cloudflare R2
/// via the ABUAD backend (replacing Firebase Storage).
class ImageUploadService {
  final CloudStorageService _storageService = CloudStorageService();

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

  /// Upload image to Cloudflare R2 and return URL with dimensions
  Future<ImageUploadResult> uploadImage(XFile imageFile, {String? path}) async {
    try {
      final url = await _storageService.uploadImage(imageFile, path: path);
      return ImageUploadResult(url: url, width: 800, height: 600);
    } catch (e) {
      debugPrint('Image upload error: $e');
      rethrow;
    }
  }

  /// Upload audio to Cloudflare R2
  Future<ImageUploadResult> uploadAudio(XFile audioFile, {String? path}) async {
    try {
      final url = await _storageService.uploadAudio(audioFile, path: path);
      return ImageUploadResult(url: url, width: 0, height: 0);
    } catch (e) {
      debugPrint('Audio upload error: $e');
      rethrow;
    }
  }

  /// Upload video to Cloudflare R2
  Future<ImageUploadResult> uploadVideo(XFile videoFile, {String? path}) async {
    try {
      final url = await _storageService.uploadVideo(videoFile, path: path);
      return ImageUploadResult(url: url, width: 1280, height: 720);
    } catch (e) {
      debugPrint('Video upload error: $e');
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
