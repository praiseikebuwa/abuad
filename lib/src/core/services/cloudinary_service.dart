import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class CloudinaryService {
  final CloudinaryPublic cloudinary = CloudinaryPublic(
    'abuad-nest', // Placeholder: You should normally use env vars or remote config
    'abuad_preset',
    cache: false,
  );

  Future<String> uploadImage(XFile image) async {
    try {
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromByteData(
          await image.readAsBytes().then(
            (bytes) => ByteData.view(bytes.buffer),
          ),
          identifier: image.name,
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      return response.secureUrl;
    } catch (e) {
      debugPrint('Cloudinary Error: $e');
      return ''; // Handle error gracefully
    }
  }
}
