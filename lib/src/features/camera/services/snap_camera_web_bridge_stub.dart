import 'package:flutter/widgets.dart';
import 'snap_web_lens_model.dart';

class SnapCameraWebBridge {
  static const bool isSupported = false;
  static const String viewType = 'snap-camerakit-view';

  static String? lastError;
  static int lastStage = 0;
  static String lastStageName = 'Not supported';

  static List<Map<String, dynamic>> getDiagnosticLogs() => const [];

  static Future<bool> initSession({String? apiToken, String? lensGroupId}) async {
    lastError = 'SnapCameraWebBridge is not supported on this platform.';
    return false;
  }

  static Future<SnapInitResult> initSessionDetailed({String? apiToken, String? lensGroupId}) async {
    return const SnapInitResult(
      success: false,
      stage: 0,
      stageName: 'Not supported',
      error: 'SnapCameraWebBridge is not supported on this platform.',
    );
  }

  static Widget buildPreviewWidget() {
    return const SizedBox.shrink();
  }

  static Future<List<SnapWebLens>> loadLensGroup(String groupId, {String? apiToken}) async {
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
