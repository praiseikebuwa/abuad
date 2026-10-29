import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/image_upload_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/autoplay_live_media_widget.dart';
import '../data/sticker_repository.dart';
import '../domain/sticker_item.dart';

class StickerCreatorScreen extends ConsumerStatefulWidget {
  final String? initialTemplateUrl;
  final String? initialMode; // 'PACKS', 'MY', 'CREATE'

  const StickerCreatorScreen({
    super.key,
    this.initialTemplateUrl,
    this.initialMode,
  });

  @override
  ConsumerState<StickerCreatorScreen> createState() => _StickerCreatorScreenState();
}

class _StickerCreatorScreenState extends ConsumerState<StickerCreatorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Boundary Key for rasterizing sticker to PNG
  final GlobalKey _photoBoundaryKey = GlobalKey();

  // Marketplace & Tray Data State
  List<StickerItem> _trendingStickers = [];
  List<StickerItem> _communityStickers = [];
  List<StickerItem> _myStickers = [];
  bool _isLoadingData = false;
  String _selectedCategory = 'ALL';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // Sticker Maker State
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isMotionMedia = false;
  double _cornerRadius = 28.0; // 0.0 (sharp) to 90.0 (pill/circle)
  bool _hasWhiteContour = true;
  double _contourWidth = 6.0;
  final TextEditingController _captionCtrl = TextEditingController(text: 'ABUAD VIBES ✨');
  final TextEditingController _titleCtrl = TextEditingController(text: 'Campus Sticker');
  final TextEditingController _tagsCtrl = TextEditingController(text: 'abuad, campus, vibes');
  String _makerCategory = 'CAMPUS';
  bool _isPublic = true;
  bool _isExporting = false;
  String _exportStatus = '';

  final List<String> _categories = [
    'ALL',
    'CAMPUS',
    'MEME',
    'REACTION',
    'STUDY',
    'SPORTS',
    'LIFESTYLE',
  ];

  @override
  void initState() {
    super.initState();
    int initialIndex = 0;
    if (widget.initialMode == 'MY') {
      initialIndex = 1;
    } else if (widget.initialMode == 'CREATE' ||
        widget.initialMode == 'PHOTO' ||
        widget.initialMode == 'DRAW' ||
        widget.initialMode == 'MOTION') {
      initialIndex = 2;
    }

    _tabController = TabController(length: 3, vsync: this, initialIndex: initialIndex);
    _loadMarketplaceAndTray();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    _captionCtrl.dispose();
    _titleCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMarketplaceAndTray() async {
    if (_isLoadingData) return;
    setState(() => _isLoadingData = true);
    try {
      final repo = ref.read(stickerRepositoryProvider);
      final trending = await repo.getTrendingStickers();
      final community = await repo.getCommunityStickers(
        category: _selectedCategory == 'ALL' ? null : _selectedCategory,
        search: _searchQuery,
      );
      final my = await repo.getMyStickers();
      if (mounted) {
        setState(() {
          _trendingStickers = trending;
          _communityStickers = community;
          _myStickers = my;
        });
      }
    } catch (e) {
      debugPrint('Error loading sticker marketplace: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // MEDIA PICKING
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 92);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _selectedImage = picked;
          _selectedImageBytes = bytes;
          _isMotionMedia = false;
          if (_titleCtrl.text.isEmpty || _titleCtrl.text == 'Campus Sticker') {
            _titleCtrl.text = _captionCtrl.text.isNotEmpty ? _captionCtrl.text : 'Photo Sticker';
          }
        });
      }
    } catch (e) {
      debugPrint('Error picking photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load image: $e')),
        );
      }
    }
  }

  Future<void> _pickMotionGifOrVideo() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _selectedImage = picked;
          _selectedImageBytes = bytes;
          _isMotionMedia = true;
          if (_titleCtrl.text.isEmpty || _titleCtrl.text == 'Campus Sticker') {
            _titleCtrl.text = 'Motion Sticker';
          }
        });
      }
    } catch (e) {
      debugPrint('Error picking motion sticker: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // RASTERIZE CANVAS TO BYTES & SAVE
  // ──────────────────────────────────────────────────────────────────────────
  Future<Uint8List?> _captureBoundaryToBytes(GlobalKey key) async {
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing sticker image bytes: $e');
      return null;
    }
  }

  Future<void> _exportAndSaveSticker() async {
    setState(() {
      _isExporting = true;
      _exportStatus = 'Exporting sticker...';
    });

    try {
      String finalImageUrl = '';
      String? finalAnimatedUrl;

      final isWebP = _selectedImage != null && _selectedImage!.name.toLowerCase().endsWith('.webp');
      final isGif = _selectedImage != null && _selectedImage!.name.toLowerCase().endsWith('.gif');
      final isMotion = _isMotionMedia || isWebP || isGif;

      // If user uploaded an animated WebP or GIF, preserve raw multi-frame bytes
      if (isMotion && _selectedImageBytes != null && _selectedImageBytes!.isNotEmpty) {
        setState(() => _exportStatus = 'Uploading animated sticker...');
        try {
          final ext = isGif ? 'gif' : 'webp';
          final mime = isGif ? 'image/gif' : 'image/webp';
          final xfile = XFile.fromData(
            _selectedImageBytes!,
            name: 'sticker_${DateTime.now().millisecondsSinceEpoch}.$ext',
            mimeType: mime,
          );
          final uploadResult = await ref.read(imageUploadServiceProvider).uploadImage(xfile);
          finalImageUrl = uploadResult.url;
          finalAnimatedUrl = uploadResult.url;
        } catch (uploadError) {
          debugPrint('Cloud upload fallback for animated sticker: $uploadError');
        }
      }

      if (finalImageUrl.isEmpty) {
        final capturedBytes = await _captureBoundaryToBytes(_photoBoundaryKey);
        if (capturedBytes != null && capturedBytes.isNotEmpty) {
          setState(() => _exportStatus = 'Uploading to Campus Cloud...');
          try {
            final xfile = XFile.fromData(
              capturedBytes,
              name: 'sticker_${DateTime.now().millisecondsSinceEpoch}.png',
              mimeType: 'image/png',
            );
            final uploadResult = await ref.read(imageUploadServiceProvider).uploadImage(xfile);
            finalImageUrl = uploadResult.url;
            if (_isMotionMedia) {
              finalAnimatedUrl = finalImageUrl;
            }
          } catch (uploadError) {
            debugPrint('Cloud upload fallback: $uploadError');
            finalImageUrl = 'https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/sticker_fallback.png';
          }
        }
      }

      if (finalImageUrl.isEmpty) {
        finalImageUrl = 'https://pub-0014553a7b194df8b2d31efb7c6f4921.r2.dev/uploads/sticker_fallback.png';
      }

      setState(() => _exportStatus = 'Saving to your sticker tray...');

      final List<String> parsedTags = _tagsCtrl.text
          .split(',')
          .map((t) => t.trim().replaceAll('#', ''))
          .where((t) => t.isNotEmpty)
          .toList();

      final createdSticker = await ref.read(stickerRepositoryProvider).createSticker(
            title: _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : 'Campus Sticker',
            imageUrl: finalImageUrl,
            animatedUrl: finalAnimatedUrl,
            type: _isMotionMedia ? 'MOTION' : 'PHOTO',
            category: _makerCategory,
            tags: parsedTags,
            isPublic: _isPublic,
          );

      if (createdSticker != null) {
        // Automatically save to local tray
        await ref.read(stickerRepositoryProvider).saveSticker(createdSticker);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.tealAccent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _isPublic
                      ? 'Sticker "${createdSticker?.title ?? 'Sticker'}" saved to tray & published! 🎉'
                      : 'Saved to your "My Tray" ⭐',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

      final resultItem = createdSticker != null
          ? CreatedStickerItem.fromStickerItem(createdSticker)
          : CreatedStickerItem(
              id: 'stk_${DateTime.now().millisecondsSinceEpoch}',
              title: _titleCtrl.text.trim(),
              type: _isMotionMedia ? 'motion' : 'photo',
              cloudUrl: finalImageUrl,
              isPublic: _isPublic,
              category: _makerCategory,
              tags: parsedTags,
            );

      Navigator.pop(context, resultItem);
    } catch (e) {
      debugPrint('Export sticker failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save sticker: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportStatus = '';
        });
      }
    }
  }

  Future<void> _toggleSaveSticker(StickerItem item) async {
    final repo = ref.read(stickerRepositoryProvider);
    final isAlreadySaved = _myStickers.any((s) => s.id == item.id);
    if (isAlreadySaved) {
      await repo.unsaveSticker(item.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed "${item.title}" from My Tray'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      await repo.saveSticker(item);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${item.title}" to My Tray ⭐'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    await _loadMarketplaceAndTray();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.secondaryTeal.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.style_rounded, color: AppColors.secondaryTeal, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Sticker Place',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.secondaryTeal,
          unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
          indicatorColor: AppColors.secondaryTeal,
          indicatorWeight: 3,
          tabs: [
            Tab(
              icon: const Icon(Icons.backpack_rounded, size: 20),
              text: 'Sticker Packs (${_communityStickers.length})',
            ),
            Tab(
              icon: const Icon(Icons.star_rounded, size: 20),
              text: 'My Tray (${_myStickers.length})',
            ),
            const Tab(
              icon: Icon(Icons.add_circle_outline_rounded, size: 20),
              text: 'Create Sticker',
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildStickerPacksTab(isDark),
              _buildMyTrayTab(isDark),
              _buildStickerMakerTab(isDark),
            ],
          ),
          if (_isExporting)
            Container(
              color: Colors.black.withValues(alpha: 0.75),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppColors.secondaryTeal),
                      const SizedBox(height: 16),
                      Text(
                        _exportStatus,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // TAB 1: STICKER PACKS & MARKETPLACE
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildStickerPacksTab(bool isDark) {
    return RefreshIndicator(
      onRefresh: _loadMarketplaceAndTray,
      color: AppColors.secondaryTeal,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // Search Bar
          SizedBox(
            height: 40,
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search campus sticker packs (e.g. #exam, food, hostel)...',
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                          _loadMarketplaceAndTray();
                        },
                        child: const Icon(Icons.clear, size: 16),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white12 : Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white12 : Colors.grey.withValues(alpha: 0.2),
                  ),
                ),
              ),
              onSubmitted: (val) {
                setState(() => _searchQuery = val);
                _loadMarketplaceAndTray();
              },
            ),
          ),
          const SizedBox(height: 10),

          // Category Chips
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _categories.map((cat) {
                final isSel = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(
                      cat == 'ALL' ? '🌟 ALL' : cat,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                    selected: isSel,
                    selectedColor: AppColors.secondaryTeal,
                    backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    checkmarkColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSel ? AppColors.secondaryTeal : (isDark ? Colors.white12 : Colors.black12),
                      ),
                    ),
                    onSelected: (val) {
                      setState(() => _selectedCategory = cat);
                      _loadMarketplaceAndTray();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // Trending Header (if trending stickers exist)
          if (_trendingStickers.isNotEmpty) ...[
            Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                const Text(
                  'Trending Stickers',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Spacer(),
                Text(
                  'Sorted by student uses',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 115,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _trendingStickers.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final stk = _trendingStickers[index];
                  return _buildTrendingCard(stk, isDark);
                },
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Community Sticker Packs Grid
          Row(
            children: [
              const Icon(Icons.explore_rounded, color: AppColors.secondaryTeal, size: 18),
              const SizedBox(width: 6),
              const Text(
                'Campus Stickers & Packs',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Spacer(),
              Text(
                '${_communityStickers.length} available',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (_isLoadingData && _communityStickers.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: AppColors.secondaryTeal),
              ),
            )
          else if (_communityStickers.isEmpty)
            _buildEmptyState(
              icon: Icons.backpack_outlined,
              title: 'No community stickers yet',
              message: 'Be the first student to create and publish a sticker for the campus!',
              actionLabel: 'Create Sticker Now',
              onAction: () => _tabController.animateTo(2),
              isDark: isDark,
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.82,
              ),
              itemCount: _communityStickers.length,
              itemBuilder: (context, index) {
                final stk = _communityStickers[index];
                return _buildMarketplaceCard(stk, isDark);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTrendingCard(StickerItem stk, bool isDark) {
    final isSaved = _myStickers.any((s) => s.id == stk.id);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.pop(context, stk),
      child: Container(
        width: 100,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: stk.isAnimated
                        ? AutoPlayLiveMediaWidget(
                            url: stk.animatedUrl ?? stk.imageUrl,
                            fit: BoxFit.contain,
                          )
                        : (stk.imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: stk.imageUrl,
                                fit: BoxFit.contain,
                                errorWidget: (context, url, error) => Center(
                                  child: Text(
                                    stk.title,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  stk.title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              )),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () => _toggleSaveSticker(stk),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: isSaved ? const Color(0xFFF59E0B) : Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isSaved ? Icons.star_rounded : Icons.star_border_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              stk.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 10),
                const SizedBox(width: 2),
                Text(
                  '${stk.usageCount} uses',
                  style: TextStyle(fontSize: 9, color: isDark ? Colors.white60 : Colors.black54),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketplaceCard(StickerItem stk, bool isDark) {
    final isSaved = _myStickers.any((s) => s.id == stk.id);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.pop(context, stk),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: stk.isAnimated
                        ? AutoPlayLiveMediaWidget(
                            url: stk.animatedUrl ?? stk.imageUrl,
                            fit: BoxFit.contain,
                          )
                        : (stk.imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: stk.imageUrl,
                                fit: BoxFit.contain,
                                errorWidget: (context, url, error) => Center(
                                  child: Text(
                                    stk.title,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  stk.title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              )),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () => _toggleSaveSticker(stk),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isSaved ? const Color(0xFFF59E0B) : Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isSaved ? Icons.star_rounded : Icons.star_border_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              stk.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 22,
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  backgroundColor: isSaved ? AppColors.secondaryTeal.withValues(alpha: 0.15) : null,
                  side: BorderSide(
                    color: isSaved ? AppColors.secondaryTeal : Colors.grey.withValues(alpha: 0.3),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _toggleSaveSticker(stk),
                child: Text(
                  isSaved ? 'In Tray ⭐' : '+ Add',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSaved ? AppColors.secondaryTeal : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // TAB 2: MY TRAY & FAVORITES
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildMyTrayTab(bool isDark) {
    if (_myStickers.isEmpty) {
      return _buildEmptyState(
        icon: Icons.star_outline_rounded,
        title: 'Your Sticker Tray is Empty',
        message: 'Save stickers from the Sticker Packs or make your own with custom curves & photos!',
        actionLabel: 'Create a Sticker',
        onAction: () => _tabController.animateTo(2),
        isDark: isDark,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMarketplaceAndTray,
      color: AppColors.secondaryTeal,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Row(
            children: [
              const Text('⭐', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Text(
                'My Active Sticker Tray',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: () => _tabController.animateTo(2),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('New', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Tap any sticker to send directly into your chat, or remove it from your tray.',
            style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white60 : Colors.black54),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.95,
            ),
            itemCount: _myStickers.length,
            itemBuilder: (context, index) {
              final stk = _myStickers[index];
              return _buildMyTrayTile(stk, isDark);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMyTrayTile(StickerItem stk, bool isDark) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        ref.read(stickerRepositoryProvider).useSticker(stk.id);
        Navigator.pop(context, stk);
      },
      onLongPress: () => _showRemoveTrayDialog(stk),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(5),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: stk.imageUrl.isNotEmpty
                  ? AutoPlayLiveMediaWidget(
                      url: stk.animatedUrl ?? stk.imageUrl,
                      fit: BoxFit.contain,
                      errorWidget: Center(
                        child: Text(
                          stk.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        stk.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                ),
                child: Text(
                  stk.title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRemoveTrayDialog(StickerItem stk) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Manage "${stk.title}"',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.send_rounded, color: AppColors.secondaryTeal),
                title: const Text('Send to Chat'),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(stickerRepositoryProvider).useSticker(stk.id);
                  Navigator.pop(context, stk);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: const Text('Remove from My Tray', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(ctx);
                  _toggleSaveSticker(stk);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // TAB 3: STICKER MAKER (ADJUSTABLE CURVE SLIDER & DIE-CUT BORDER)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildStickerMakerTab(bool isDark) {
    final borderRadius = BorderRadius.circular(_cornerRadius);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Live Sticker Preview Box with Smooth Corner Curvature
        Center(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: RepaintBoundary(
              key: _photoBoundaryKey,
              child: Container(
                width: 175,
                height: 175,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: borderRadius,
                  border: _hasWhiteContour
                      ? Border.all(color: Colors.white, width: _contourWidth)
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Direct memory byte rendering
                      if (_selectedImageBytes != null)
                        Image.memory(
                          _selectedImageBytes!,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                          errorBuilder: (context, error, stackTrace) => _buildPlaceholderPhoto(),
                        )
                      else if (_selectedImage != null)
                        AutoPlayLiveMediaWidget(
                          url: _selectedImage!.path,
                          fit: BoxFit.contain,
                          errorWidget: _buildPlaceholderPhoto(),
                        )
                      else
                        _buildPlaceholderPhoto(),

                      // Caption overlay banner at bottom
                      if (_captionCtrl.text.isNotEmpty)
                        Positioned(
                          bottom: 8,
                          left: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white24, width: 0.8),
                            ),
                            child: Text(
                              _captionCtrl.text,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Media Picker Action Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.tonalIcon(
              icon: const Icon(Icons.camera_alt_rounded, size: 16),
              label: const Text('Take Snap', style: TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onPressed: () => _pickPhoto(ImageSource.camera),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.photo_library_rounded, size: 16),
              label: const Text('Photo / WebP', style: TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onPressed: () => _pickPhoto(ImageSource.gallery),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.motion_photos_on_rounded, size: 16),
              label: const Text('Motion / GIF', style: TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onPressed: _pickMotionGifOrVideo,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ──────────────────────────────────────────────────────────────────
        // ADJUSTABLE CORNER CURVE SLIDER & QUICK PRESETS
        // ──────────────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.grey.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.rounded_corner_rounded, color: AppColors.secondaryTeal, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Corner Curvature',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryTeal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_cornerRadius.toInt()}px',
                      style: const TextStyle(
                        color: AppColors.secondaryTeal,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Slide to fine-tune from sharp square to smooth squircle or pill/circle',
                style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
              ),
              Slider(
                value: _cornerRadius,
                min: 0.0,
                max: 90.0,
                activeColor: AppColors.secondaryTeal,
                onChanged: (val) => setState(() => _cornerRadius = val),
              ),
              // Preset chips for instant curves
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCurvePresetChip('Sharp', 0.0, isDark),
                  _buildCurvePresetChip('Soft', 16.0, isDark),
                  _buildCurvePresetChip('Squircle', 32.0, isDark),
                  _buildCurvePresetChip('Pill', 60.0, isDark),
                  _buildCurvePresetChip('Circle', 90.0, isDark),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ──────────────────────────────────────────────────────────────────
        // DIE-CUT WHITE CONTOUR BORDER
        // ──────────────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.grey.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'White Contour Die-Cut Border',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Gives an authentic die-cut sticker look',
                  style: TextStyle(fontSize: 11),
                ),
                value: _hasWhiteContour,
                activeThumbColor: AppColors.secondaryTeal,
                onChanged: (val) => setState(() => _hasWhiteContour = val),
              ),
              if (_hasWhiteContour) ...[
                Row(
                  children: [
                    const Text('Border Thickness', style: TextStyle(fontSize: 12)),
                    const Spacer(),
                    Text('${_contourWidth.toInt()}px',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
                Slider(
                  value: _contourWidth,
                  min: 2.0,
                  max: 16.0,
                  activeColor: AppColors.secondaryTeal,
                  onChanged: (val) => setState(() => _contourWidth = val),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ──────────────────────────────────────────────────────────────────
        // TEXT CAPTION & METADATA
        // ──────────────────────────────────────────────────────────────────
        TextField(
          controller: _captionCtrl,
          onChanged: (val) => setState(() {
            _titleCtrl.text = val.isNotEmpty ? val : 'Campus Sticker';
          }),
          decoration: InputDecoration(
            labelText: 'Sticker Caption Overlay',
            hintText: 'e.g. ABUAD VIBES, TDB NO SLEEP',
            prefixIcon: const Icon(Icons.title_rounded, color: AppColors.secondaryTeal),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),

        TextField(
          controller: _titleCtrl,
          decoration: InputDecoration(
            labelText: 'Sticker Title',
            hintText: 'e.g. Exam Rush',
            prefixIcon: const Icon(Icons.label_outline_rounded, color: AppColors.secondaryTeal),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Category Selector & Public Switch
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.grey.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: ['CAMPUS', 'MEME', 'REACTION', 'STUDY', 'SPORTS'].map((c) {
                  final isSel = _makerCategory == c;
                  return ChoiceChip(
                    label: Text(c, style: const TextStyle(fontSize: 10.5)),
                    selected: isSel,
                    selectedColor: AppColors.secondaryTeal,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                    ),
                    onSelected: (val) => setState(() => _makerCategory = c),
                  );
                }).toList(),
              ),
              const Divider(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Publish to Campus Marketplace',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text('Other students can discover and add your sticker',
                    style: TextStyle(fontSize: 11)),
                value: _isPublic,
                activeThumbColor: AppColors.secondaryTeal,
                onChanged: (val) => setState(() => _isPublic = val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Save & Add to Tray Button
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.secondaryTeal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.cloud_upload_rounded),
            label: const Text(
              'Save & Add to My Tray ⭐',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            onPressed: _exportAndSaveSticker,
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildCurvePresetChip(String label, double value, bool isDark) {
    final isSel = (_cornerRadius - value).abs() < 3.0;
    return GestureDetector(
      onTap: () => setState(() => _cornerRadius = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSel ? AppColors.secondaryTeal : (isDark ? const Color(0xFF0F172A) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSel ? AppColors.secondaryTeal : Colors.grey.withValues(alpha: 0.25),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
            color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderPhoto() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryInk,
            AppColors.secondaryTeal,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('✨', style: TextStyle(fontSize: 42)),
            SizedBox(height: 6),
            Text(
              'Pick a Photo or WebP',
              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
    required bool isDark,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.grey.withValues(alpha: 0.2),
                ),
              ),
              child: Icon(icon, size: 40, color: AppColors.secondaryTeal),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.tonalIcon(
              onPressed: onAction,
              icon: const Icon(Icons.add, size: 16),
              label: Text(actionLabel),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.secondaryTeal.withValues(alpha: 0.15),
                foregroundColor: AppColors.secondaryTeal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
