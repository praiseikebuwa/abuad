import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
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
  int _rotationQuarterTurns = 0;
  bool _showControls = true;

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

  void _shareImage() {
    if (_urls.isEmpty) return;
    final currentUrl = _urls[_currentIndex];
    Share.share(currentUrl, subject: 'Image from ABUAD App');
  }

  void _copyLink() {
    if (_urls.isEmpty) return;
    final currentUrl = _urls[_currentIndex];
    Clipboard.setData(ClipboardData(text: currentUrl));
    toastification.show(
      context: context,
      title: const Text('Link Copied'),
      description: const Text('Image link copied to clipboard.'),
      type: ToastificationType.success,
      autoCloseDuration: const Duration(seconds: 2),
    );
  }

  void _rotateImage() {
    setState(() {
      _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
    });
  }

  void _showImageDetails() {
    if (_urls.isEmpty) return;
    final currentUrl = _urls[_currentIndex];
    final uri = Uri.tryParse(currentUrl);
    final ext = uri?.path.split('.').last.toUpperCase() ?? 'IMAGE';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF18181B),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white12, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Image Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              _buildDetailRow('Format', ext.isNotEmpty ? ext : 'JPEG'),
              _buildDetailRow('Item', '${_currentIndex + 1} of ${_urls.length}'),
              if (uri != null && uri.host.isNotEmpty)
                _buildDetailRow('Host', uri.host),
              _buildDetailRow('Rotation', '${_rotationQuarterTurns * 90}°'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Download Image'),
                  onPressed: () {
                    Navigator.pop(context);
                    _saveImage(context);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
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
      extendBodyBehindAppBar: true,
      appBar: _showControls
          ? AppBar(
              backgroundColor: Colors.black.withValues(alpha: 0.6),
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
                  icon: const Icon(Icons.rotate_right_rounded, color: Colors.white),
                  onPressed: _rotateImage,
                  tooltip: 'Rotate 90°',
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline_rounded, color: Colors.white),
                  onPressed: _showImageDetails,
                  tooltip: 'Details',
                ),
                IconButton(
                  icon: const Icon(Icons.share_rounded, color: Colors.white),
                  onPressed: _shareImage,
                  tooltip: 'Share',
                ),
              ],
            )
          : null,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          children: [
            RotatedBox(
              quarterTurns: _rotationQuarterTurns,
              child: PhotoViewGallery.builder(
                scrollPhysics: const BouncingScrollPhysics(),
                builder: (BuildContext context, int index) {
                  final rawUrl = _urls[index];
                  final url = UrlValidator.formatImageUrl(rawUrl);
                  return PhotoViewGalleryPageOptions(
                    imageProvider: (url.isNotEmpty && UrlValidator.isValidUrl(url))
                        ? CachedNetworkImageProvider(url)
                        : null,
                    initialScale: PhotoViewComputedScale.contained,
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 3.0,
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
            ),

            // Bottom dots indicator if multiple images
            if (_urls.length > 1 && _showControls)
              Positioned(
                bottom: 84,
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

            // Bottom frosted toolbar with Actions
            if (_showControls)
              Positioned(
                bottom: 16,
                left: 20,
                right: 20,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white12, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildBottomAction(
                          icon: Icons.download_rounded,
                          label: 'Save',
                          onTap: () => _saveImage(context),
                        ),
                        _buildBottomAction(
                          icon: Icons.share_rounded,
                          label: 'Share',
                          onTap: _shareImage,
                        ),
                        _buildBottomAction(
                          icon: Icons.link_rounded,
                          label: 'Copy',
                          onTap: _copyLink,
                        ),
                        _buildBottomAction(
                          icon: Icons.rotate_right_rounded,
                          label: 'Rotate',
                          onTap: _rotateImage,
                        ),
                        _buildBottomAction(
                          icon: Icons.info_outline_rounded,
                          label: 'Info',
                          onTap: _showImageDetails,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
