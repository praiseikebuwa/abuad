import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class SupabaseStorageService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Upload an image to Supabase Storage
  /// Returns the public URL
  Future<String> uploadImage(XFile file) async {
    try {
      debugPrint('📤 Uploading file to Supabase Storage: ${file.name}');

      final bytes = await file.readAsBytes();
      final fileExt = file.name.split('.').last;
      final fileName = '${DateTime.now().toIso8601String()}.$fileExt';
      final filePath = fileName; // Relative path in bucket

      await _supabase.storage
          .from('adui')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$fileExt'),
          );

      final publicUrl = _supabase.storage.from('adui').getPublicUrl(filePath);

      debugPrint('✅ Upload successful: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('❌ Supabase Storage Upload Error: $e');
      rethrow;
    }
  }

  /// Upload raw image bytes to Supabase Storage
  Future<String> uploadImageBytes(Uint8List bytes, String path) async {
    try {
      debugPrint('📤 Uploading image bytes to Supabase Storage...');

      // Use a consistent naming strategy or user provided path
      // If path ends in / treat it as a directory, else a full path
      String filePath;
      if (path.endsWith('/')) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        filePath = '$path$fileName';
      } else {
        filePath = path;
      }

      await _supabase.storage
          .from('adui')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      final publicUrl = _supabase.storage.from('adui').getPublicUrl(filePath);

      debugPrint('✅ Upload successful: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('❌ Supabase Storage Byte Upload Error: $e');
      rethrow;
    }
  }

  /// Upload a video to Supabase Storage
  /// Returns the public URL
  Future<String> uploadVideo(XFile file) async {
    try {
      debugPrint('📤 Uploading video to Supabase Storage: ${file.name}');

      final bytes = await file.readAsBytes();
      final fileExt = file.name.split('.').last;
      final fileName = '${DateTime.now().toIso8601String()}.$fileExt';
      final filePath = fileName; // Relative path in bucket

      await _supabase.storage
          .from('adui')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(contentType: 'video/$fileExt'),
          );

      final publicUrl = _supabase.storage.from('adui').getPublicUrl(filePath);

      debugPrint('✅ Video Upload successful: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('❌ Supabase Storage Video Upload Error: $e');
      rethrow;
    }
  }
}
