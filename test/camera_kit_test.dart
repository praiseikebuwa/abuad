import 'package:flutter_test/flutter_test.dart';
import 'package:abuad/src/features/camera/presentation/camera_screen.dart';
import 'package:abuad/src/features/camera/services/snap_camera_web_bridge.dart';

void main() {
  group('Snapchat Camera Kit Models and Separation Tests', () {
    test('SnapWebLens parses from valid map correctly', () {
      final map = {
        'id': 'lens-1234',
        'name': 'Neon Cyber Halo',
        'iconUrl': 'https://storage.googleapis.com/snap/icon.png',
        'groupId': '4b594445-eaf3-46cd-8626-fae099b74079',
      };

      final lens = SnapWebLens.fromMap(map);
      expect(lens.id, equals('lens-1234'));
      expect(lens.name, equals('Neon Cyber Halo'));
      expect(lens.iconUrl, equals('https://storage.googleapis.com/snap/icon.png'));
      expect(lens.groupId, equals('4b594445-eaf3-46cd-8626-fae099b74079'));

      final effect = CameraLensEffect.fromSnapWebLens(lens);
      expect(effect.isAr, isTrue);
      expect(effect.snapLensId, equals('lens-1234'));
      expect(effect.name, equals('Neon Cyber Halo'));
      expect(effect.iconUrl, equals('https://storage.googleapis.com/snap/icon.png'));
      expect(effect.category, equals('Snapchat AR'));
    });

    test('SnapCaptureResult computes correct MIME type', () {
      const photoResult = SnapCaptureResult(
        success: true,
        dataUrl: 'data:image/jpeg;base64,...',
        isVideo: false,
      );
      expect(photoResult.mimeType, equals('image/jpeg'));

      const videoResult = SnapCaptureResult(
        success: true,
        dataUrl: 'data:video/webm;base64,...',
        isVideo: true,
      );
      expect(videoResult.mimeType, equals('video/webm'));
    });

    test('Non-web platforms safely fall back without breaking via stub', () async {
      // In Dart VM unit test environment (non-web), stub is used
      expect(SnapCameraWebBridge.isSupported, isFalse);

      final initRes = await SnapCameraWebBridge.initSession();
      expect(initRes, isFalse);

      final lenses = await SnapCameraWebBridge.loadLensGroup('test-group');
      expect(lenses, isEmpty);

      final captureRes = await SnapCameraWebBridge.capturePhoto();
      expect(captureRes.success, isFalse);
      expect(captureRes.error, contains('not supported on this platform'));
    });
  });
}
