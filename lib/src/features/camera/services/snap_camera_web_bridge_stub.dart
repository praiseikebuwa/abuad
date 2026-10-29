import 'package:flutter/widgets.dart';
import 'snap_web_lens_model.dart';

class SnapCameraWebBridge {
  static const bool isSupported = false;
  static const String viewType = 'snap-camerakit-view';

  static Future<bool> initSession({String? apiToken, String? lensGroupId}) async {
    return false;
  }

  static Widget buildPreviewWidget() {
    return const SizedBox.shrink();
  }

  static Future<List<SnapWebLens>> loadLensGroup(String groupId) async {
    return const [];
  }

  static List<SnapWebLens> getLoadedLenses() {
    return const [];
  }

  static Future<bool> applyLens(String lensId) async {
    return false;
  }

  static Future<bool> removeLens() async {
    return false;
  }

  static Future<SnapCaptureResult> capturePhoto() async {
    return const SnapCaptureResult(
      success: false,
      error: 'SnapCameraWebBridge is not supported on this platform.',
    );
  }

  static Future<bool> startRecording() async {
    return false;
  }

  static Future<SnapCaptureResult> stopRecording() async {
    return const SnapCaptureResult(
      success: false,
      error: 'SnapCameraWebBridge is not supported on this platform.',
      isVideo: true,
    );
  }

  static Future<bool> switchCamera() async {
    return false;
  }

  static void dispose() {}
}
