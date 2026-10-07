import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'api_client.dart';

/// CloudStorageService — uploads files to Cloudflare R2 via the ABUAD backend.
/// Replaces FirebaseStorageService entirely. No Firebase dependency.
class CloudStorageService {
  static const String _placeholder = 'https://placehold.co/600x400';

  /// Upload an image XFile.
  Future<String> uploadImage(XFile file, {String? path}) async {
    return _uploadXFile(file);
  }

  /// Upload raw image bytes.
  Future<String> uploadImageBytes(Uint8List bytes, String fileName) async {
    return _uploadBytes(bytes, fileName, 'image/jpeg');
  }

  /// Upload a video XFile.
  Future<String> uploadVideo(XFile file, {String? path}) async {
    return _uploadXFile(file);
  }

  /// Upload an audio XFile.
  Future<String> uploadAudio(XFile file, {String? path}) async {
    return _uploadXFile(file);
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<String> _uploadXFile(XFile file) async {
    final bytes = await file.readAsBytes();
    final contentType = _mimeFromExtension(file.name) ?? 'image/jpeg';
    final url = await ApiClient.uploadBytes(bytes, file.name, contentType: contentType);
    if (url == null || url.isEmpty || url == _placeholder) {
      throw Exception('Failed to upload file to Cloudflare R2 storage');
    }
    return url;
  }

  Future<String> _uploadBytes(Uint8List bytes, String fileName, String contentType) async {
    final url = await ApiClient.uploadBytes(bytes, fileName, contentType: contentType);
    if (url == null || url.isEmpty || url == _placeholder) {
      throw Exception('Failed to upload bytes to Cloudflare R2 storage');
    }
    return url;
  }

  static String? _mimeFromExtension(String name) {
    final ext = name.split('.').last.toLowerCase();
    const map = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      'mp3': 'audio/mpeg',
      'aac': 'audio/aac',
      'wav': 'audio/wav',
    };
    return map[ext];
  }
}
