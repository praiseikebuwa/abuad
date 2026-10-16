import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:camerakit_flutter/camerakit_flutter.dart';
import 'package:camerakit_flutter/lens_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';
import '../../music/domain/audio_track.dart';
import '../../music/presentation/music_picker_sheet.dart';
import 'media_editor_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CameraMode { directors, photo, video, night, focus }
enum GridType { thirds, golden, crosshair }
enum CameraContext { post, story, snap }
enum CameraAspectRatio {
  full('Full', null),
  ratio9_16('9:16', 9 / 16),
  ratio3_4('3:4', 3 / 4),
  ratio1_1('1:1', 1.0);

  final String label;
  final double? ratio; // width / height
  const CameraAspectRatio(this.label, this.ratio);
}

class CameraScreen extends StatefulWidget {
  final bool isForStory;
  final CameraContext? cameraContext;
  final String? directRecipientId;
  final String? directRecipientName;
  final Function(XFile file, CameraMode mode)? onMediaCaptured;

  const CameraScreen({
    super.key,
    this.isForStory = true,
    this.cameraContext,
    this.directRecipientId,
    this.directRecipientName,
    this.onMediaCaptured,
  });

  CameraContext get effectiveContext {
    if (cameraContext != null) return cameraContext!;
    return isForStory ? CameraContext.story : CameraContext.snap;
  }

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin
    implements CameraKitFlutterEvents {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _selectedCameraIndex = 0;
  CameraMode _currentMode = CameraMode.photo;
  bool _isRecording = false;
  bool _isCameraInitialized = false;
  bool _isCameraInitializing = false;
  bool _isCaptureOperationInProgress = false;
  FlashMode _flashMode = FlashMode.off;
  AudioTrack? _selectedAudioTrack;

  // Global key for exact preview viewfinder coordinate calculation
  final GlobalKey _previewKey = GlobalKey();
  Timer? _focusTimer;

  // Zoom control
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 4.0;
  double _baseZoom = 1.0;

  // Lighting & Exposure
  double _exposureOffset = 0.0;
  double _maxExposureOffset = 2.0;
  double _minExposureOffset = -2.0;
  bool _showExposureSlider = false;
  bool _isNightMode = false;
  Offset? _focusPoint;

  // Grid & Composition
  bool _showGrid = false;
  GridType _gridType = GridType.thirds;
  final bool _isMirrored = true;

  // Gallery Asset
  Uint8List? _latestGallerImage;

  // Snapchat Lenses (CameraKit)
  late final _cameraKitFlutterImpl = CameraKitFlutterImpl(cameraKitFlutterEvents: this);
  static const String _snapLensGroupId = '4b594445-eaf3-46cd-8626-fae099b74079';
  List<Lens> _snapLenses = [];

  // Timers & Duration
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;
  Timer? _countdownTimer;
  bool _timerModeActive = false;
  final int _timerDelaySeconds = 3;
  int _timerCountdownValue = 0;

  // Resolution & Picker
  final ResolutionPreset _resolutionPreset = ResolutionPreset.high;
  final _picker = ImagePicker();
  bool _isPickingImage = false;

  // Aspect Ratio & Toolbar Visibility State
  static const String _prefAspectRatioKey = 'camera_aspect_ratio_pref';
  static const String _prefShowToolbarKey = 'camera_show_toolbar_pref';
  CameraAspectRatio _aspectRatio = CameraAspectRatio.full;
  bool _showSideToolbar = true;

  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _fetchLatestGalleryImage();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedRatio = prefs.getString(_prefAspectRatioKey);
      final savedToolbar = prefs.getBool(_prefShowToolbarKey);

      if (savedRatio != null && mounted) {
        final matchedRatio = CameraAspectRatio.values.firstWhere(
          (r) => r.name == savedRatio || r.label == savedRatio,
          orElse: () => CameraAspectRatio.full,
        );
        setState(() {
          _aspectRatio = matchedRatio;
        });
      }

      if (savedToolbar != null && mounted) {
        setState(() {
          _showSideToolbar = savedToolbar;
        });
      }
    } catch (e) {
      debugPrint('Error loading camera preferences: $e');
    }
  }

  Future<void> _setAspectRatio(CameraAspectRatio ratio) async {
    HapticFeedback.mediumImpact();
    setState(() {
      _aspectRatio = ratio;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefAspectRatioKey, ratio.name);
    } catch (e) {
      debugPrint('Error saving aspect ratio: $e');
    }
  }

  void _cycleAspectRatio() {
    final currentIndex = CameraAspectRatio.values.indexOf(_aspectRatio);
    final nextIndex = (currentIndex + 1) % CameraAspectRatio.values.length;
    _setAspectRatio(CameraAspectRatio.values[nextIndex]);
  }

  Future<void> _toggleSideToolbar() async {
    HapticFeedback.lightImpact();
    final nextVal = !_showSideToolbar;
    setState(() {
      _showSideToolbar = nextVal;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefShowToolbarKey, nextVal);
    } catch (e) {
      debugPrint('Error saving toolbar pref: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusTimer?.cancel();
    _recordingTimer?.cancel();
    _countdownTimer?.cancel();
    _pulseController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _releaseCamera();
    } else if (state == AppLifecycleState.resumed) {
      _restoreCamera();
    }
  }

  Future<void> _releaseCamera() async {
    final controller = _controller;
    _controller = null;
    if (mounted) {
      setState(() {
        _isCameraInitialized = false;
        if (_isRecording) {
          _isRecording = false;
          _recordingTimer?.cancel();
        }
      });
    }
    if (controller != null) {
      await controller.dispose();
    }
  }

  Future<void> _restoreCamera() async {
    if (!mounted || _isCameraInitializing || _cameras.isEmpty) {
      return;
    }
    final index = _selectedCameraIndex.clamp(0, _cameras.length - 1);
    await _onNewCameraSelected(_cameras[index]);
  }

  Future<void> _initializeCamera() async {
    try {
      final cameraStatus = await Permission.camera.request();
      // Request microphone optionally so photo mode is not blocked if denied
      await Permission.microphone.request();

      if (cameraStatus.isGranted) {
        _cameras = await availableCameras();
        if (_cameras.isNotEmpty) {
          await _onNewCameraSelected(_cameras[_selectedCameraIndex]);
        }
      } else {
        if (mounted) setState(() => _isCameraInitialized = false);
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _onNewCameraSelected(CameraDescription cameraDescription) async {
    if (_isCameraInitializing) return;
    _isCameraInitializing = true;

    final oldController = _controller;
    _controller = null;
    if (mounted) setState(() => _isCameraInitialized = false);
    if (oldController != null) {
      await oldController.dispose();
    }

    final CameraController cameraController = CameraController(
      cameraDescription,
      _resolutionPreset,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _controller = cameraController;

    cameraController.addListener(() {
      if (mounted) setState(() {});
      if (cameraController.value.hasError) {
        debugPrint('Camera error: ${cameraController.value.errorDescription}');
      }
    });

    try {
      await cameraController.initialize();
      try {
        await cameraController.setFlashMode(_flashMode);
      } catch (_) {}
      try {
        _minZoom = await cameraController.getMinZoomLevel();
        _maxZoom = await cameraController.getMaxZoomLevel();
        if (_maxZoom <= _minZoom) _maxZoom = _minZoom * 4.0;
      } catch (_) {
        _minZoom = 1.0;
        _maxZoom = 4.0;
      }
      _currentZoom = 1.0.clamp(_minZoom, _maxZoom);
      try {
        await cameraController.setZoomLevel(_currentZoom);
      } catch (_) {}

      try {
        _minExposureOffset = await cameraController.getMinExposureOffset();
        _maxExposureOffset = await cameraController.getMaxExposureOffset();
      } catch (_) {
        _minExposureOffset = -2.0;
        _maxExposureOffset = 2.0;
      }
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _controller = cameraController;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera controller: $e');
      if (mounted) {
        setState(() => _isCameraInitialized = false);
      }
    } finally {
      _isCameraInitializing = false;
    }
  }

  Future<void> _fetchLatestGalleryImage() async {
    if (kIsWeb) return;
    try {
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      if (!ps.isAuth) return;
      final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
      );
      if (paths.isEmpty) return;
      final List<AssetEntity> assets = await paths[0].getAssetListRange(
        start: 0,
        end: 1,
      );
      if (assets.isEmpty) return;
      final asset = assets[0];
      final Uint8List? thumb = await asset.thumbnailData;
      if (mounted) {
        setState(() {
          _latestGallerImage = thumb;
        });
      }
    } catch (e) {
      debugPrint('Error fetching latest gallery image: $e');
    }
  }

  void _toggleCamera() {
    if (_cameras.length < 2 || _isRecording || _isCaptureOperationInProgress) return;
    HapticFeedback.mediumImpact();
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    _onNewCameraSelected(_cameras[_selectedCameraIndex]);
  }

  void _toggleFlash() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    HapticFeedback.lightImpact();
    setState(() {
      _flashMode = _flashMode == FlashMode.off
          ? FlashMode.auto
          : _flashMode == FlashMode.auto
              ? FlashMode.always
              : _flashMode == FlashMode.always
                  ? FlashMode.torch
                  : FlashMode.off;
    });
    try {
      _controller?.setFlashMode(_flashMode);
    } catch (_) {}
  }

  void _toggleNightMode() {
    HapticFeedback.mediumImpact();
    setState(() => _isNightMode = !_isNightMode);
    if (_isNightMode) {
      _setExposureOffset(_maxExposureOffset);
    } else {
      _setExposureOffset(0.0);
    }
  }

  void _setFocusPoint(Offset globalPosition) {
    final renderObject = _previewKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || _controller == null || !_controller!.value.isInitialized) return;
    final local = renderObject.globalToLocal(globalPosition);
    final size = renderObject.size;
    final x = (local.dx / size.width).clamp(0.0, 1.0);
    final y = (local.dy / size.height).clamp(0.0, 1.0);
    try {
      _controller!.setFocusPoint(Offset(x, y));
      _controller!.setExposurePoint(Offset(x, y));
    } catch (_) {}
    HapticFeedback.selectionClick();
    setState(() => _focusPoint = Offset(x, y));
    _focusTimer?.cancel();
    _focusTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && _focusPoint == Offset(x, y)) {
        setState(() => _focusPoint = null);
      }
    });
  }

  Future<void> _setExposureOffset(double value) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final clamped = value.clamp(_minExposureOffset, _maxExposureOffset);
    try {
      await controller.setExposureOffset(clamped);
      if (mounted) setState(() => _exposureOffset = clamped);
    } catch (_) {}
  }

  void _openGridTypeSelector() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('Composition Grid', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.grid_3x3_rounded, color: Colors.white),
                title: const Text('Rule of Thirds (3x3)', style: TextStyle(color: Colors.white)),
                trailing: _showGrid && _gridType == GridType.thirds ? const Icon(Icons.check, color: AppColors.secondaryTeal) : null,
                onTap: () {
                  setState(() {
                    _showGrid = true;
                    _gridType = GridType.thirds;
                  });
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.crop_rotate_rounded, color: Colors.white),
                title: const Text('Golden Ratio', style: TextStyle(color: Colors.white)),
                trailing: _showGrid && _gridType == GridType.golden ? const Icon(Icons.check, color: AppColors.secondaryTeal) : null,
                onTap: () {
                  setState(() {
                    _showGrid = true;
                    _gridType = GridType.golden;
                  });
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.filter_center_focus_rounded, color: Colors.white),
                title: const Text('Center Crosshair', style: TextStyle(color: Colors.white)),
                trailing: _showGrid && _gridType == GridType.crosshair ? const Icon(Icons.check, color: AppColors.secondaryTeal) : null,
                onTap: () {
                  setState(() {
                    _showGrid = true;
                    _gridType = GridType.crosshair;
                  });
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.grid_off_rounded, color: Colors.white54),
                title: const Text('Disable Grid', style: TextStyle(color: Colors.white70)),
                trailing: !_showGrid ? const Icon(Icons.check, color: Colors.white54) : null,
                onTap: () {
                  setState(() => _showGrid = false);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAspectRatioSelector() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.96),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white12),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Camera Aspect Ratio',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Frames viewfinder and crops photos & videos with black letterboxing',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: CameraAspectRatio.values.map((ratio) {
                    final isSelected = _aspectRatio == ratio;
                    return GestureDetector(
                      onTap: () {
                        _setAspectRatio(ratio);
                        Navigator.pop(ctx);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.secondaryTeal.withValues(alpha: 0.25)
                                  : Colors.white10,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.secondaryTeal
                                    : Colors.white24,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Center(
                              child: _buildAspectRatioIcon(ratio, isSelected),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            ratio.label,
                            style: TextStyle(
                              color: isSelected ? AppColors.secondaryTeal : Colors.white70,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAspectRatioIcon(CameraAspectRatio ratio, bool isSelected) {
    final color = isSelected ? AppColors.secondaryTeal : Colors.white70;
    switch (ratio) {
      case CameraAspectRatio.full:
        return Icon(Icons.fullscreen_rounded, color: color, size: 28);
      case CameraAspectRatio.ratio9_16:
        return Container(
          width: 18,
          height: 32,
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      case CameraAspectRatio.ratio3_4:
        return Container(
          width: 22,
          height: 30,
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      case CameraAspectRatio.ratio1_1:
        return Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
        );
    }
  }

  void _setZoom(double zoom) {
    final clamped = zoom.clamp(_minZoom, _maxZoom);
    setState(() => _currentZoom = clamped);
    try {
      _controller?.setZoomLevel(clamped);
    } catch (_) {}
    HapticFeedback.selectionClick();
  }

  void _openSnapchatLenses() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Snapchat Lenses are supported on mobile devices (Android/iOS).'),
        ),
      );
      return;
    }
    try {
      HapticFeedback.mediumImpact();
      await _cameraKitFlutterImpl.openCameraKit(
        groupIds: [_snapLensGroupId],
        isHideCloseButton: false,
      );
    } catch (e) {
      debugPrint('Error launching Snapchat Camera Kit: $e');
      if (mounted) {
        final isMissingPlugin = e.toString().contains('MissingPluginException');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isMissingPlugin
                  ? 'Please do a full app rebuild to compile native Snapchat SDK.'
                  : 'Could not launch Snapchat Lenses: $e',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  void receivedLenses(List<Lens> lensList) {
    if (mounted) {
      setState(() {
        _snapLenses = lensList;
        debugPrint('Loaded ${_snapLenses.length} Snapchat Lenses');
      });
    }
  }

  @override
  void onCameraKitResult(Map<dynamic, dynamic> result) {
    final String? path = result['path']?.toString();
    final String? type = result['type']?.toString();
    if (path != null && path.isNotEmpty) {
      final mode = (type != null && type.contains('video')) ? CameraMode.video : CameraMode.photo;
      _handleMediaCapture(XFile(path), mode);
    }
  }

  void _toggleTimerMode() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_timerModeActive) {
        _timerModeActive = false;
        _countdownTimer?.cancel();
        _timerCountdownValue = 0;
      } else {
        _timerModeActive = true;
        _timerCountdownValue = _timerDelaySeconds;
      }
    });
  }

  Future<void> _handleShutterTap() async {
    if (_isCaptureOperationInProgress) return;
    switch (_currentMode) {
      case CameraMode.photo:
      case CameraMode.focus:
      case CameraMode.directors:
      case CameraMode.night:
        await _takePhoto();
        break;
      case CameraMode.video:
        if (_isRecording) {
          await _stopVideoRecording();
        } else {
          await _startVideoRecording();
        }
        break;
    }
  }

  void _handleShutterLongPressStart() {
    if (_currentMode != CameraMode.video && !_isRecording) {
      _startVideoRecording();
    }
  }

  void _handleShutterLongPressEnd() {
    if (_isRecording) {
      _stopVideoRecording();
    }
  }

  Future<void> _takePhoto() async {
    final controller = _controller;
    if (!_isCameraInitialized || _isRecording || _isCaptureOperationInProgress || controller == null || !controller.value.isInitialized) {
      return;
    }
    HapticFeedback.mediumImpact();

    if (_timerModeActive) {
      _timerCountdownValue = _timerDelaySeconds;
      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return timer.cancel();
        setState(() => _timerCountdownValue--);
        if (_timerCountdownValue <= 0) {
          timer.cancel();
          _capturePhoto();
        }
      });
    } else {
      _capturePhoto();
    }
  }

  Future<void> _capturePhoto() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isCaptureOperationInProgress) return;
    _isCaptureOperationInProgress = true;
    try {
      final XFile file = await controller.takePicture();
      _handleMediaCapture(file, CameraMode.photo);
    } catch (e) {
      debugPrint('Error taking photo: $e');
    } finally {
      _isCaptureOperationInProgress = false;
    }
  }

  Future<void> _startVideoRecording() async {
    final controller = _controller;
    if (!_isCameraInitialized || _isRecording || _isCaptureOperationInProgress || controller == null || !controller.value.isInitialized) {
      return;
    }
    _isCaptureOperationInProgress = true;
    HapticFeedback.heavyImpact();
    try {
      await controller.startVideoRecording();
      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !_isRecording) return;
        setState(() => _recordingDuration += const Duration(seconds: 1));
      });
    } catch (e) {
      debugPrint('Error starting video recording: $e');
    } finally {
      _isCaptureOperationInProgress = false;
    }
  }

  Future<void> _stopVideoRecording() async {
    final controller = _controller;
    if (!_isCameraInitialized || !_isRecording || _isCaptureOperationInProgress || controller == null || !controller.value.isInitialized) {
      return;
    }
    _isCaptureOperationInProgress = true;
    HapticFeedback.mediumImpact();
    try {
      _recordingTimer?.cancel();
      final XFile file = await controller.stopVideoRecording();
      if (!mounted) return;
      setState(() => _isRecording = false);
      _handleMediaCapture(file, CameraMode.video);
    } catch (e) {
      debugPrint('Error stopping video recording: $e');
      if (mounted) setState(() => _isRecording = false);
    } finally {
      _isCaptureOperationInProgress = false;
    }
  }

  void _handleMediaCapture(XFile file, CameraMode mode) async {
    if (!mounted) return;
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MediaEditorScreen(
          mediaFile: file,
          isVideo: mode == CameraMode.video,
          isForStory: widget.isForStory,
          cameraContext: widget.effectiveContext,
          directRecipientId: widget.directRecipientId,
          directRecipientName: widget.directRecipientName,
          onMediaExported: widget.onMediaCaptured,
          initialAudioTrack: _selectedAudioTrack,
          aspectRatio: _aspectRatio.ratio,
          aspectRatioLabel: _aspectRatio.label,
        ),
      ),
    );
    if (result != null && mounted) {
      Navigator.of(context).pop(result);
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isPickingImage) return;
    _isPickingImage = true;
    HapticFeedback.lightImpact();
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) _handleMediaCapture(image, CameraMode.photo);
    } finally {
      _isPickingImage = false;
    }
  }

  Future<void> _openMusicSelector() async {
    HapticFeedback.lightImpact();
    final track = await MusicPickerSheet.show(context);
    if (track != null && mounted) {
      setState(() {
        _selectedAudioTrack = track;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isFrontCamera = _cameras.isNotEmpty &&
        _selectedCameraIndex < _cameras.length &&
        _cameras[_selectedCameraIndex].lensDirection == CameraLensDirection.front;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Edge-to-Edge Fullscreen Camera Viewfinder (Aspect Ratio Cover without black bars)
          GestureDetector(
            onScaleStart: (details) {
              _baseZoom = _currentZoom;
            },
            onScaleUpdate: (details) {
              final newZoom = (_baseZoom * details.scale).clamp(_minZoom, _maxZoom);
              if (newZoom != _currentZoom) {
                setState(() => _currentZoom = newZoom);
                _controller?.setZoomLevel(newZoom);
              }
            },
            onDoubleTap: _toggleCamera,
            onTapUp: (details) => _setFocusPoint(details.globalPosition),
            child: KeyedSubtree(
              key: _previewKey,
              child: _buildCameraViewfinder(screenSize, isFrontCamera),
            ),
          ),

          // 2. Focus & Lighting Indicator (Animated Ring + Exposure Sun)
          if (_focusPoint != null)
            Positioned(
              left: (_focusPoint!.dx * screenSize.width) - 35,
              top: (_focusPoint!.dy * screenSize.height) - 35,
              child: Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ).animate().scale(duration: 150.ms, curve: Curves.easeOut),
                  const SizedBox(width: 8),
                  const Icon(Icons.wb_sunny_rounded, color: Color(0xFFFFD700), size: 20)
                      .animate()
                      .fadeIn(duration: 200.ms),
                ],
              ),
            ),

          // 4. Top Action Bar: [X], [Flash], [Music Pill], [Aspect Ratio Pill], [Toolbar Toggle]
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Close button (Frosted circular X)
                _buildFrostedCircleButton(
                  icon: Icons.close_rounded,
                  size: 42,
                  onTap: () => Navigator.of(context).pop(),
                ),

                // Center: Flash & Music Pill
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFrostedCircleButton(
                      icon: _getFlashIcon(),
                      size: 42,
                      isActive: _flashMode != FlashMode.off,
                      onTap: _toggleFlash,
                    ),
                    const SizedBox(width: 8),
                    // Music Pill (Frosted dropdown capsule)
                    GestureDetector(
                      onTap: _openMusicSelector,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: _selectedAudioTrack != null
                                  ? AppColors.secondaryTeal.withValues(alpha: 0.35)
                                  : Colors.black.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: _selectedAudioTrack != null
                                    ? AppColors.secondaryTeal
                                    : Colors.white.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.music_note_rounded, color: Colors.white, size: 18),
                                if (_selectedAudioTrack != null) ...[
                                  const SizedBox(width: 6),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 100),
                                    child: Text(
                                      _selectedAudioTrack!.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      setState(() => _selectedAudioTrack = null);
                                    },
                                    child: const Icon(Icons.close, color: Colors.white70, size: 16),
                                  ),
                                ] else ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 18),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Right Top Actions: [Aspect Ratio Pill] & [Side Toolbar Toggle]
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Aspect Ratio Pill
                    GestureDetector(
                      onTap: _cycleAspectRatio,
                      onLongPress: _openAspectRatioSelector,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: _aspectRatio != CameraAspectRatio.full
                                  ? AppColors.secondaryTeal.withValues(alpha: 0.3)
                                  : Colors.black.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _aspectRatio != CameraAspectRatio.full
                                    ? AppColors.secondaryTeal
                                    : Colors.white.withValues(alpha: 0.18),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.crop_rounded,
                                  color: _aspectRatio != CameraAspectRatio.full
                                      ? AppColors.secondaryTeal
                                      : Colors.white,
                                  size: 15,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _aspectRatio.label,
                                  style: TextStyle(
                                    color: _aspectRatio != CameraAspectRatio.full
                                        ? AppColors.secondaryTeal
                                        : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Side Toolbar Visibility Toggle
                    _buildFrostedCircleButton(
                      icon: _showSideToolbar ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 42,
                      isActive: _showSideToolbar,
                      onTap: _toggleSideToolbar,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 5. Right Vertical Floating Capsule Toolbar (Frosted Island) - Collapsible
          Positioned(
            right: 14,
            top: MediaQuery.of(context).padding.top + 60,
            child: AnimatedSlide(
              offset: _showSideToolbar ? Offset.zero : const Offset(1.4, 0),
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOutCubic,
              child: AnimatedOpacity(
                opacity: _showSideToolbar ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 220),
                child: IgnorePointer(
                  ignoring: !_showSideToolbar,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        width: 50,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.42),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Collapse Chevron (Arrow to hide)
                            GestureDetector(
                              onTap: _toggleSideToolbar,
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                width: 34,
                                height: 26,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.white70,
                                  size: 22,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(width: 20, height: 1, color: Colors.white12),
                            const SizedBox(height: 8),
                            // Aspect Ratio switcher in toolbar
                            _buildToolbarIcon(
                              icon: Icons.crop_rounded,
                              isActive: _aspectRatio != CameraAspectRatio.full,
                              activeColor: AppColors.secondaryTeal,
                              onTap: _cycleAspectRatio,
                              onLongPress: _openAspectRatioSelector,
                            ),
                            const SizedBox(height: 12),
                            // Tuning / Exposure
                            _buildToolbarIcon(
                              icon: Icons.tune_rounded,
                              isActive: _showExposureSlider,
                              onTap: () => setState(() => _showExposureSlider = !_showExposureSlider),
                            ),
                            const SizedBox(height: 12),
                            // Camera Flip
                            _buildToolbarIcon(
                              icon: Icons.flip_camera_ios_rounded,
                              onTap: _toggleCamera,
                            ),
                            const SizedBox(height: 12),
                            // Timer (History/Retake)
                            _buildToolbarIcon(
                              icon: _timerModeActive ? Icons.timer_rounded : Icons.timer_outlined,
                              isActive: _timerModeActive,
                              onTap: _toggleTimerMode,
                            ),
                            const SizedBox(height: 12),
                            // Night Mode (Crescent Moon)
                            _buildToolbarIcon(
                              icon: _isNightMode ? Icons.nightlight_round : Icons.dark_mode_outlined,
                              isActive: _isNightMode,
                              activeColor: Colors.amberAccent,
                              onTap: _toggleNightMode,
                            ),
                            const SizedBox(height: 12),
                            // Grid Mode (4 squares - tap to toggle, long-press to choose grid style)
                            _buildToolbarIcon(
                              icon: _showGrid ? Icons.grid_view_rounded : Icons.grid_view,
                              isActive: _showGrid,
                              onTap: () => setState(() => _showGrid = !_showGrid),
                              onLongPress: _openGridTypeSelector,
                            ),
                            const SizedBox(height: 10),
                            Container(width: 20, height: 1, color: Colors.white24),
                            const SizedBox(height: 10),
                            // Text Tool (Aa)
                            _buildToolbarIcon(
                              label: 'Aa',
                              onTap: () {
                                HapticFeedback.lightImpact();
                                _takePhoto();
                              },
                            ),
                            const SizedBox(height: 12),
                            // Pen / Draw Tool
                            _buildToolbarIcon(
                              icon: Icons.edit_outlined,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                _takePhoto();
                              },
                            ),
                            const SizedBox(height: 12),
                            // Sticker Tool
                            _buildToolbarIcon(
                              icon: Icons.sticky_note_2_outlined,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                _openSnapchatLenses();
                              },
                            ),
                            const SizedBox(height: 12),
                            // Scissors Tool
                            _buildToolbarIcon(
                              icon: Icons.content_cut_rounded,
                              onTap: () => HapticFeedback.lightImpact(),
                            ),
                            const SizedBox(height: 12),
                            // Paperclip Link Tool
                            _buildToolbarIcon(
                              icon: Icons.link_rounded,
                              onTap: () => HapticFeedback.lightImpact(),
                            ),
                            const SizedBox(height: 12),
                            // Stopwatch Duration
                            _buildToolbarIcon(
                              icon: Icons.av_timer_rounded,
                              onTap: () => HapticFeedback.lightImpact(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 5.5 Mini Docked Pull Handle (when side toolbar is collapsed)
          if (!_showSideToolbar)
            Positioned(
              right: 6,
              top: MediaQuery.of(context).padding.top + 70,
              child: GestureDetector(
                onTap: _toggleSideToolbar,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24, width: 0.8),
                        boxShadow: const [
                          BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(-2, 2)),
                        ],
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chevron_left_rounded, color: Colors.white, size: 20),
                          SizedBox(height: 4),
                          Icon(Icons.tune_rounded, color: AppColors.secondaryTeal, size: 14),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 6. Vertical Exposure Slider (When tuning toggle is active)
          if (_showExposureSlider)
            Positioned(
              right: 80,
              top: screenSize.height * 0.35,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    height: 180,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.wb_sunny, color: Colors.amberAccent, size: 16),
                        RotatedBox(
                          quarterTurns: 3,
                          child: SliderTheme(
                            data: SliderThemeData(
                              activeTrackColor: Colors.amberAccent,
                              inactiveTrackColor: Colors.white24,
                              thumbColor: Colors.white,
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                            ),
                            child: Slider(
                              value: _exposureOffset,
                              min: _minExposureOffset,
                              max: _maxExposureOffset,
                              onChanged: _setExposureOffset,
                            ),
                          ),
                        ),
                        const Icon(Icons.brightness_2, color: Colors.white60, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 7. Video Recording / Countdown Timer Indicators
          if (_isRecording)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(
                        _formatDuration(_recordingDuration),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (_timerModeActive && _countdownTimer != null)
            Positioned.fill(
              child: Center(
                child: Text(
                  '$_timerCountdownValue',
                  style: const TextStyle(
                    fontSize: 100,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [Shadow(blurRadius: 16, color: Colors.black)],
                  ),
                ),
              ),
            ),

          // 8. Bottom Camera Shutter, Mode Bar & Action Controls
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Zoom Pill Selectors (0.5x, 1x, 2x, 3x)
                  _buildZoomPillSelector(),

                  const SizedBox(height: 12),

                  // Dynamic floating tooltip
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12, width: 0.5),
                        ),
                        child: Text(
                          _isRecording
                              ? 'recording in progress'
                              : _currentMode == CameraMode.video
                                  ? 'tap to record video'
                                  : 'tap to snap, hold for video',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Shutter Row: Gallery | Big Shutter Button | Lenses/Effects
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left: Gallery Thumbnail
                        GestureDetector(
                          onTap: _pickFromGallery,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white54, width: 2),
                                  color: Colors.white10,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: _latestGallerImage != null
                                    ? Image.memory(_latestGallerImage!, fit: BoxFit.cover)
                                    : const Icon(Icons.photo_library_outlined, color: Colors.white, size: 24),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Gallery',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),

                        // Center: Shutter with Iridescent Gradient Border
                        GestureDetector(
                          onTap: _handleShutterTap,
                          onLongPressStart: (_) => _handleShutterLongPressStart(),
                          onLongPressEnd: (_) => _handleShutterLongPressEnd(),
                          child: _buildGlowingShutterButton(),
                        ),

                        // Right: Lenses / Effects
                        GestureDetector(
                          onTap: _openSnapchatLenses,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                  child: Container(
                                    width: 54,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.35),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Colors.white30, width: 1.5),
                                    ),
                                    child: const Icon(
                                      Icons.sentiment_satisfied_alt_rounded,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Lenses / Effects',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Mode Selector Bar: Directors Mode | Camera | Video | Night | Focus
                  _buildModeCarousel(),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Viewfinder with dynamic Aspect Ratio letterboxing and framing
  Widget _buildCameraViewfinder(Size screenSize, bool isFrontCamera) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      );
    }

    final previewSize = _controller!.value.previewSize;
    final previewWidth = previewSize != null ? previewSize.height : screenSize.width;
    final previewHeight = previewSize != null ? previewSize.width : screenSize.height;

    double targetWidth = screenSize.width;
    double targetHeight = screenSize.height;

    if (_aspectRatio.ratio != null) {
      final calculatedHeight = screenSize.width / _aspectRatio.ratio!;
      if (calculatedHeight <= screenSize.height) {
        targetWidth = screenSize.width;
        targetHeight = calculatedHeight;
      } else {
        targetHeight = screenSize.height;
        targetWidth = screenSize.height * _aspectRatio.ratio!;
      }
    }

    return Container(
      color: Colors.black,
      width: screenSize.width,
      height: screenSize.height,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          width: targetWidth,
          height: targetHeight,
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                OverflowBox(
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: previewWidth,
                      height: previewHeight,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: isFrontCamera && _isMirrored
                            ? Matrix4.diagonal3Values(-1.0, 1.0, 1.0)
                            : Matrix4.identity(),
                        child: CameraPreview(_controller!),
                      ),
                    ),
                  ),
                ),
                if (_showGrid)
                  IgnorePointer(
                    child: CustomPaint(painter: GridPainter(_gridType)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Zoom Pill Selector: [0.5x] [1x] [2x] [3x]
  Widget _buildZoomPillSelector() {
    final List<double> zoomOptions = [];
    if (_minZoom <= 0.6) zoomOptions.add(0.5);
    zoomOptions.add(1.0);
    if (_maxZoom >= 2.0) zoomOptions.add(2.0);
    if (_maxZoom >= 3.0) zoomOptions.add(3.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: zoomOptions.map((z) {
              final isSelected = (_currentZoom - z).abs() < 0.3;
              return GestureDetector(
                onTap: () => _setZoom(z),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${z == 0.5 ? "0.5" : z.toInt()}x',
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // Iridescent Shutter Button
  Widget _buildGlowingShutterButton() {
    final isVideo = _currentMode == CameraMode.video;
    final isPulsing = _isRecording;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: isPulsing ? 92 : 86,
      height: isPulsing ? 92 : 86,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isVideo || isPulsing
            ? const SweepGradient(
                colors: [
                  Color(0xFFEF4444), // Red 500
                  Color(0xFFF87171), // Red 400
                  Color(0xFFDC2626), // Red 600
                  Color(0xFFEF4444),
                ],
              )
            : const SweepGradient(
                colors: [
                  Color(0xFF8B5CF6), // Violet
                  Color(0xFFEC4899), // Pink
                  Color(0xFF38BDF8), // Cyan
                  Color(0xFF6366F1), // Indigo
                  Color(0xFF8B5CF6), // Loop
                ],
              ),
        boxShadow: [
          BoxShadow(
            color: (isVideo || isPulsing ? const Color(0xFFEF4444) : const Color(0xFF8B5CF6))
                .withValues(alpha: 0.45),
            blurRadius: isPulsing ? 24 : 18,
            spreadRadius: isPulsing ? 4 : 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(5),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isPulsing ? Colors.redAccent : Colors.white,
          shape: isPulsing ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: isPulsing ? BorderRadius.circular(16) : null,
        ),
        child: isPulsing
            ? const Center(
                child: Icon(Icons.stop_rounded, color: Colors.white, size: 36),
              )
            : (isVideo
                ? const Center(
                    child: Icon(Icons.videocam_rounded, color: Color(0xFFEF4444), size: 30),
                  )
                : null),
      ),
    );
  }

  // Mode Carousel
  Widget _buildModeCarousel() {
    final modes = [
      (CameraMode.directors, 'Directors Mode'),
      (CameraMode.photo, 'Camera'),
      (CameraMode.video, 'Video'),
      (CameraMode.night, 'Night'),
      (CameraMode.focus, 'Focus'),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 38,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12, width: 0.5),
          ),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            shrinkWrap: true,
            itemCount: modes.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final mode = modes[index].$1;
              final label = modes[index].$2;
              final isSelected = _currentMode == mode;

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _currentMode = mode);
                  if (mode == CameraMode.night && !_isNightMode) {
                    _toggleNightMode();
                  }
                },
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white54,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      if (isSelected)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          width: 18,
                          height: 2,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }



  // Right Toolbar Icon Button
  Widget _buildToolbarIcon({
    IconData? icon,
    String? label,
    bool isActive = false,
    Color? activeColor,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isActive ? (activeColor ?? Colors.white).withValues(alpha: 0.25) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: label != null
              ? Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                )
              : Icon(
                  icon,
                  color: isActive ? (activeColor ?? Colors.amberAccent) : Colors.white,
                  size: 22,
                ),
        ),
      ),
    );
  }

  // Circular Frosted Button
  Widget _buildFrostedCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    double size = 42,
    bool isActive = false,
  }) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.amberAccent.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
            ),
            child: Icon(icon, color: isActive ? Colors.amberAccent : Colors.white, size: size * 0.52),
          ),
        ),
      ),
    );
  }

  IconData _getFlashIcon() {
    switch (_flashMode) {
      case FlashMode.off:
        return Icons.flash_off_rounded;
      case FlashMode.auto:
        return Icons.flash_auto_rounded;
      case FlashMode.always:
        return Icons.flash_on_rounded;
      case FlashMode.torch:
        return Icons.flashlight_on_rounded;
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }
}

class GridPainter extends CustomPainter {
  final GridType type;
  GridPainter(this.type);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white30
      ..strokeWidth = 1.0;

    switch (type) {
      case GridType.thirds:
        canvas.drawLine(Offset(size.width / 3, 0), Offset(size.width / 3, size.height), paint);
        canvas.drawLine(Offset(size.width * 2 / 3, 0), Offset(size.width * 2 / 3, size.height), paint);
        canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), paint);
        canvas.drawLine(Offset(0, size.height * 2 / 3), Offset(size.width, size.height * 2 / 3), paint);
        break;
      case GridType.golden:
        const phi = 1.618;
        final w = size.width / phi;
        final h = size.height / phi;
        canvas.drawLine(Offset(w, 0), Offset(w, size.height), paint);
        canvas.drawLine(Offset(size.width - w, 0), Offset(size.width - w, size.height), paint);
        canvas.drawLine(Offset(0, h), Offset(size.width, h), paint);
        canvas.drawLine(Offset(0, size.height - h), Offset(size.width, size.height - h), paint);
        break;
      case GridType.crosshair:
        canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), paint);
        canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
        canvas.drawCircle(Offset(size.width / 2, size.height / 2), 30, paint..style = PaintingStyle.stroke);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) => oldDelegate.type != type;
}