import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:toastification/toastification.dart';

class FullScreenImageView extends StatelessWidget {
  final String imageUrl;
  final String? heroTag;

  const FullScreenImageView({super.key, required this.imageUrl, this.heroTag});

  Future<void> _saveImage(BuildContext context) async {
    try {
      // Check permissions
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        await Gal.requestAccess();
      }

      // Show loading
      if (context.mounted) {
        toastification.show(
          context: context,
          title: const Text('Saving...'),
          type: ToastificationType.info,
          autoCloseDuration: const Duration(seconds: 2),
        );
      }

      // 1. Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final path =
          '${tempDir.path}/abuad_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // 2. Download image
      await Dio().download(imageUrl, path);

      // 3. Save to gallery using Gal
      await Gal.putImage(path);

      if (context.mounted) {
        toastification.show(
          context: context,
          title: const Text('Success!'),
          description: const Text('Image saved to gallery.'),
          type: ToastificationType.success,
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      if (context.mounted) {
        toastification.show(
          context: context,
          title: const Text('Error'),
          description: Text(e.toString()),
          type: ToastificationType.error,
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const CloseButton(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: () => _saveImage(context),
            tooltip: 'Save to Gallery',
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Hero(
        tag: heroTag ?? imageUrl,
        child: PhotoView(
          imageProvider: CachedNetworkImageProvider(imageUrl),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 2,
          loadingBuilder: (context, event) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          errorBuilder: (context, error, stackTrace) => const Center(
            child: Icon(Icons.broken_image, color: Colors.white, size: 64),
          ),
        ),
      ),
    );
  }
}
