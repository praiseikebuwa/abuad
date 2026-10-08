import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:toastification/toastification.dart';
import '../../../../core/services/media_saver.dart';
import '../../../../core/utils/url_validator.dart';

class FullScreenImageView extends StatefulWidget {
  final String? imageUrl;
  final List<String>? imageUrls;
  final int initialIndex;
  final String? heroTag;

  const FullScreenImageView({
    super.key,
    this.imageUrl,
    this.imageUrls,
    this.initialIndex = 0,
    this.heroTag,
  });

  @override
  State<FullScreenImageView> createState() => _FullScreenImageViewState();
}

class _FullScreenImageViewState extends State<FullScreenImageView> {
  late PageController _pageController;
  late int _currentIndex;
  late List<String> _urls;

  @override
  void initState() {
    super.initState();
    if (widget.imageUrls != null && widget.imageUrls!.isNotEmpty) {
      _urls = widget.imageUrls!;
    } else if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      _urls = [widget.imageUrl!];
    } else {
      _urls = [];
    }
    _currentIndex = (widget.initialIndex >= 0 && widget.initialIndex < _urls.length)
        ? widget.initialIndex
        : 0;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _saveImage(BuildContext context) async {
    if (_urls.isEmpty) return;
    final currentUrl = _urls[_currentIndex];

    if (context.mounted) {
      toastification.show(
        context: context,
        title: const Text('Saving...'),
        type: ToastificationType.info,
        autoCloseDuration: const Duration(seconds: 2),
      );
    }

    final success = await MediaSaver.saveImage(currentUrl);

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
    if (_urls.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const CloseButton(color: Colors.white),
        ),
        body: const Center(
          child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        elevation: 0,
        leading: const CloseButton(color: Colors.white),
        title: _urls.length > 1
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_currentIndex + 1} / ${_urls.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : null,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            onPressed: () => _saveImage(context),
            tooltip: 'Save to Gallery',
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          PhotoViewGallery.builder(
            scrollPhysics: const BouncingScrollPhysics(),
            builder: (BuildContext context, int index) {
              final url = _urls[index];
              return PhotoViewGalleryPageOptions(
                imageProvider: UrlValidator.isValidUrl(url)
                    ? CachedNetworkImageProvider(url)
                    : null,
                initialScale: PhotoViewComputedScale.contained,
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2.5,
                heroAttributes: (widget.heroTag != null && index == widget.initialIndex)
                    ? PhotoViewHeroAttributes(tag: widget.heroTag!)
                    : null,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
                ),
              );
            },
            itemCount: _urls.length,
            loadingBuilder: (context, event) => const Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            pageController: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),
          // Bottom dots indicator if multiple images
          if (_urls.length > 1)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_urls.length, (index) {
                    final isSelected = index == _currentIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 6,
                      width: isSelected ? 20 : 6,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
