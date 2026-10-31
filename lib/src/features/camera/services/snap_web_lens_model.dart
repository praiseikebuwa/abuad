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

class SnapInitResult {
  final bool success;
  final int stage;
  final String stageName;
  final String? error;
  final int lensCount;
  final int elapsedMs;
  final bool alreadyInitialized;

  const SnapInitResult({
    required this.success,
    this.stage = 0,
    this.stageName = 'Unknown',
    this.error,
    this.lensCount = 0,
    this.elapsedMs = 0,
    this.alreadyInitialized = false,
  });

  factory SnapInitResult.fromMap(Map<String, dynamic> map) {
    return SnapInitResult(
      success: map['success'] == true,
      stage: (map['stage'] as num?)?.toInt() ?? 0,
      stageName: map['stageName']?.toString() ?? '',
      error: map['error']?.toString(),
      lensCount: (map['lensCount'] as num?)?.toInt() ?? 0,
      elapsedMs: (map['elapsedMs'] as num?)?.toInt() ?? 0,
      alreadyInitialized: map['alreadyInitialized'] == true,
    );
  }

  factory SnapInitResult.failure(String error, {int stage = 0, String stageName = 'Initialization'}) {
    return SnapInitResult(
      success: false,
      stage: stage,
      stageName: stageName,
      error: error,
    );
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
