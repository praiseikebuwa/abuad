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
import 'package:audioplayers/audioplayers.dart';

import '../../../core/theme/app_colors.dart';
import '../../music/domain/audio_track.dart';
import '../../music/presentation/music_picker_sheet.dart';
import 'media_editor_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LensType {
  colorFilter,
  arFaceLens,
}

class CameraLensEffect {
  final String id;
  final String name;
  final String category;
  final IconData icon;
  final List<Color> previewGradient;
  final List<double>? colorMatrix;
  final LensType type;
  final String? arType;

  const CameraLensEffect({
    required this.id,
    required this.name,
    required this.category,
    required this.icon,
    required this.previewGradient,
    this.colorMatrix,
    this.type = LensType.colorFilter,
    this.arType,
  });

  bool get isAr => type == LensType.arFaceLens;
}

enum CameraMode { photo, video }
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
  AudioPlayer? _bgMusicPlayer;

  // Real-time Aesthetic Lenses & Effects
  CameraLensEffect? _selectedLens;
  bool _showLensesCarousel = false;
  String? _attachedLink;
  int? _snapDurationSeconds;

  static const List<CameraLensEffect> _builtinLenses = [
    CameraLensEffect(
      id: 'none',
      name: 'Original',
      category: 'Natural',
      icon: Icons.block_rounded,
      previewGradient: [Color(0xFF4B5563), Color(0xFF1F2937)],
      colorMatrix: null,
    ),
    // --- Real Snapchat AR Face Lenses ---
    CameraLensEffect(
      id: 'ar_dog',
      name: 'Puppy Dog 🐶',
      category: 'Snapchat AR',
      icon: Icons.pets_rounded,
      previewGradient: [Color(0xFFB45309), Color(0xFFF59E0B)],
      type: LensType.arFaceLens,
      arType: 'dog',
    ),
    CameraLensEffect(
      id: 'ar_bunny',
      name: 'Bunny Ears 🐰',
      category: 'Snapchat AR',
      icon: Icons.cruelty_free_rounded,
      previewGradient: [Color(0xFFEC4899), Color(0xFFFDA4AF)],
      type: LensType.arFaceLens,
      arType: 'bunny',
    ),
    CameraLensEffect(
      id: 'ar_crown',
      name: 'Golden Crown 👑',
      category: 'Snapchat AR',
      icon: Icons.emoji_events_rounded,
      previewGradient: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
      type: LensType.arFaceLens,
      arType: 'golden_crown',
    ),
    CameraLensEffect(
      id: 'ar_cyber',
      name: 'Cyber Visor 🕶️',
      category: 'Snapchat AR',
      icon: Icons.remove_red_eye_rounded,
      previewGradient: [Color(0xFF06B6D4), Color(0xFF8B5CF6)],
      type: LensType.arFaceLens,
      arType: 'cyber_visor',
    ),
    CameraLensEffect(
      id: 'ar_hearts',
      name: 'Heart Blush 🥰',
      category: 'Snapchat AR',
      icon: Icons.favorite_rounded,
      previewGradient: [Color(0xFFF43F5E), Color(0xFFFB7185)],
      type: LensType.arFaceLens,
      arType: 'heart_blush',
    ),
    CameraLensEffect(
      id: 'ar_angel',
      name: 'Angel Halo 😇',
      category: 'Snapchat AR',
      icon: Icons.brightness_5_rounded,
      previewGradient: [Color(0xFF38BDF8), Color(0xFFE0F2FE)],
      type: LensType.arFaceLens,
      arType: 'angel_halo',
    ),
    CameraLensEffect(
      id: 'ar_butterflies',
      name: 'Butterflies 🦋',
      category: 'Snapchat AR',
      icon: Icons.flutter_dash_rounded,
      previewGradient: [Color(0xFF10B981), Color(0xFF6EE7B7)],
      type: LensType.arFaceLens,
      arType: 'butterflies',
    ),
    CameraLensEffect(
      id: 'ar_devil',
      name: 'Neon Horns 😈',
      category: 'Snapchat AR',
      icon: Icons.local_fire_department_rounded,
      previewGradient: [Color(0xFFEF4444), Color(0xFF991B1B)],
      type: LensType.arFaceLens,
      arType: 'devil_horns',
    ),
    // --- Aesthetic Color Grading Filters ---
    CameraLensEffect(
      id: 'golden',
      name: 'Golden Hour',
      category: 'Aesthetic',
      icon: Icons.wb_sunny_rounded,
      previewGradient: [Color(0xFFFF9900), Color(0xFFFF5E36)],
      colorMatrix: [
        1.20, 0.05, 0.00, 0.00, 15.0,
        0.05, 1.08, 0.00, 0.00, 8.0,
        0.00, 0.00, 0.82, 0.00, -12.0,
        0.00, 0.00, 0.00, 1.00, 0.0,
      ],
    ),
    CameraLensEffect(
      id: 'noir',
      name: 'Noir B&W',
      category: 'Classic',
      icon: Icons.filter_b_and_w_rounded,
      previewGradient: [Color(0xFF374151), Color(0xFF111827)],
      colorMatrix: [
        0.33, 0.59, 0.11, 0.00, -5.0,
        0.33, 0.59, 0.11, 0.00, -5.0,
        0.33, 0.59, 0.11, 0.00, -5.0,
        0.00, 0.00, 0.00, 1.00, 0.0,
      ],
    ),
    CameraLensEffect(
      id: 'cyberpunk',
      name: 'Cyberpunk',
      category: 'Vibrant',
      icon: Icons.electric_bolt_rounded,
      previewGradient: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
      colorMatrix: [
        1.25, 0.00, 0.35, 0.00, 20.0,
        0.00, 0.90, 0.15, 0.00, -8.0,
        0.30, 0.00, 1.45, 0.00, 35.0,
        0.00, 0.00, 0.00, 1.00, 0.0,
      ],
    ),
    CameraLensEffect(
      id: 'vintage',
      name: "Vintage '90s",
      category: 'Retro',
      icon: Icons.camera_roll_rounded,
      previewGradient: [Color(0xFFD97706), Color(0xFF78350F)],
      colorMatrix: [
        1.08, 0.02, 0.00, 0.00, 16.0,
        0.02, 1.02, 0.00, 0.00, 10.0,
        0.00, 0.00, 0.82, 0.00, -10.0,
        0.00, 0.00, 0.00, 1.00, 0.0,
      ],
    ),
    CameraLensEffect(
      id: 'beauty',
      name: 'Soft Beauty',
      category: 'Beauty',
      icon: Icons.face_retouching_natural_rounded,
      previewGradient: [Color(0xFFF472B6), Color(0xFFFDA4AF)],
      colorMatrix: [
        1.12, 0.00, 0.00, 0.00, 18.0,
        0.00, 1.06, 0.00, 0.00, 12.0,
        0.00, 0.00, 1.04, 0.00, 12.0,
        0.00, 0.00, 0.00, 1.00, 0.0,
      ],
    ),
    CameraLensEffect(
      id: 'aqua',
      name: 'Aqua Marine',
      category: 'Cinematic',
      icon: Icons.water_drop_rounded,
      previewGradient: [Color(0xFF0D9488), Color(0xFF0284C7)],
      colorMatrix: [
        1.08, 0.00, 0.00, 0.00, 4.0,
        0.00, 1.18, 0.10, 0.00, 12.0,
        0.00, 0.15, 1.30, 0.00, 24.0,
        0.00, 0.00, 0.00, 1.00, 0.0,
      ],
    ),
    CameraLensEffect(
      id: 'emerald',
      name: 'Emerald Lush',
      category: 'Nature',
      icon: Icons.forest_rounded,
      previewGradient: [Color(0xFF059669), Color(0xFF047857)],
      colorMatrix: [
        0.88, 0.10, 0.00, 0.00, -8.0,
        0.00, 1.28, 0.00, 0.00, 18.0,
        0.00, 0.10, 0.90, 0.00, -2.0,
        0.00, 0.00, 0.00, 1.00, 0.0,
      ],
    ),
    CameraLensEffect(
      id: 'crimson',
      name: 'Crimson Mood',
      category: 'Aesthetic',
      icon: Icons.favorite_rounded,
      previewGradient: [Color(0xFFE11D48), Color(0xFF881337)],
      colorMatrix: [
        1.30, 0.00, 0.15, 0.00, 22.0,
        0.00, 0.92, 0.08, 0.00, -4.0,
        0.10, 0.00, 1.12, 0.00, 12.0,
        0.00, 0.00, 0.00, 1.00, 0.0,
      ],
    ),
    CameraLensEffect(
      id: 'pop',
      name: 'Vibrant Pop',
      category: 'Vibrant',
      icon: Icons.palette_rounded,
      previewGradient: [Color(0xFFEC4899), Color(0xFFF59E0B)],
      colorMatrix: [
        1.25, -0.10, -0.10, 0.00, 0.0,
        -0.10, 1.25, -0.10, 0.00, 0.0,
        -0.10, -0.10, 1.25, 0.00, 0.0,
        0.00, 0.00, 0.00, 1.00, 0.0,
      ],
    ),
    CameraLensEffect(
      id: 'sepia',
      name: 'Sepia Dream',
      category: 'Retro',
      icon: Icons.history_edu_rounded,
      previewGradient: [Color(0xFFB45309), Color(0xFF78350F)],
      colorMatrix: [
        0.393, 0.769, 0.189, 0.00, 0.0,
        0.349, 0.686, 0.168, 0.00, 0.0,
        0.272, 0.534, 0.131, 0.00, 0.0,
        0.000, 0.000, 0.000, 1.00, 0.0,
      ],
    ),
    CameraLensEffect(
      id: 'moonlight',
      name: 'Moonlight',
      category: 'Cinematic',
      icon: Icons.nightlight_round,
      previewGradient: [Color(0xFF3B82F6), Color(0xFF1E1B4B)],
      colorMatrix: [
        0.85, 0.00, 0.10, 0.00, -10.0,
        0.00, 0.95, 0.15, 0.00, 0.0,
        0.10, 0.15, 1.35, 0.00, 25.0,
        0.00, 0.00, 0.00, 1.00, 0.0,
      ],
    ),
  ];

  // Lifecycle & disposal guard
  bool _isDisposed = false;

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
  Offset? _focusPoint;

  // Gallery Asset
  Uint8List? _latestGallerImage;

  // Snapchat Lenses (CameraKit)
  late final _cameraKitFlutterImpl = CameraKitFlutterImpl(cameraKitFlutterEvents: this);
  static const String _snapLensGroupId = '4b594445-eaf3-46cd-8626-fae099b74079';
  static const String _snapWebProductionToken =
      'eyJhbGciOiJIUzI1NiIsImtpZCI6IkNhbnZhc1MyU0hNQUNQcm9kIiwidHlwIjoiSldUIn0.eyJhdWQiOiJjYW52YXMtY2FudmFzYXBpIiwiaXNzIjoiY2FudmFzLXMyc3Rva2VuIiwibmJmIjoxNzkzMDM3MTc5LCJzdWIiOiI5NzYwZjY0ZS00YzQ5LTQ3MDAtYWY2Ny03OTI0MjBjNTVkNWR-UFJPRFVDVElPTn4zYTYyNmFjZi1jYjQyLTQzYzQtYmQ3ZS1lMGY5Y2E0N2IwMDAifQ.YTBGQ4kQdAv40TkAUzbNGqtmtSFzL3I4PWyrWjbrWGA';
  static const String _snapWebStagingToken =
      'eyJhbGciOiJIUzI1NiIsImtpZCI6IkNhbnZhc1MyU0hNQUNQcm9kIiwidHlwIjoiSldUIn0.eyJhdWQiOiJjYW52YXMtY2FudmFzYXBpIiwiaXNzIjoiY2FudmFzLXMyc3Rva2VuIiwibmJmIjoxNzkzMDM3MTc5LCJzdWIiOiI5NzYwZjY0ZS00YzQ5LTQ3MDAtYWY2Ny03OTI0MjBjNTVkNWR-U1RBR0lOR35jYjI5ZjBmNS01MTY3LTRmNjgtOWQ4Ny1jYmM0OWQ3NGNjMDQifQ.OLtrkZew0oVv_QNj1ddw-arhFmgSA7QEjwclu--CFB4';
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
    _isDisposed = true;
    _isCameraInitialized = false;
    WidgetsBinding.instance.removeObserver(this);
    _focusTimer?.cancel();
    _recordingTimer?.cancel();
    _countdownTimer?.cancel();
    _pulseController.dispose();
    _stopBackgroundMusic();
    _bgMusicPlayer?.dispose();
    final controller = _controller;
    _controller = null;
    controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // On Web, browser tabs and permission dialogs fire inactive/paused events constantly;
    // do not destroy/release the camera controller on web!
    if (kIsWeb) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _stopBackgroundMusic();
      _releaseCamera();
    } else if (state == AppLifecycleState.resumed) {
      _restoreCamera();
      if (_selectedAudioTrack != null) {
        _playBackgroundMusic(_selectedAudioTrack!);
      }
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
      if (kIsWeb) {
        _cameras = await availableCameras();
        if (_cameras.isNotEmpty) {
          final frontIndex = _cameras.indexWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
          );
          _selectedCameraIndex = frontIndex != -1 ? frontIndex : 0;
          await _onNewCameraSelected(_cameras[_selectedCameraIndex]);
        } else {
          if (mounted) setState(() => _isCameraInitialized = false);
        }
        return;
      }

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
    if (_isDisposed) return;
    if (_isCameraInitializing) return;
    _isCameraInitializing = true;

    final oldController = _controller;
    _controller = null;
    if (mounted) setState(() => _isCameraInitialized = false);
    if (oldController != null) {
      try {
        await oldController.dispose();
      } catch (_) {}
    }

    if (_isDisposed || !mounted) {
      _isCameraInitializing = false;
      return;
    }

    final CameraController cameraController = CameraController(
      cameraDescription,
      _resolutionPreset,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await cameraController.initialize();
      if (_isDisposed || !mounted) {
        await cameraController.dispose();
        _isCameraInitializing = false;
        return;
      }

      cameraController.addListener(() {
        if (mounted && !_isDisposed) setState(() {});
        if (cameraController.value.hasError) {
          debugPrint('Camera error: ${cameraController.value.errorDescription}');
        }
      });

      if (!kIsWeb) {
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
      } else {
        _minZoom = 1.0;
        _maxZoom = 4.0;
        _currentZoom = 1.0;
      }

      if (mounted && !_isDisposed) {
        setState(() {
          _isCameraInitialized = true;
          _controller = cameraController;
        });
      } else {
        await cameraController.dispose();
      }
    } catch (e) {
      debugPrint('Error initializing camera controller: $e');
      if (mounted && !_isDisposed) {
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

  Future<void> _toggleFlash() async {
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Flash/Torch is not available on webcams'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    if (_controller == null || !_controller!.value.isInitialized) return;
    HapticFeedback.lightImpact();
    final nextMode = _flashMode == FlashMode.off
        ? FlashMode.auto
        : _flashMode == FlashMode.auto
            ? FlashMode.always
            : (_flashMode == FlashMode.always && !kIsWeb)
                ? FlashMode.torch
                : FlashMode.off;
    try {
      await _controller?.setFlashMode(nextMode);
      if (mounted) setState(() => _flashMode = nextMode);
    } catch (e) {
      debugPrint('Flash mode not supported: $e');
      try {
        await _controller?.setFlashMode(FlashMode.off);
        if (mounted) setState(() => _flashMode = FlashMode.off);
      } catch (_) {}
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
    if (!kIsWeb) {
      try {
        _controller?.setZoomLevel(clamped);
      } catch (_) {}
    }
    HapticFeedback.selectionClick();
  }

  void _toggleLensesCarousel() {
    HapticFeedback.lightImpact();
    setState(() {
      _showLensesCarousel = !_showLensesCarousel;
    });
  }

  Future<void> _capturePhotoWithInitialTool(String tool) async {
    final controller = _controller;
    if (!_isCameraInitialized || _isRecording || _isCaptureOperationInProgress || controller == null || !controller.value.isInitialized) {
      return;
    }
    _isCaptureOperationInProgress = true;
    HapticFeedback.mediumImpact();
    try {
      final XFile file = await controller.takePicture();
      _handleMediaCapture(file, CameraMode.photo, initialTool: tool);
    } catch (e) {
      debugPrint('Error capturing photo for tool $tool: $e');
    } finally {
      _isCaptureOperationInProgress = false;
    }
  }

  void _openDurationSelector() {
    HapticFeedback.lightImpact();
    final durations = [
      (1, '1s'),
      (2, '2s'),
      (3, '3s'),
      (5, '5s'),
      (10, '10s'),
      (null, 'No Limit (∞)'),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.8),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: Colors.white24, width: 0.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.av_timer_rounded, color: AppColors.secondaryTeal, size: 22),
                    SizedBox(width: 8),
                    Text('Snap View Duration', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                const Text('Choose how long recipients can view your snap', style: TextStyle(color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: durations.map((d) {
                    final isSelected = _snapDurationSeconds == d.$1;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _snapDurationSeconds = d.$1);
                        Navigator.pop(ctx);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.secondaryTeal : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? AppColors.secondaryTeal : Colors.white24,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          d.$2,
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openLinkAttachmentDialog() {
    HapticFeedback.lightImpact();
    final textController = TextEditingController(text: _attachedLink ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white24),
        ),
        title: const Row(
          children: [
            Icon(Icons.link_rounded, color: AppColors.secondaryTeal),
            SizedBox(width: 10),
            Text('Attach Link', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add a website URL or link for friends to swipe up on your snap.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: textController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                hintText: 'https://...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.secondaryTeal)),
              ),
            ),
          ],
        ),
        actions: [
          if (_attachedLink != null)
            TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _attachedLink = null);
                Navigator.pop(ctx);
              },
              child: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondaryTeal,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final raw = textController.text.trim();
              if (raw.isNotEmpty) {
                final formatted = (raw.startsWith('http://') || raw.startsWith('https://')) ? raw : 'https://$raw';
                setState(() => _attachedLink = formatted);
              } else {
                setState(() => _attachedLink = null);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Attach', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _openLensesSearchSheet() {
    HapticFeedback.lightImpact();
    String searchQuery = '';
    int selectedTab = 0; // 0: All, 1: Snapchat AR, 2: Color Filters

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final filtered = _builtinLenses.where((lens) {
            if (selectedTab == 1 && !lens.isAr) return false;
            if (selectedTab == 2 && (lens.isAr || lens.id == 'none')) return false;

            if (searchQuery.isEmpty) return true;
            return lens.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                lens.category.toLowerCase().contains(searchQuery.toLowerCase());
          }).toList();

          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.72,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.88),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border.all(color: Colors.white24, width: 0.5),
                ),
                child: Column(
                  children: [
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 12),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome, color: Color(0xFFFFFC00), size: 20),
                        SizedBox(width: 8),
                        Text('Snapchat AR & Camera Lenses', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Tabs: All | ✨ Snapchat AR | 🎨 Color Filters
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildLensTab(
                            title: 'All (${_builtinLenses.length})',
                            isSelected: selectedTab == 0,
                            onTap: () => setSheetState(() => selectedTab = 0),
                          ),
                          const SizedBox(width: 8),
                          _buildLensTab(
                            title: '✨ Snapchat AR (${_builtinLenses.where((l) => l.isAr).length})',
                            isSelected: selectedTab == 1,
                            accentColor: const Color(0xFFFFFC00),
                            textColor: selectedTab == 1 ? Colors.black : Colors.white,
                            onTap: () => setSheetState(() => selectedTab = 1),
                          ),
                          const SizedBox(width: 8),
                          _buildLensTab(
                            title: '🎨 Color Filters (${_builtinLenses.where((l) => !l.isAr && l.id != 'none').length})',
                            isSelected: selectedTab == 2,
                            onTap: () => setSheetState(() => selectedTab = 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, color: Colors.white60),
                        hintText: 'Search AR lenses & effects...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.1),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                      onChanged: (q) {
                        setSheetState(() => searchQuery = q);
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.95,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final lens = filtered[i];
                          final isSelected = _selectedLens?.id == lens.id || (_selectedLens == null && lens.id == 'none');
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _selectedLens = lens.id == 'none' ? null : lens;
                                _showLensesCarousel = true;
                              });
                              Navigator.pop(ctx);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: lens.previewGradient,
                                ),
                                border: Border.all(
                                  color: isSelected ? Colors.white : Colors.white24,
                                  width: isSelected ? 2.5 : 1,
                                ),
                              ),
                              padding: const EdgeInsets.all(8),
                              child: Stack(
                                children: [
                                  Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(lens.icon, color: Colors.white, size: 26),
                                        const SizedBox(height: 6),
                                        Text(
                                          lens.name,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          lens.category,
                                          style: const TextStyle(color: Colors.white70, fontSize: 10),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (lens.isAr)
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFFC00),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'AR',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFFC00),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        elevation: 4,
                      ),
                      icon: const Icon(Icons.auto_awesome, size: 18, color: Colors.black),
                      label: const Text(
                        'Launch Snapchat AR Face Lenses',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openSnapchatLenses();
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLensTab({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    Color? accentColor,
    Color? textColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (accentColor ?? AppColors.secondaryTeal)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (accentColor ?? AppColors.secondaryTeal)
                : Colors.white24,
            width: 1,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? (textColor ?? Colors.white) : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _openSnapchatLenses() async {
    HapticFeedback.mediumImpact();
    final firstArLens = _builtinLenses.firstWhere(
      (l) => l.isAr,
      orElse: () => _builtinLenses[1],
    );
    setState(() {
      _showLensesCarousel = true;
      _selectedLens = firstArLens;
    });

    if (kIsWeb) {
      debugPrint('Initializing Web Camera Kit with token: $_snapWebProductionToken (staging backup: $_snapWebStagingToken)');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1E293B),
            content: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFFFFFC00), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '✨ ${firstArLens.name} active! Swipe carousel to try all AR lenses.',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    try {
      HapticFeedback.mediumImpact();
      // Safely pause camera stream to avoid hardware conflict crash on Android
      await _controller?.pausePreview();
      await _cameraKitFlutterImpl.openCameraKit(
        groupIds: [_snapLensGroupId],
        isHideCloseButton: false,
      );
    } catch (e) {
      debugPrint('Error launching Snapchat Camera Kit: $e');
      if (mounted) {
        _openLensesSearchSheet();
      }
    } finally {
      if (mounted) {
        try {
          await _controller?.resumePreview();
        } catch (_) {}
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

  void _handleMediaCapture(
    XFile file,
    CameraMode mode, {
    String? initialTool,
    String? attachedLink,
    int? snapDurationSeconds,
  }) async {
    _stopBackgroundMusic();
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
          initialTool: initialTool,
          attachedLink: attachedLink ?? _attachedLink,
          snapDurationSeconds: snapDurationSeconds ?? _snapDurationSeconds,
          colorMatrix: _selectedLens?.colorMatrix,
        ),
      ),
    );
    if (result != null && mounted) {
      Navigator.of(context).pop(result);
    } else if (mounted && _selectedAudioTrack != null) {
      _playBackgroundMusic(_selectedAudioTrack!);
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
      _playBackgroundMusic(track);
    }
  }

  Future<void> _playBackgroundMusic(AudioTrack track) async {
    try {
      _bgMusicPlayer ??= AudioPlayer();
      await _bgMusicPlayer!.stop();
      await _bgMusicPlayer!.setReleaseMode(ReleaseMode.loop);
      await _bgMusicPlayer!.play(UrlSource(track.audioUrl));
    } catch (e) {
      debugPrint('Error playing background audio on camera: $e');
    }
  }

  Future<void> _stopBackgroundMusic() async {
    try {
      await _bgMusicPlayer?.stop();
    } catch (_) {}
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
                if (!kIsWeb) {
                  _controller?.setZoomLevel(newZoom);
                }
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
                                      _stopBackgroundMusic();
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
                              activeColor: AppColors.secondaryTeal,
                              onTap: _toggleTimerMode,
                            ),
                            const SizedBox(height: 10),
                            Container(width: 20, height: 1, color: Colors.white24),
                            const SizedBox(height: 10),
                            // Text Tool (Aa)
                            _buildToolbarIcon(
                              label: 'Aa',
                              onTap: () => _capturePhotoWithInitialTool('text'),
                            ),
                            const SizedBox(height: 12),
                            // Pen / Draw Tool
                            _buildToolbarIcon(
                              icon: Icons.edit_outlined,
                              onTap: () => _capturePhotoWithInitialTool('draw'),
                            ),
                            const SizedBox(height: 12),
                            // Sticker Tool
                            _buildToolbarIcon(
                              icon: Icons.sticky_note_2_outlined,
                              onTap: () => _capturePhotoWithInitialTool('sticker'),
                            ),
                            const SizedBox(height: 12),
                            // Paperclip Link Tool
                            _buildToolbarIcon(
                              icon: Icons.link_rounded,
                              isActive: _attachedLink != null,
                              activeColor: AppColors.secondaryTeal,
                              onTap: _openLinkAttachmentDialog,
                            ),
                            const SizedBox(height: 12),
                            // Stopwatch Duration
                            _buildToolbarIcon(
                              icon: Icons.av_timer_rounded,
                              isActive: _snapDurationSeconds != null,
                              activeColor: AppColors.secondaryTeal,
                              onTap: _openDurationSelector,
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

                  // Lenses / Effects Horizontal Carousel ("cycle cycle cycle")
                  if (_showLensesCarousel) ...[
                    _buildLensesCarousel(),
                    const SizedBox(height: 12),
                  ],

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
                          onTap: _toggleLensesCarousel,
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
                                      color: _showLensesCarousel || _selectedLens != null
                                          ? AppColors.secondaryTeal.withValues(alpha: 0.35)
                                          : Colors.black.withValues(alpha: 0.35),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: _showLensesCarousel || _selectedLens != null
                                            ? AppColors.secondaryTeal
                                            : Colors.white30,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.sentiment_satisfied_alt_rounded,
                                      color: _showLensesCarousel || _selectedLens != null
                                          ? AppColors.secondaryTeal
                                          : Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _selectedLens != null ? _selectedLens!.name : 'Lenses',
                                style: TextStyle(
                                  color: _selectedLens != null ? AppColors.secondaryTeal : Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
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
    final controller = _controller;
    if (_isDisposed || !_isCameraInitialized || controller == null || !controller.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      );
    }

    final previewSize = controller.value.previewSize;
    // On web, webcam previewSize is already in standard orientation (width x height)
    // On native mobile (Android/iOS), camera sensors are 90deg rotated, so height is width
    final double previewWidth;
    final double previewHeight;
    if (previewSize != null) {
      if (kIsWeb) {
        previewWidth = previewSize.width;
        previewHeight = previewSize.height;
      } else {
        previewWidth = previewSize.height;
        previewHeight = previewSize.width;
      }
    } else {
      previewWidth = screenSize.width;
      previewHeight = screenSize.height;
    }

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

    Widget cameraTexture = CameraPreview(controller);
    // CRITICAL: On Flutter Web, wrapping HtmlElementView in ColorFiltered blanks out the video feed completely!
    // Only wrap with ColorFiltered on native mobile platforms.
    if (!kIsWeb && _selectedLens?.colorMatrix != null) {
      cameraTexture = ColorFiltered(
        colorFilter: ColorFilter.matrix(_selectedLens!.colorMatrix!),
        child: cameraTexture,
      );
    }

    return Container(
      color: Colors.black,
      width: screenSize.width,
      height: screenSize.height,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
          width: targetWidth,
          height: targetHeight,
          decoration: BoxDecoration(
            borderRadius: _aspectRatio != CameraAspectRatio.full
                ? BorderRadius.circular(20)
                : BorderRadius.zero,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              SizedBox(
                width: targetWidth,
                height: targetHeight,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: previewWidth,
                    height: previewHeight,
                    child: cameraTexture,
                  ),
                ),
              ),
              // On web, overlay the aesthetic tint gracefully on top of the camera stream
              if (kIsWeb && _selectedLens != null && !_selectedLens!.isAr)
                _buildWebLensOverlay(_selectedLens!),
              // Live Interactive Snapchat AR Face Lens Overlay (Web & Mobile!)
              if (_selectedLens != null && _selectedLens!.isAr)
                _buildArOverlay(_selectedLens!, Size(targetWidth, targetHeight), isFrontCamera),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArOverlay(CameraLensEffect lens, Size viewSize, bool isFrontCamera) {
    return Positioned.fill(
      child: IgnorePointer(
        child: SizedBox(
          width: viewSize.width,
          height: viewSize.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              switch (lens.arType) {
                'dog' => _buildDogArFilter(viewSize),
                'bunny' => _buildBunnyArFilter(viewSize),
                'golden_crown' => _buildCrownArFilter(viewSize),
                'cyber_visor' => _buildCyberVisorArFilter(viewSize),
                'heart_blush' => _buildHeartBlushArFilter(viewSize),
                'angel_halo' => _buildAngelHaloArFilter(viewSize),
                'butterflies' => _buildButterfliesArFilter(viewSize),
                'devil_horns' => _buildDevilHornsArFilter(viewSize),
                _ => const SizedBox.shrink(),
              },
            ],
          ),
        ),
      ),
    );
  }

  // 1. Classic Snapchat Puppy Dog AR Filter (Ears, Nose & Animated Tongue)
  Widget _buildDogArFilter(Size viewSize) {
    return Stack(
      children: [
        // Left Floppy Dog Ear
        Positioned(
          top: viewSize.height * 0.08,
          left: viewSize.width * 0.16,
          child: Transform.rotate(
            angle: -0.3,
            child: Container(
              width: 75,
              height: 110,
              decoration: BoxDecoration(
                color: const Color(0xFF8D5B28),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(50),
                  bottom: Radius.circular(40),
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(-3, 6)),
                ],
              ),
              child: Center(
                child: Container(
                  width: 45,
                  height: 75,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD49A6A),
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
          )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .rotate(duration: 900.ms, begin: -0.04, end: 0.04)
              .moveY(duration: 700.ms, begin: -3, end: 3),
        ),
        // Right Floppy Dog Ear
        Positioned(
          top: viewSize.height * 0.08,
          right: viewSize.width * 0.16,
          child: Transform.rotate(
            angle: 0.3,
            child: Container(
              width: 75,
              height: 110,
              decoration: BoxDecoration(
                color: const Color(0xFF8D5B28),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(50),
                  bottom: Radius.circular(40),
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(3, 6)),
                ],
              ),
              child: Center(
                child: Container(
                  width: 45,
                  height: 75,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD49A6A),
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
          )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .rotate(duration: 900.ms, begin: 0.04, end: -0.04)
              .moveY(duration: 700.ms, begin: -3, end: 3),
        ),
        // Puppy Dog Nose with White Highlight & Whiskers
        Positioned(
          top: viewSize.height * 0.36,
          left: (viewSize.width / 2) - 45,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                    bottom: Radius.circular(24),
                  ),
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 3))],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 8,
                      left: 20,
                      child: Container(
                        width: 24,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Cute Animated Panting Dog Tongue
              Container(
                width: 38,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5376),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
                  border: Border.all(color: const Color(0xFFD81B60), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 3)),
                  ],
                ),
                child: Center(
                  child: Container(width: 2, height: 26, color: const Color(0xFFD81B60)),
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat(reverse: true))
                  .scaleY(duration: 500.ms, begin: 0.85, end: 1.15)
                  .moveY(duration: 500.ms, begin: -2, end: 4),
            ],
          ),
        ),
      ],
    );
  }

  // 2. Cute Bunny Ears & Heart Nose
  Widget _buildBunnyArFilter(Size viewSize) {
    return Stack(
      children: [
        // Bunny Ears
        Positioned(
          top: viewSize.height * 0.04,
          left: (viewSize.width / 2) - 80,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Left Ear
              Transform.rotate(
                angle: -0.12,
                child: Container(
                  width: 48,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(35),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFAEC9),
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat(reverse: true))
                  .rotate(duration: 800.ms, begin: -0.06, end: 0.06),
              const SizedBox(width: 40),
              // Right Ear
              Transform.rotate(
                angle: 0.12,
                child: Container(
                  width: 48,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(35),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFAEC9),
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat(reverse: true))
                  .rotate(duration: 800.ms, begin: 0.06, end: -0.06),
            ],
          ),
        ),
        // Pink Anime Cheek Blush Left
        Positioned(
          top: viewSize.height * 0.38,
          left: viewSize.width * 0.22,
          child: Container(
            width: 50,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF4081).withValues(alpha: 0.35),
            ),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true)).scale(duration: 1200.ms, begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1)),
        ),
        // Pink Anime Cheek Blush Right
        Positioned(
          top: viewSize.height * 0.38,
          right: viewSize.width * 0.22,
          child: Container(
            width: 50,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF4081).withValues(alpha: 0.35),
            ),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true)).scale(duration: 1200.ms, begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1)),
        ),
        // Bunny Pink Heart Nose
        Positioned(
          top: viewSize.height * 0.36,
          left: (viewSize.width / 2) - 18,
          child: const Icon(Icons.favorite_rounded, color: Color(0xFFFF4081), size: 36),
        ),
      ],
    );
  }

  // 3. Royal Golden Crown with Twinkling Sparkles
  Widget _buildCrownArFilter(Size viewSize) {
    return Stack(
      children: [
        Positioned(
          top: viewSize.height * 0.07,
          left: (viewSize.width / 2) - 75,
          child: Container(
            width: 150,
            height: 90,
            decoration: const BoxDecoration(
              boxShadow: [
                BoxShadow(color: Color(0x80F59E0B), blurRadius: 28, spreadRadius: 4),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  color: Color(0xFFFFD700),
                  size: 96,
                ),
                Positioned(
                  top: 10,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
                      const SizedBox(width: 14),
                      Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle)),
                      const SizedBox(width: 14),
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                    ],
                  ),
                ),
              ],
            ),
          )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .moveY(duration: 1400.ms, begin: -6, end: 6)
              .shimmer(duration: 1800.ms, color: Colors.white),
        ),
        // Twinkling Sparkle Stars
        Positioned(
          top: viewSize.height * 0.12,
          left: viewSize.width * 0.18,
          child: const Icon(Icons.auto_awesome, color: Color(0xFFFFE082), size: 28)
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(duration: 600.ms, begin: const Offset(0.6, 0.6), end: const Offset(1.2, 1.2))
              .rotate(duration: 2000.ms),
        ),
        Positioned(
          top: viewSize.height * 0.09,
          right: viewSize.width * 0.18,
          child: const Icon(Icons.auto_awesome, color: Color(0xFFFFE082), size: 32)
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(duration: 800.ms, begin: const Offset(0.7, 0.7), end: const Offset(1.3, 1.3))
              .rotate(duration: 2500.ms),
        ),
      ],
    );
  }

  // 4. Futuristic Cyber Visor with Neon HUD & Targeting Reticle
  Widget _buildCyberVisorArFilter(Size viewSize) {
    return Stack(
      children: [
        // Visor Bar across eyes
        Positioned(
          top: viewSize.height * 0.27,
          left: viewSize.width * 0.12,
          right: viewSize.width * 0.12,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF06B6D4).withValues(alpha: 0.35),
                      const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF00F0FF), width: 2),
                  boxShadow: const [
                    BoxShadow(color: Color(0x8000F0FF), blurRadius: 16, spreadRadius: 2),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('SYS: AR_ONLINE', style: TextStyle(color: Color(0xFF00F0FF), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        Text('FOV: 120° // TRACK: LOCK', style: TextStyle(color: Colors.white70, fontSize: 9)),
                      ],
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF00F0FF), width: 1.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.filter_center_focus, color: Color(0xFF00F0FF), size: 18),
                      ),
                    ).animate(onPlay: (controller) => controller.repeat()).rotate(duration: 3000.ms),
                    const Text('ABUAD HUD v2.5', style: TextStyle(color: Color(0xFFFF007F), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  ],
                ),
              ),
            ),
          )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .shimmer(duration: 1500.ms, color: const Color(0xFF00F0FF)),
        ),
      ],
    );
  }

  // 5. Floating Heart Blush & Anime Freckles
  Widget _buildHeartBlushArFilter(Size viewSize) {
    return Stack(
      children: [
        // Rosy Cheeks
        Positioned(
          top: viewSize.height * 0.37,
          left: viewSize.width * 0.18,
          child: Container(
            width: 60,
            height: 35,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF1493).withValues(alpha: 0.28),
            ),
          ),
        ),
        Positioned(
          top: viewSize.height * 0.37,
          right: viewSize.width * 0.18,
          child: Container(
            width: 60,
            height: 35,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF1493).withValues(alpha: 0.28),
            ),
          ),
        ),
        // Floating Animated Hearts Rising
        Positioned(
          top: viewSize.height * 0.28,
          left: viewSize.width * 0.24,
          child: const Icon(Icons.favorite, color: Color(0xFFFF3366), size: 26)
              .animate(onPlay: (controller) => controller.repeat())
              .moveY(duration: 2000.ms, begin: 20, end: -60)
              .fadeOut(duration: 2000.ms),
        ),
        Positioned(
          top: viewSize.height * 0.24,
          right: viewSize.width * 0.22,
          child: const Icon(Icons.favorite, color: Color(0xFFFF6699), size: 32)
              .animate(onPlay: (controller) => controller.repeat())
              .moveY(duration: 2200.ms, begin: 30, end: -70)
              .fadeOut(duration: 2200.ms),
        ),
        Positioned(
          top: viewSize.height * 0.32,
          left: viewSize.width * 0.46,
          child: const Icon(Icons.favorite, color: Color(0xFFFF0066), size: 22)
              .animate(onPlay: (controller) => controller.repeat())
              .moveY(duration: 1800.ms, begin: 10, end: -50)
              .fadeOut(duration: 1800.ms),
        ),
      ],
    );
  }

  // 6. Glowing Angel Halo & Heavenly Drifting Feathers
  Widget _buildAngelHaloArFilter(Size viewSize) {
    return Stack(
      children: [
        Positioned(
          top: viewSize.height * 0.06,
          left: (viewSize.width / 2) - 80,
          child: Container(
            width: 160,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFFFFEA00), width: 7),
              boxShadow: const [
                BoxShadow(color: Color(0xFFFFEA00), blurRadius: 28, spreadRadius: 6),
                BoxShadow(color: Colors.white, blurRadius: 10, spreadRadius: 2),
              ],
            ),
          )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .moveY(duration: 1600.ms, begin: -8, end: 8),
        ),
        // Drifting Feathers
        Positioned(
          top: viewSize.height * 0.18,
          left: viewSize.width * 0.15,
          child: const Icon(Icons.spa_rounded, color: Colors.white70, size: 24)
              .animate(onPlay: (controller) => controller.repeat())
              .moveY(duration: 3000.ms, begin: -10, end: 120)
              .rotate(duration: 3000.ms)
              .fadeOut(duration: 3000.ms),
        ),
        Positioned(
          top: viewSize.height * 0.15,
          right: viewSize.width * 0.18,
          child: const Icon(Icons.spa_rounded, color: Colors.white70, size: 28)
              .animate(onPlay: (controller) => controller.repeat())
              .moveY(duration: 3400.ms, begin: -20, end: 130)
              .rotate(duration: 3400.ms)
              .fadeOut(duration: 3400.ms),
        ),
      ],
    );
  }

  // 7. Fluttering Iridescent Butterflies Orbiting
  Widget _buildButterfliesArFilter(Size viewSize) {
    return Stack(
      children: [
        Positioned(
          top: viewSize.height * 0.12,
          left: viewSize.width * 0.15,
          child: const Icon(Icons.flutter_dash_rounded, color: Color(0xFF00E5FF), size: 36)
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(duration: 600.ms, begin: const Offset(0.75, 1.0), end: const Offset(1.15, 0.9))
              .move(duration: 2000.ms, begin: const Offset(-10, 0), end: const Offset(20, -25)),
        ),
        Positioned(
          top: viewSize.height * 0.09,
          right: viewSize.width * 0.18,
          child: const Icon(Icons.flutter_dash_rounded, color: Color(0xFFFFD700), size: 42)
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(duration: 500.ms, begin: const Offset(0.7, 1.0), end: const Offset(1.2, 0.95))
              .move(duration: 2200.ms, begin: const Offset(15, 0), end: const Offset(-25, -20)),
        ),
        Positioned(
          top: viewSize.height * 0.22,
          right: viewSize.width * 0.10,
          child: const Icon(Icons.flutter_dash_rounded, color: Color(0xFFFF4081), size: 30)
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(duration: 650.ms, begin: const Offset(0.8, 1.0), end: const Offset(1.1, 0.9))
              .move(duration: 1800.ms, begin: const Offset(0, 10), end: const Offset(-15, -30)),
        ),
      ],
    );
  }

  // 8. Glowing Neon Devil Horns
  Widget _buildDevilHornsArFilter(Size viewSize) {
    return Stack(
      children: [
        Positioned(
          top: viewSize.height * 0.08,
          left: viewSize.width * 0.22,
          child: Transform.rotate(
            angle: -0.35,
            child: const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF1744), size: 54),
          )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(duration: 800.ms, begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1))
              .shimmer(duration: 1200.ms, color: const Color(0xFFFF8A80)),
        ),
        Positioned(
          top: viewSize.height * 0.08,
          right: viewSize.width * 0.22,
          child: Transform.rotate(
            angle: 0.35,
            child: const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF1744), size: 54),
          )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scale(duration: 800.ms, begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1))
              .shimmer(duration: 1200.ms, color: const Color(0xFFFF8A80)),
        ),
      ],
    );
  }

  Widget _buildWebLensOverlay(CameraLensEffect lens) {
    Color overlayColor;
    double opacity = 0.22;

    switch (lens.id) {
      case 'golden':
        overlayColor = const Color(0xFFFFB300);
        opacity = 0.22;
        break;
      case 'cyberpunk':
        overlayColor = const Color(0xFFD946EF);
        opacity = 0.25;
        break;
      case 'vintage':
        overlayColor = const Color(0xFFB45309);
        opacity = 0.26;
        break;
      case 'beauty':
        overlayColor = const Color(0xFFF472B6);
        opacity = 0.16;
        break;
      case 'aqua':
        overlayColor = const Color(0xFF06B6D4);
        opacity = 0.22;
        break;
      case 'emerald':
        overlayColor = const Color(0xFF10B981);
        opacity = 0.22;
        break;
      case 'crimson':
        overlayColor = const Color(0xFFF43F5E);
        opacity = 0.24;
        break;
      case 'pop':
        overlayColor = const Color(0xFFEC4899);
        opacity = 0.18;
        break;
      case 'sepia':
        overlayColor = const Color(0xFF78350F);
        opacity = 0.30;
        break;
      case 'moonlight':
        overlayColor = const Color(0xFF3B82F6);
        opacity = 0.24;
        break;
      default:
        overlayColor = lens.previewGradient.isNotEmpty ? lens.previewGradient.first : Colors.amber;
        opacity = 0.18;
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: overlayColor.withValues(alpha: opacity),
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
      (CameraMode.photo, 'Camera'),
      (CameraMode.video, 'Video'),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: modes.map((item) {
              final mode = item.$1;
              final label = item.$2;
              final isSelected = _currentMode == mode;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _currentMode = mode);
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
                            fontSize: 14,
                          ),
                        ),
                        if (isSelected)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            width: 22,
                            height: 2.5,
                            decoration: BoxDecoration(
                              color: AppColors.secondaryTeal,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                      ],
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

  Widget _buildLensesCarousel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_selectedLens != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedLens = null);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.secondaryTeal, width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, color: AppColors.secondaryTeal, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      _selectedLens!.name,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.close_rounded, color: Colors.white70, size: 14),
                  ],
                ),
              ),
            ),
          ),
        SizedBox(
          height: 82,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _builtinLenses.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: _openLensesSearchSheet,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipOval(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withValues(alpha: 0.45),
                                border: Border.all(color: Colors.white30, width: 1.5),
                              ),
                              child: const Icon(Icons.search_rounded, color: Colors.white, size: 22),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Search',
                          style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final lens = _builtinLenses[index - 1];
              final isSelected = _selectedLens?.id == lens.id || (_selectedLens == null && lens.id == 'none');

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedLens = lens.id == 'none' ? null : lens;
                    });
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: isSelected ? 56 : 50,
                            height: isSelected ? 56 : 50,
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: isSelected
                                  ? const SweepGradient(
                                      colors: [
                                        Color(0xFF8B5CF6),
                                        Color(0xFFEC4899),
                                        Color(0xFF38BDF8),
                                        Color(0xFF8B5CF6),
                                      ],
                                    )
                                  : null,
                              border: isSelected ? null : Border.all(color: Colors.white30, width: 1.5),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.5),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: lens.previewGradient,
                                ),
                              ),
                              child: Icon(
                                lens.icon,
                                color: Colors.white,
                                size: isSelected ? 22 : 18,
                              ),
                            ),
                          ),
                          if (lens.isAr)
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFC00),
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black54, blurRadius: 4),
                                  ],
                                ),
                                child: const Text(
                                  'AR',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lens.name,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white60,
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
