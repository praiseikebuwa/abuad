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

  /// Upload a document (PDF, Word, PPT, Excel, TXT, etc.)
  Future<String> uploadDocument(Uint8List bytes, String fileName) async {
    final contentType = _mimeFromExtension(fileName) ?? 'application/octet-stream';
    return _uploadBytes(bytes, fileName, contentType);
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
    String fileName = file.name;
    if (fileName.isEmpty || !fileName.contains('.')) {
      fileName = 'upload_${DateTime.now().millisecondsSinceEpoch}.jpg';
    }
    final contentType = _mimeFromExtension(fileName) ?? 'image/jpeg';
    final url = await ApiClient.uploadBytes(bytes, fileName, contentType: contentType);
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
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'ppt': 'application/vnd.ms-powerpoint',
      'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'xls': 'application/vnd.ms-excel',
      'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'txt': 'text/plain',
    };
    return map[ext];
  }
}
