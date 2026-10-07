import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:toastification/toastification.dart';
import '../../../../core/services/media_saver.dart';
import '../../../../core/utils/url_validator.dart';

class FullScreenImageView extends StatelessWidget {
  final String imageUrl;
  final String? heroTag;

  const FullScreenImageView({super.key, required this.imageUrl, this.heroTag});

  Future<void> _saveImage(BuildContext context) async {
    if (context.mounted) {
      toastification.show(
        context: context,
        title: const Text('Saving...'),
        type: ToastificationType.info,
        autoCloseDuration: const Duration(seconds: 2),
      );
    }

    final success = await MediaSaver.saveImage(imageUrl);

    if (context.mounted) {
      toastification.show(
        context: context,
        title: Text(success ? 'Success!' : 'Error'),
        description: Text(
          success ? 'Image saved to gallery.' : 'Failed to save image.',
        ),
        type: success ? ToastificationType.success : ToastificationType.error,
        autoCloseDuration: const Duration(seconds: 3),
      );
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
        child: UrlValidator.isValidUrl(imageUrl)
            ? PhotoView(
                imageProvider: CachedNetworkImageProvider(imageUrl),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
                loadingBuilder: (context, event) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.white, size: 64),
                ),
              )
            : const Center(
                child: Icon(Icons.broken_image, color: Colors.white, size: 64),
              ),
      ),
    );
  }
}
