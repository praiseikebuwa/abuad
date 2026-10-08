import 'package:flutter/material.dart';
import 'package:abuad/src/features/auth/data/auth_repository.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/chat_repository.dart';
import '../../../core/theme/app_colors.dart';

class QRScannerScreen extends ConsumerStatefulWidget {
  const QRScannerScreen({super.key});

  @override
  ConsumerState<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends ConsumerState<QRScannerScreen> {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  bool _isProcessing = false;

  String _extractUserId(String raw) {
    final value = raw.trim();
    final uri = Uri.tryParse(value);
    if (uri != null && uri.pathSegments.length >= 2) {
      if (uri.pathSegments.first == 'user') {
        return uri.pathSegments[1];
      }
    }
    return value;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _handleScan(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code.trim().isEmpty) return;
    final parsedUserId = _extractUserId(code);

    // Expected format: BU-XXXX-XXXX... (UserId)
    setState(() => _isProcessing = true);

    try {
      final userRepo = ref.read(userRepositoryProvider);
      final chatRepo = ref.read(chatRepositoryProvider);

      // Try to fetch the user to verify it's a valid ID
      final user = await userRepo.getUser(parsedUserId);
      if (user != null && mounted) {
        final authRepo = ref.read(authRepositoryProvider);
        final currentUser = authRepo.currentUser ?? ref.read(currentUserProvider).value;

        final channelId = await chatRepo.createOrGetChannel(
          user.uid,
          otherUserName: user.displayName,
          otherUserAvatar: user.avatarUrl,
          currentUserName: currentUser?.displayName,
          currentUserAvatar: currentUser?.avatarUrl,
        );

        if (mounted) {
          // Replace scanner with the chat screen
          context.replace('/chat/$channelId');
        }
      } else {
        throw Exception('Invalid User QR Code');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Scan Profile QR',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            color: Colors.white,
            icon: const Icon(Icons.flash_on),
            onPressed: () => controller.toggleTorch(),
          ),
          IconButton(
            color: Colors.white,
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () => controller.switchCamera(),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: _handleScan,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Camera error: ${error.errorCode.name}. Please allow camera permission and try again.',
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
          ),
          // Scanner Overlay
          CustomPaint(painter: ScannerOverlayPainter(), child: Container()),
          // Processing Indicator
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          // Guidance Text
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Center the QR code within the frame',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black45
      ..style = PaintingStyle.fill;

    final cutOutRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.7,
      height: size.width * 0.7,
    );

    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutOutPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(cutOutRect, const Radius.circular(20)),
      );

    final finalPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutOutPath,
    );
    canvas.drawPath(finalPath, paint);

    // Draw corners
    final cornerPaint = Paint()
      ..color = AppColors.secondaryTeal
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final path = Path();
    final len = size.width * 0.1;
    final r = 20.0;

    // Top Left
    path.moveTo(cutOutRect.left, cutOutRect.top + len);
    path.lineTo(cutOutRect.left, cutOutRect.top + r);
    path.quadraticBezierTo(
      cutOutRect.left,
      cutOutRect.top,
      cutOutRect.left + r,
      cutOutRect.top,
    );
    path.lineTo(cutOutRect.left + len, cutOutRect.top);

    // Top Right
    path.moveTo(cutOutRect.right - len, cutOutRect.top);
    path.lineTo(cutOutRect.right - r, cutOutRect.top);
    path.quadraticBezierTo(
      cutOutRect.right,
      cutOutRect.top,
      cutOutRect.right,
      cutOutRect.top + r,
    );
    path.lineTo(cutOutRect.right, cutOutRect.top + len);

    // Bottom Right
    path.moveTo(cutOutRect.right, cutOutRect.bottom - len);
    path.lineTo(cutOutRect.right, cutOutRect.bottom - r);
    path.quadraticBezierTo(
      cutOutRect.right,
      cutOutRect.bottom,
      cutOutRect.right - r,
      cutOutRect.bottom,
    );
    path.lineTo(cutOutRect.right - len, cutOutRect.bottom);

    // Bottom Left
    path.moveTo(cutOutRect.left + len, cutOutRect.bottom);
    path.lineTo(cutOutRect.left + r, cutOutRect.bottom);
    path.quadraticBezierTo(
      cutOutRect.left,
      cutOutRect.bottom,
      cutOutRect.left,
      cutOutRect.bottom - r,
    );
    path.lineTo(cutOutRect.left, cutOutRect.bottom - len);

    canvas.drawPath(path, cornerPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
