// snap_camera_web_bridge_web.dart
// Web-specific implementation of the Snapchat Camera Kit bridge.

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'snap_web_lens_model.dart';

class SnapCameraWebBridge {
  static const bool isSupported = true;
  static const String viewType = 'snap-camerakit-view';
  static bool _viewRegistered = false;

  static String? lastError;
  static int lastStage = 0;
  static String lastStageName = 'Not Started';

  static JSObject? get _bridge {
    try {
      if (globalContext.has('SnapCameraBridge')) {
        return globalContext.getProperty('SnapCameraBridge'.toJS) as JSObject?;
      }
    } catch (e) {
      debugPrint('[SnapCameraBridge:Web] Error accessing SnapCameraBridge: $e');
    }
    return null;
  }

  static void _ensureViewRegistered() {
    if (_viewRegistered) return;
    _viewRegistered = true;
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) {
        final bridge = _bridge;
        if (bridge != null) {
          try {
            if (bridge.has('attachLiveCanvas')) {
              bridge.callMethod('attachLiveCanvas'.toJS);
            }
            if (bridge.has('getOrCreateContainer')) {
              final container = bridge.callMethod('getOrCreateContainer'.toJS) as web.HTMLElement?;
              if (container != null) {
                return container;
              }
            }
          } catch (e) {
            debugPrint('[SnapCameraBridge:Web] Error getting bridge container: $e');
          }
        }
        final fallback = web.document.createElement('div') as web.HTMLDivElement;
        fallback.id = 'snap-camerakit-fallback-$viewId';
        fallback.style.width = '100%';
        fallback.style.height = '100%';
        fallback.style.backgroundColor = '#000000';
        return fallback;
      },
    );
  }

  static Widget buildPreviewWidget() {
    _ensureViewRegistered();
    final bridge = _bridge;
    if (bridge != null && bridge.has('attachLiveCanvas')) {
      try {
        bridge.callMethod('attachLiveCanvas'.toJS);
      } catch (_) {}
    }
    return const HtmlElementView(viewType: viewType);
  }

  static List<Map<String, dynamic>> getDiagnosticLogs() {
    final bridge = _bridge;
    if (bridge == null) return const [];
    try {
      if (bridge.has('getDiagnosticLogsJson')) {
        final resJS = bridge.callMethod('getDiagnosticLogsJson'.toJS) as JSString?;
        final resStr = resJS?.toDart;
        if (resStr != null) {
          final decoded = jsonDecode(resStr);
          if (decoded is List) {
            return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        }
      }
    } catch (e) {
      debugPrint('[SnapCameraBridge:Web] Error reading diagnostic logs: $e');
    }
    return const [];
  }

  static Future<SnapInitResult> initSessionDetailed({String? apiToken, String? lensGroupId}) async {
    _ensureViewRegistered();
    final bridge = _bridge;
    if (bridge == null) {
      const err = 'SnapCameraBridge not available on window. Ensure snap_camerakit_bridge.js loaded.';
      lastError = err;
      lastStage = 2;
      lastStageName = 'The web bridge is available';
      debugPrint('[SnapCameraKit:Diag] [Stage 2/17: The web bridge is available] status: FAILURE - $err');
      return SnapInitResult.failure(err, stage: 2, stageName: lastStageName);
    }

    try {
      final tokenJS = (apiToken ?? '').toJS;
      final groupJS = (lensGroupId ?? '').toJS;
      final promise = bridge.callMethod(
        'initSessionJson'.toJS,
        tokenJS,
        groupJS,
      ) as JSPromise?;

      if (promise == null) {
        const err = 'Bridge returned null promise during initSessionJson.';
        lastError = err;
        lastStage = 4;
        lastStageName = 'Camera Kit initialization begins';
        return SnapInitResult.failure(err, stage: 4, stageName: lastStageName);
      }

      // Add a client-side timeout wrapper in Dart
      final rawResult = await promise.toDart.timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw Exception('SnapCameraBridge.initSession timed out after 20 seconds in Flutter Web.');
        },
      );

      final resultStr = (rawResult as JSString?)?.toDart;
      if (resultStr == null) {
        const err = 'Empty response received from SnapCameraBridge.initSessionJson.';
        lastError = err;
        return SnapInitResult.failure(err);
      }

      final Map<String, dynamic> data = jsonDecode(resultStr);
      final result = SnapInitResult.fromMap(data);
      lastStage = result.stage;
      lastStageName = result.stageName;
      lastError = result.error;

      if (!result.success) {
        debugPrint('[SnapCameraKit:Diag] Bridge initSession failed at stage ${result.stage} (${result.stageName}): ${result.error}');
      } else {
        debugPrint('[SnapCameraKit:Diag] Bridge initSession completed successfully (lenses: ${result.lensCount}, elapsed: ${result.elapsedMs}ms)');
      }

      return result;
    } catch (e) {
      final err = e.toString();
      lastError = err;
      debugPrint('[SnapCameraBridge:Web] initSessionDetailed exception: $err');
      return SnapInitResult.failure(err, stage: lastStage, stageName: lastStageName);
    }
  }

  static Future<bool> initSession({String? apiToken, String? lensGroupId}) async {
    final res = await initSessionDetailed(apiToken: apiToken, lensGroupId: lensGroupId);
    return res.success;
  }

  static Future<List<SnapWebLens>> loadLensGroup(String groupId, {String? apiToken}) async {
    final bridge = _bridge;
    if (bridge == null) {
      lastError = 'Bridge not available on window.';
      return const [];
    }

    try {
      final tokenJS = (apiToken ?? '').toJS;
      final promise = bridge.callMethod(
        'loadLensGroupJson'.toJS,
        groupId.toJS,
        tokenJS,
      ) as JSPromise?;

      if (promise == null) return const [];
      final rawResult = await promise.toDart.timeout(
        const Duration(seconds: 18),
        onTimeout: () {
          throw Exception('loadLensGroup timed out after 18 seconds.');
        },
      );
      final resultStr = (rawResult as JSString?)?.toDart;
      if (resultStr == null) return const [];

      final Map<String, dynamic> data = jsonDecode(resultStr);
      if (data['success'] == true && data['lenses'] is List) {
        final List list = data['lenses'];
        return list
            .map((item) => SnapWebLens.fromMap(Map<String, dynamic>.from(item as Map)))
            .toList();
      }

      if (data['error'] != null) {
        lastError = data['error'].toString();
        debugPrint('[SnapCameraKit:Diag] loadLensGroup returned error: $lastError');
      }
      return const [];
    } catch (e) {
      lastError = e.toString();
      debugPrint('[SnapCameraBridge:Web] loadLensGroup error: $e');
      return const [];
    }
  }

  static List<SnapWebLens> getLoadedLenses() {
    final bridge = _bridge;
    if (bridge == null) return const [];

    try {
      final jsLenses = bridge.callMethod('getLoadedLenses'.toJS) as JSArray?;
      if (jsLenses == null) return const [];
      final list = jsLenses.toDart;
      final result = <SnapWebLens>[];
      for (final item in list) {
        if (item != null && item.isA<JSObject>()) {
          final obj = item as JSObject;
          final id = (obj.getProperty('id'.toJS) as JSString?)?.toDart ?? '';
          final name = (obj.getProperty('name'.toJS) as JSString?)?.toDart ?? 'Snap Lens';
          final iconUrl = (obj.getProperty('iconUrl'.toJS) as JSString?)?.toDart ?? '';
          final groupId = (obj.getProperty('groupId'.toJS) as JSString?)?.toDart ?? '';
          result.add(SnapWebLens(id: id, name: name, iconUrl: iconUrl, groupId: groupId));
        }
      }
      return result;
    } catch (e) {
      debugPrint('[SnapCameraBridge:Web] getLoadedLenses error: $e');
      return const [];
    }
  }

  static Future<bool> applyLens(String lensId) async {
    final bridge = _bridge;
    if (bridge == null) {
      lastError = 'Bridge not available on window';
      return false;
    }

    try {
      final promise = bridge.callMethod(
        'applyLensJson'.toJS,
        lensId.toJS,
      ) as JSPromise?;

      if (promise == null) return false;
      final rawResult = await promise.toDart.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('applyLens timed out after 15 seconds.');
        },
      );
      final resultStr = (rawResult as JSString?)?.toDart;
      if (resultStr == null) return false;

      final Map<String, dynamic> data = jsonDecode(resultStr);
      if (data['success'] == true) {
        return true;
      }
      lastError = data['error']?.toString() ?? 'Failed to apply lens $lensId';
      debugPrint('[SnapCameraKit:Diag] applyLens failed: $lastError');
      return false;
    } catch (e) {
      lastError = e.toString();
      debugPrint('[SnapCameraBridge:Web] applyLens error: $e');
      return false;
    }
  }

  static Future<bool> removeLens() async {
    final bridge = _bridge;
    if (bridge == null) return false;

    try {
      final promise = bridge.callMethod('removeLensJson'.toJS) as JSPromise?;
      if (promise == null) return false;
      final rawResult = await promise.toDart;
      final resultStr = (rawResult as JSString?)?.toDart;
      if (resultStr == null) return false;

      final Map<String, dynamic> data = jsonDecode(resultStr);
      return data['success'] == true;
    } catch (e) {
      debugPrint('[SnapCameraBridge:Web] removeLens error: $e');
      return false;
    }
  }

  static Future<SnapCaptureResult> capturePhoto() async {
    final bridge = _bridge;
    if (bridge == null) {
      return const SnapCaptureResult(success: false, error: 'Bridge not initialized');
    }

    try {
      final promise = bridge.callMethod('capturePhotoJson'.toJS) as JSPromise?;
      if (promise == null) {
        return const SnapCaptureResult(success: false, error: 'Null capture promise');
      }

      final rawResult = await promise.toDart.timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          throw Exception('capturePhoto timed out after 8s');
        },
      );
      final resultStr = (rawResult as JSString?)?.toDart;
      if (resultStr == null) {
        return const SnapCaptureResult(success: false, error: 'Empty capture result');
      }

      final Map<String, dynamic> data = jsonDecode(resultStr);
      if (data['success'] == true && data['dataUrl'] is String) {
        final dataUrl = data['dataUrl'] as String;
        final base64Prefix = 'base64,';
        final idx = dataUrl.indexOf(base64Prefix);
        Uint8List? bytes;
        if (idx != -1) {
          bytes = base64Decode(dataUrl.substring(idx + base64Prefix.length));
        }
        return SnapCaptureResult(
          success: true,
          dataUrl: dataUrl,
          bytes: bytes,
        );
      }
      return SnapCaptureResult(
        success: false,
        error: data['error']?.toString() ?? 'Failed to capture photo',
      );
    } catch (e) {
      return SnapCaptureResult(success: false, error: e.toString());
    }
  }

  static Future<bool> startRecording() async {
    final bridge = _bridge;
    if (bridge == null) return false;

    try {
      final resJS = bridge.callMethod('startRecordingJson'.toJS) as JSString?;
      final resStr = resJS?.toDart;
      if (resStr == null) return false;
      final Map<String, dynamic> data = jsonDecode(resStr);
      return data['success'] == true;
    } catch (e) {
      debugPrint('[SnapCameraBridge:Web] startRecording error: $e');
      return false;
    }
  }

  static Future<SnapCaptureResult> stopRecording() async {
    final bridge = _bridge;
    if (bridge == null) {
      return const SnapCaptureResult(
        success: false,
        error: 'Bridge not initialized',
        isVideo: true,
      );
    }

    try {
      final promise = bridge.callMethod('stopRecordingJson'.toJS) as JSPromise?;
      if (promise == null) {
        return const SnapCaptureResult(
          success: false,
          error: 'Null recording promise',
          isVideo: true,
        );
      }

      final rawResult = await promise.toDart.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('stopRecording timed out after 10s');
        },
      );
      final resultStr = (rawResult as JSString?)?.toDart;
      if (resultStr == null) {
        return const SnapCaptureResult(
          success: false,
          error: 'Empty recording result',
          isVideo: true,
        );
      }

      final Map<String, dynamic> data = jsonDecode(resultStr);
      if (data['success'] == true && data['dataUrl'] is String) {
        final dataUrl = data['dataUrl'] as String;
        final base64Prefix = 'base64,';
        final idx = dataUrl.indexOf(base64Prefix);
        Uint8List? bytes;
        if (idx != -1) {
          bytes = base64Decode(dataUrl.substring(idx + base64Prefix.length));
        }
        return SnapCaptureResult(
          success: true,
          dataUrl: dataUrl,
          bytes: bytes,
          isVideo: true,
        );
      }
      return SnapCaptureResult(
        success: false,
        error: data['error']?.toString() ?? 'Failed to record video',
        isVideo: true,
      );
    } catch (e) {
      return SnapCaptureResult(success: false, error: e.toString(), isVideo: true);
    }
  }

  static Future<bool> switchCamera() async {
    final bridge = _bridge;
    if (bridge == null) return false;

    try {
      final promise = bridge.callMethod('switchCameraJson'.toJS) as JSPromise?;
      if (promise == null) return false;
      final rawResult = await promise.toDart;
      final resultStr = (rawResult as JSString?)?.toDart;
      if (resultStr == null) return false;
      final Map<String, dynamic> data = jsonDecode(resultStr);
      return data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  static void dispose() {
    final bridge = _bridge;
    if (bridge == null) return;
    try {
      bridge.callMethod('dispose'.toJS);
    } catch (_) {}
  }
}
