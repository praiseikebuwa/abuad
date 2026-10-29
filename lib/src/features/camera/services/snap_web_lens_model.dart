import 'dart:typed_data';

class SnapWebLens {
  final String id;
  final String name;
  final String iconUrl;
  final String groupId;

  const SnapWebLens({
    required this.id,
    required this.name,
    required this.iconUrl,
    required this.groupId,
  });

  factory SnapWebLens.fromMap(Map<String, dynamic> map) {
    return SnapWebLens(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Snap Lens',
      iconUrl: map['iconUrl']?.toString() ?? '',
      groupId: map['groupId']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'iconUrl': iconUrl,
      'groupId': groupId,
    };
  }
}

class SnapCaptureResult {
  final bool success;
  final String? dataUrl;
  final Uint8List? bytes;
  final String? error;
  final bool isVideo;

  const SnapCaptureResult({
    required this.success,
    this.dataUrl,
    this.bytes,
    this.error,
    this.isVideo = false,
  });

  String get mimeType => isVideo ? 'video/webm' : 'image/jpeg';
}
