import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class SupabaseStorageService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Upload an image to Supabase Storage
  Future<String> uploadImage(XFile image) async {
    return _uploadFile(image, 'images');
  }

  /// Upload a video to Supabase Storage
  Future<String> uploadVideo(XFile video) async {
    return _uploadFile(video, 'videos');
  }

  Future<String> _uploadFile(XFile file, String folder) async {
    try {
      debugPrint('📤 Uploading file to Supabase: ${file.name}');

      final bytes = await file.readAsBytes();
      // Sanitize filename to avoid issues with special characters
      final sanitizedFileName = file.name.replaceAll(
        RegExp(r'[^a-zA-Z0-9\._-]'),
        '',
      );
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_$sanitizedFileName';
      final filePath = '$folder/$fileName';

      // Upload the file
      await _supabase.storage
          .from(SupabaseConfig.bucketName)
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(contentType: file.mimeType, upsert: true),
          );

      // Get the public URL
      final publicUrl = _supabase.storage
          .from(SupabaseConfig.bucketName)
          .getPublicUrl(filePath);

      debugPrint('✅ Upload successful: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('❌ Supabase Upload Error: $e');
      rethrow;
    }
  }
}
