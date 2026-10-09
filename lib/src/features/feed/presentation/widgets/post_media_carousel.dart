import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/utils/url_validator.dart';
import 'full_screen_image_view.dart';

class PostMediaCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final String postId;
  final double maxHeight;
  final double minHeight;
  final String? locationText;

  const PostMediaCarousel({
    super.key,
    required this.imageUrls,
    required this.postId,
    this.maxHeight = 650,
    this.minHeight = 120,
    this.locationText,
  });

  @override
  State<PostMediaCarousel> createState() => _PostMediaCarouselState();
}

class _PostMediaCarouselState extends State<PostMediaCarousel> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls.where((u) => u.trim().isNotEmpty).toList();
    if (urls.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (urls.length == 1) {
      final rawUrl = urls.first;
      final singleUrl = UrlValidator.formatImageUrl(rawUrl);
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FullScreenImageView(
                imageUrls: urls,
                initialIndex: 0,
                heroTag: 'post_media_${widget.postId}_0',
              ),
            ),
          );
        },
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: widget.maxHeight,
                  minHeight: widget.minHeight,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Hero(
                    tag: 'post_media_${widget.postId}_0',
                    child: (singleUrl.isNotEmpty && UrlValidator.isValidUrl(singleUrl))
                        ? CachedNetworkImage(
                            imageUrl: singleUrl,
                            width: double.infinity,
                            fit: BoxFit.fitWidth,
                            placeholder: (context, url) => AspectRatio(
                              aspectRatio: 4 / 5,
                              child: _buildPlaceholder(context, isDark),
                            ),
                            errorWidget: (context, url, error) => AspectRatio(
                              aspectRatio: 16 / 9,
                              child: _buildErrorWidget(context, isDark),
                            ),
                          )
                        : AspectRatio(
                            aspectRatio: 16 / 9,
                            child: _buildErrorWidget(context, isDark),
                          ),
                  ),
                ),
              ),
            ),
            if (widget.locationText != null) _buildLocationTag(widget.locationText!),
          ],
        ),
      );
    }

    // Multi-Image Carousel
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: widget.maxHeight,
              minHeight: widget.minHeight,
            ),
            child: AspectRatio(
              aspectRatio: 4 / 5,
              child: PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                itemCount: urls.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final rawUrl = urls[index];
                  final url = UrlValidator.formatImageUrl(rawUrl);
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FullScreenImageView(
                            imageUrls: urls,
                            initialIndex: index,
                            heroTag: index == 0 ? 'post_media_${widget.postId}_0' : null,
                          ),
                        ),
                      );
                    },
                    child: Hero(
                      tag: index == 0 ? 'post_media_${widget.postId}_0' : 'post_media_${widget.postId}_$index',
                      child: (url.isNotEmpty && UrlValidator.isValidUrl(url))
                          ? CachedNetworkImage(
                              imageUrl: url,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => _buildPlaceholder(context, isDark),
                              errorWidget: (context, url, error) => _buildErrorWidget(context, isDark),
                            )
                          : _buildErrorWidget(context, isDark),
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        // Multi-image counter badge (Top-Right)
        Positioned(
          top: 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.photo_library_rounded,
                  color: Colors.white,
                  size: 13,
                ),
                const SizedBox(width: 5),
                Text(
                  '${_currentPage + 1}/${urls.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Carousel Indicator Dots (Bottom-Center)
        Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(urls.length, (index) {
              final isSelected = index == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 5,
                width: isSelected ? 18 : 5,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),

        // Location Tag
        if (widget.locationText != null) _buildLocationTag(widget.locationText!),
      ],
    );
  }

  Widget _buildPlaceholder(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
      ),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFFE2E8F0), Color(0xFFCBD5E1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              color: isDark ? Colors.white38 : Colors.black38,
              size: 36,
            ),
            const SizedBox(height: 6),
            Text(
              'Image preview',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationTag(String location) {
    return Positioned(
      left: 12,
      bottom: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_on_rounded,
              size: 13,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              location,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
