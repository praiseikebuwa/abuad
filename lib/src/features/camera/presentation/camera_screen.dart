import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

enum CameraMode { photo, video, videoNote }
enum GridType { thirds, golden, crosshair }

class CameraScreen extends StatefulWidget {
  final bool isForStory;
  final Function(XFile file, CameraMode mode)? onMediaCaptured;

  const CameraScreen({super.key, this.isForStory = true, this.onMediaCaptured});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _selectedCameraIndex = 0;
  CameraMode _currentMode = CameraMode.photo;
  bool _isRecording = false;
  bool _isCameraInitialized = false;
  FlashMode _flashMode = FlashMode.off;
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  bool _showGrid = false;
  GridType _gridType = GridType.thirds;
  Uint8List? _latestGallerImage;
  AssetEntity? _latestAsset;

  late PageController _modePageController;
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;
  Timer? _countdownTimer;
  bool _timerModeActive = false;
  final int _timerDelaySeconds = 3; // 3 or 10
  int _timerCountdownValue = 0;
  bool _isMirrored = true;
  double _exposureOffset = 0.0;
  double _maxExposureOffset = 2.0;
  double _minExposureOffset = -2.0;
  bool _showExposureSlider = false;
  ResolutionPreset _resolutionPreset = ResolutionPreset.high;
  Offset? _focusPoint;
  final _picker = ImagePicker();
  bool _isPickingImage = false;

  @override
  void initState() {
    super.initState();
    _modePageController = PageController(initialPage: 0, viewportFraction: 0.3);
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _fetchLatestGalleryImage();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _modePageController.dispose();
    _recordingTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _isCameraInitialized = false;
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _onNewCameraSelected(cameraController.description);
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameraStatus = await Permission.camera.request();
      final micStatus = await Permission.microphone.request();
      if (cameraStatus.isGranted && micStatus.isGranted) {
        _cameras = await availableCameras();
        if (_cameras.isNotEmpty) {
          _onNewCameraSelected(_cameras[_selectedCameraIndex]);
        }
      } else {
        if (mounted) setState(() {}); // will show permission button
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  Future<void> _onNewCameraSelected(CameraDescription cameraDescription) async {
    if (_controller != null) {
      await _controller!.dispose();
    }

    final CameraController cameraController = CameraController(
      cameraDescription,
      _resolutionPreset,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _controller = cameraController;

    // If the controller is updated then update the UI.
    cameraController.addListener(() {
      if (mounted) setState(() {});
      if (cameraController.value.hasError) {
        debugPrint('Camera error ${cameraController.value.errorDescription}');
      }
    });

    try {
      await cameraController.initialize();
      await cameraController.setFlashMode(_flashMode);
      _minZoom = await cameraController.getMinZoomLevel();
      _maxZoom = await cameraController.getMaxZoomLevel();
      _minExposureOffset = await cameraController.getMinExposureOffset();
      _maxExposureOffset = await cameraController.getMaxExposureOffset();
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
    }
  }

  Future<void> _fetchLatestGalleryImage() async {
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
        _latestAsset = asset;
      });
      }
    } catch (e) {
      debugPrint('Error fetching latest gallery image: $e');
    }
  }

  void _toggleCamera() {
    if (_cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    _onNewCameraSelected(_cameras[_selectedCameraIndex]);
    HapticFeedback.mediumImpact();
  }

  void _toggleFlash() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    setState(() {
      _flashMode = _flashMode == FlashMode.off
          ? FlashMode.torch
          : _flashMode == FlashMode.torch
              ? FlashMode.auto
              : _flashMode == FlashMode.auto
                  ? FlashMode.always
                  : FlashMode.off;
    });
    _controller?.setFlashMode(_flashMode);
  }

  void _setFocusPoint(Offset globalPosition) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null || _controller == null) return;
    final local = box.globalToLocal(globalPosition);
    final size = box.size;
    final x = (local.dx / size.width).clamp(0.0, 1.0);
    final y = (local.dy / size.height).clamp(0.0, 1.0);
    _controller!.setFocusPoint(Offset(x, y));
    HapticFeedback.lightImpact();
    setState(() => _focusPoint = Offset(x, y));
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _focusPoint = null);
    });
  }

  void _setExposureOffset(double value) {
    _controller?.setExposureOffset(value);
    setState(() => _exposureOffset = value);
  }

  void _toggleTimerMode() {
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

  // ✅ CORRECTED: underscores and logic
  Future<void> _takePhoto() async {
    if (!_isCameraInitialized || _isRecording) return; // fix: _isRecording, not !_isRecording
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
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      final XFile file = await _controller!.takePicture();
      _handleMediaCapture(file, CameraMode.photo);
    } catch (e) {
      debugPrint('Error taking photo: $e');
    }
  }

  Future<void> _startVideoRecording() async {
    if (!_isCameraInitialized || _isRecording) return;
    HapticFeedback.heavyImpact();
    try {
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_isRecording) setState(() => _recordingDuration += const Duration(seconds: 1));
      });
    } catch (e) {
      debugPrint('Error starting video: $e');
    }
  }

  Future<void> _stopVideoRecording() async {
    if (!_isCameraInitialized || !_isRecording) return;
    HapticFeedback.mediumImpact();
    try {
      final XFile file = await _controller!.stopVideoRecording();
      _recordingTimer?.cancel();
      setState(() => _isRecording = false);
      _handleMediaCapture(file, _currentMode);
    } catch (e) {
      debugPrint('Error stopping video: $e');
    }
  }

  void _handleMediaCapture(XFile file, CameraMode mode) {
    if (widget.onMediaCaptured != null) {
      widget.onMediaCaptured!(file, mode);
    } else {
      Navigator.pop(context, {'file': file, 'mode': mode});
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isPickingImage) return;
    _isPickingImage = true;
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) _handleMediaCapture(image, CameraMode.photo);
    } finally {
      _isPickingImage = false;
    }
  }

  Future<void> _previewLatestImage() async {
    if (_latestAsset == null) {
      _pickFromGallery();
      return;
    }
    final file = await _latestAsset!.file;
    if (file != null) {
      showDialog(
        context: context,
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(child: Image.file(file)),
              Positioned(
                top: 40,
                left: 20,
                child: _buildCircularButton(
                  icon: Icons.close,
                  onTap: () => Navigator.pop(ctx),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if ((details.primaryVelocity ?? 0).abs() > 500) _toggleCamera();
  }

  void _toggleGridType() {
    setState(() {
      _gridType = GridType.values[(_gridType.index + 1) % GridType.values.length];
    });
  }

  void _showResolutionPicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ResolutionPreset.values.map((preset) {
            return ListTile(
              title: Text(preset.toString().split('.').last),
              leading: _resolutionPreset == preset
                  ? const Icon(Icons.check, color: Colors.blue)
                  : null,
              onTap: () {
                Navigator.pop(context);
                setState(() => _resolutionPreset = preset);
                if (_cameras.isNotEmpty) {
                  _onNewCameraSelected(_cameras[_selectedCameraIndex]);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    if (!_isCameraInitialized && _cameras.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _initializeCamera,
                child: const Text('Grant Permissions'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isCameraInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final bool isFrontCamera = _controller?.description.lensDirection ==
        CameraLensDirection.front;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GestureDetector(
            onScaleUpdate: (details) {
              double newZoom = (_currentZoom * details.scale).clamp(_minZoom, _maxZoom);
              if ((newZoom * 2).floor() != (_currentZoom * 2).floor()) {
                HapticFeedback.selectionClick();
              }
              setState(() => _currentZoom = newZoom);
              _controller?.setZoomLevel(newZoom);
            },
            onDoubleTap: _toggleCamera,
            onTapUp: (details) => _setFocusPoint(details.globalPosition),
            onHorizontalDragEnd: _onHorizontalDragEnd,
            child: Center(
              child: Transform.scale(
                scale: _controller != null && _controller!.value.isInitialized
                    ? 1 /
                          (_controller!.value.aspectRatio *
                              MediaQuery.of(context).size.aspectRatio)
                    : 1.0,
                child: Transform(
                  alignment: Alignment.center,
                  transform: isFrontCamera && _isMirrored
                       ? (Matrix4.identity()..scale(-1.0, 1.0))
                      : Matrix4.identity(),
                  child: CameraPreview(_controller!),
                ),
              ),
            ),
          ),

          // Focus point indicator
          if (_focusPoint != null)
            Positioned(
              left: (_focusPoint!.dx * size.width) - 25,
              top: (_focusPoint!.dy * size.height) - 25,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.yellow, width: 2),
                ),
              ),
            ),

          // Grid
          if (_showGrid)
            Positioned.fill(
              child: CustomPaint(painter: GridPainter(_gridType)),
            ),

          // Top controls
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCircularButton(icon: Icons.close, onTap: () => Navigator.pop(context)),
                Row(
                  children: [
                    _buildCircularButton(
                      icon: _timerModeActive ? Icons.timer : Icons.timer_outlined,
                      onTap: _toggleTimerMode,
                      size: 36,
                    ),
                    const SizedBox(width: 8),
                    _buildCircularButton(
                      icon: _getFlashIcon(),
                      onTap: () {
                        _toggleFlash();
                        HapticFeedback.lightImpact();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Right sidebar
          Positioned(
            right: 15,
            top: MediaQuery.of(context).size.height * 0.22,
            child: Column(
              children: [
                _buildSidebarButton(
                  icon: Icons.flip_camera_ios_rounded,
                  label: "Flip",
                  onTap: _toggleCamera,
                  isLarge: true,
                ),
                const SizedBox(height: 16),
                if (isFrontCamera)
                  _buildSidebarButton(
                    icon: Icons.flip,
                    label: _isMirrored ? "Mirror" : "Normal",
                    isActive: _isMirrored,
                    onTap: () => setState(() => _isMirrored = !_isMirrored),
                  ),
                _buildSidebarButton(
                  icon: _showGrid ? Icons.grid_on : Icons.grid_off,
                  label: "Grid",
                  isActive: _showGrid,
                  onTap: () => setState(() => _showGrid = !_showGrid),
                  onLongPress: _showGrid ? _toggleGridType : null,
                ),
                const SizedBox(height: 8),
                _buildSidebarButton(
                  icon: Icons.wb_sunny,
                  label: "Exp.",
                  isActive: _showExposureSlider,
                  onTap: () => setState(() => _showExposureSlider = !_showExposureSlider),
                ),
              ],
            ),
          ),

          // Exposure slider
          if (_showExposureSlider)
            Positioned(
              right: 80,
              top: size.height * 0.35,
              child: RotatedBox(
                quarterTurns: 3,
                child: Slider(
                  value: _exposureOffset,
                  min: _minExposureOffset,
                  max: _maxExposureOffset,
                  onChanged: _setExposureOffset,
                ),
              ),
            ),

          // Recording timer
          if (_isRecording)
            Positioned(
              top: MediaQuery.of(context).padding.top + 50,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'REC ${_formatDuration(_recordingDuration)}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ),

          // Countdown timer
          if (_timerModeActive && _countdownTimer != null)
            Positioned.fill(
              child: Center(
                child: Text(
                  '$_timerCountdownValue',
                  style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(blurRadius: 10, color: Colors.black)]),
                ),
              ),
            ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                ),
              ),
              padding: const EdgeInsets.only(bottom: 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildLatestImageButton(),
                        GestureDetector(
                          onTap: _currentMode == CameraMode.photo ? _takePhoto : null,
                          onLongPress: _currentMode != CameraMode.photo ? _startVideoRecording : null,
                          onLongPressUp: _currentMode != CameraMode.photo ? _stopVideoRecording : null,
                          child: _buildShutterButton(),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  GestureDetector(
                    onLongPress: _showResolutionPicker,
                    child: SizedBox(
                      height: 50,
                      child: PageView.builder(
                        controller: _modePageController,
                        itemCount: CameraMode.values.length,
                        onPageChanged: (index) {
                          setState(() => _currentMode = CameraMode.values[index]);
                          HapticFeedback.selectionClick();
                        },
                        itemBuilder: (context, index) {
                          final mode = CameraMode.values[index];
                          final isSelected = _currentMode == mode;
                          return GestureDetector(
                            onTap: () {
                              _modePageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                            },
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.white60,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  fontSize: isSelected ? 15 : 13,
                                  letterSpacing: 1.2,
                                ),
                                child: Text(_getModeName(mode)),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Zoom slider
          if (_currentZoom > 1.0)
            Positioned(
              right: 20,
              top: size.height / 2 - 100,
              child: RotatedBox(
                quarterTurns: 3,
                child: Slider(
                  value: _currentZoom,
                  min: _minZoom,
                  max: _maxZoom,
                  onChanged: (value) {
                    setState(() => _currentZoom = value);
                    _controller?.setZoomLevel(value);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLatestImageButton() {
    return GestureDetector(
      onTap: _previewLatestImage,
      onLongPress: _toggleCamera,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_latestGallerImage != null)
              Image.memory(_latestGallerImage!, fit: BoxFit.cover)
            else
              const Icon(Icons.photo_library, color: Colors.white70, size: 20),
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
                child: const Icon(Icons.sync, color: Colors.white, size: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularButton({required IconData icon, required VoidCallback onTap, double size = 40}) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: size * 0.6),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    bool isLarge = false,
    VoidCallback? onLongPress,
  }) {
    final size = isLarge ? 56.0 : 44.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: isActive ? Colors.white.withOpacity(0.35) : Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white30, width: 1.5),
                ),
                child: Icon(icon, color: Colors.white, size: isLarge ? 28 : 22),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            shadows: [Shadow(blurRadius: 4, color: Colors.black45, offset: Offset(0, 2))],
          ),
        ),
      ],
    );
  }

  Widget _buildShutterButton() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
      padding: const EdgeInsets.all(4),
      child: Container(
        decoration: BoxDecoration(
          color: _isRecording ? Colors.red : Colors.white,
          shape: BoxShape.circle,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _isRecording
              ? const Icon(Icons.stop, color: Colors.white, size: 30)
              : const SizedBox(),
        ),
      ),
    );
  }

  IconData _getFlashIcon() {
    switch (_flashMode) {
      case FlashMode.off: return Icons.flash_off;
      case FlashMode.torch: return Icons.flashlight_on;
      case FlashMode.always: return Icons.flash_on;
      case FlashMode.auto: return Icons.flash_auto;
    }
  }

  String _getModeName(CameraMode mode) {
    switch (mode) {
      case CameraMode.photo: return "PHOTO";
      case CameraMode.video: return "VIDEO";
      case CameraMode.videoNote: return "VIDEO NOTE";
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
      ..color = Colors.white24
      ..strokeWidth = 1.0;

    switch (type) {
      case GridType.thirds:
        canvas.drawLine(Offset(size.width / 3, 0), Offset(size.width / 3, size.height), paint);
        canvas.drawLine(Offset(size.width * 2 / 3, 0), Offset(size.width * 2 / 3, size.height), paint);
        canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), paint);
        canvas.drawLine(Offset(0, size.height * 2 / 3), Offset(size.width, size.height * 2 / 3), paint);
        break;
      case GridType.golden:
        final phi = 1.618;
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