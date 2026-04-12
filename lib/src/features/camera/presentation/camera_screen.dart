import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';
import 'dart:ui';

enum CameraMode { photo, video, videoNote }

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
  Uint8List? _latestGallerImage;

  late PageController _modePageController;

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
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _onNewCameraSelected(cameraController.description);
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        _onNewCameraSelected(_cameras[_selectedCameraIndex]);
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
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _controller = cameraController;

    try {
      await cameraController.initialize();
      await cameraController.setFlashMode(_flashMode);

      _minZoom = await cameraController.getMinZoomLevel();
      _maxZoom = await cameraController.getMaxZoomLevel();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera controller: $e');
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

      final Uint8List? thumb = await assets[0].thumbnailData;
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
    if (_cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    _onNewCameraSelected(_cameras[_selectedCameraIndex]);
    HapticFeedback.mediumImpact();
  }

  void _toggleFlash() {
    setState(() {
      if (_flashMode == FlashMode.off) {
        _flashMode = FlashMode.torch;
      } else if (_flashMode == FlashMode.torch) {
        _flashMode = FlashMode.auto;
      } else if (_flashMode == FlashMode.auto) {
        _flashMode = FlashMode.always;
      } else {
        _flashMode = FlashMode.off;
      }
    });
    _controller?.setFlashMode(_flashMode);
  }

  Future<void> _takePhoto() async {
    if (!_isCameraInitialized || _isRecording) return;
    HapticFeedback.mediumImpact();

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
      });
    } catch (e) {
      debugPrint('Error starting video recording: $e');
    }
  }

  Future<void> _stopVideoRecording() async {
    if (!_isCameraInitialized || !_isRecording) return;
    HapticFeedback.mediumImpact();

    try {
      final XFile file = await _controller!.stopVideoRecording();
      setState(() {
        _isRecording = false;
      });
      _handleMediaCapture(file, _currentMode);
    } catch (e) {
      debugPrint('Error stopping video recording: $e');
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
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      _handleMediaCapture(image, CameraMode.photo);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          GestureDetector(
            onScaleUpdate: (details) {
              final zoom = (_currentZoom * details.scale).clamp(
                _minZoom,
                _maxZoom,
              );
              setState(() => _currentZoom = zoom);
              _controller?.setZoomLevel(zoom);
            },
            onDoubleTap: _toggleCamera,
            child: Center(
              child: Transform.scale(
                scale: _controller != null && _controller!.value.isInitialized
                    ? 1 /
                          (_controller!.value.aspectRatio *
                              MediaQuery.of(context).size.aspectRatio)
                    : 1.0,
                child: CameraPreview(_controller!),
              ),
            ),
          ),

          // 3x3 Composition Grid Overlay
          if (_showGrid)
            Positioned.fill(child: CustomPaint(painter: GridPainter())),

          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCircularButton(
                  icon: Icons.close,
                  onTap: () => Navigator.pop(context),
                ),
                _buildCircularButton(
                  icon: _getFlashIcon(),
                  onTap: () {
                    _toggleFlash();
                    HapticFeedback.lightImpact();
                  },
                ),
              ],
            ),
          ),

          Positioned(
            right: 15,
            top: MediaQuery.of(context).size.height * 0.25,
            child: Column(
              children: [
                // Flip Camera - Larger Button
                _buildSidebarButton(
                  icon: Icons.flip_camera_ios_rounded,
                  label: "Flip",
                  onTap: _toggleCamera,
                  isLarge: true,
                ),
                const SizedBox(height: 20),
                // Grid Toggle
                _buildSidebarButton(
                  icon: _showGrid
                      ? Icons.grid_on_rounded
                      : Icons.grid_off_rounded,
                  label: "Grid",
                  isActive: _showGrid,
                  onTap: () {
                    setState(() => _showGrid = !_showGrid);
                    HapticFeedback.lightImpact();
                  },
                ),
              ],
            ),
          ),

          // Bottom Controls Layer
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
                  // Action Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildLatestImageButton(),

                        GestureDetector(
                          onTap: _currentMode == CameraMode.photo
                              ? _takePhoto
                              : null,
                          onLongPress: _currentMode != CameraMode.photo
                              ? _startVideoRecording
                              : null,
                          onLongPressUp: _currentMode != CameraMode.photo
                              ? _stopVideoRecording
                              : null,
                          child: _buildShutterButton(),
                        ),

                        const SizedBox(width: 48), // Spacer for balance
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Mode Tabs
                  SizedBox(
                    height: 50,
                    child: PageView.builder(
                      controller: _modePageController,
                      itemCount: CameraMode.values.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentMode = CameraMode.values[index];
                        });
                        HapticFeedback.selectionClick();
                      },
                      itemBuilder: (context, index) {
                        final mode = CameraMode.values[index];
                        final isSelected = _currentMode == mode;
                        return GestureDetector(
                          onTap: () {
                            _modePageController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          },
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white60,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
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
                ],
              ),
            ),
          ),

          // Zoom Indicator Overlay
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
                    setState(() {
                      _currentZoom = value;
                    });
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
      onTap: _pickFromGallery,
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

            // Camera Rotate Overlay Icon
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.black26,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sync, color: Colors.white, size: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularButton({
    required IconData icon,
    required VoidCallback onTap,
    double size = 40,
  }) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
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
  }) {
    final size = isLarge ? 56.0 : 44.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withOpacity(0.35)
                      : Colors.white.withOpacity(0.15),
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
            shadows: [
              Shadow(
                blurRadius: 4,
                color: Colors.black45,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShutterButton() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
      ),
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
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.torch:
        return Icons.flashlight_on;
      case FlashMode.always:
        return Icons.flash_on;
      case FlashMode.auto:
        return Icons.flash_auto;
    }
  }

  String _getModeName(CameraMode mode) {
    switch (mode) {
      case CameraMode.photo:
        return "PHOTO";
      case CameraMode.video:
        return "VIDEO";
      case CameraMode.videoNote:
        return "VIDEO NOTE";
    }
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.0;

    // Vertical lines
    canvas.drawLine(
      Offset(size.width / 3, 0),
      Offset(size.width / 3, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 2 / 3, 0),
      Offset(size.width * 2 / 3, size.height),
      paint,
    );

    // Horizontal lines
    canvas.drawLine(
      Offset(0, size.height / 3),
      Offset(size.width, size.height / 3),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height * 2 / 3),
      Offset(size.width, size.height * 2 / 3),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
