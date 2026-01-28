import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'supabase_storage_service.dart';

final imageUploadServiceProvider = Provider<ImageUploadService>((ref) {
  return ImageUploadService();
});

class ImageUploadService {
  final SupabaseStorageService _storageService = SupabaseStorageService();

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

  /// Upload image to Supabase and return URL with dimensions
  Future<ImageUploadResult> uploadImage(XFile imageFile) async {
    try {
      // Upload to Supabase Storage
      final url = await _storageService.uploadImage(imageFile);

      // Supabase Storage doesn't return dimensions.
      // We return default dimensions or could decode image to get them if needed.
      return ImageUploadResult(url: url, width: 800, height: 600);
    } catch (e) {
      debugPrint('Image upload error: $e');
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
