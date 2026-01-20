import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final cloudinaryServiceProvider = Provider<CloudinaryService>((ref) {
  // TODO: Replace with user credentials or load from ENV
  return CloudinaryService(cloudName: 'demo', uploadPreset: 'ml_default');
});

class CloudinaryService {
  final CloudinaryPublic _cloudinary;

  CloudinaryService({required String cloudName, required String uploadPreset})
    : _cloudinary = CloudinaryPublic(cloudName, uploadPreset, cache: false);

  Future<String?> uploadImage(String filePath) async {
    try {
      CloudinaryResponse response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          filePath,
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      return response.secureUrl;
    } catch (e) {
      // debugPrint('Cloudinary Upload Error: $e');
      return null;
    }
  }

  Future<String?> uploadVideo(String filePath) async {
    try {
      CloudinaryResponse response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          filePath,
          resourceType: CloudinaryResourceType.Video,
        ),
      );
      return response.secureUrl;
    } catch (e) {
      return null;
    }
  }
}
