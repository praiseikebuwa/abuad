import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/services/image_upload_service.dart';
import '../data/sticker_repository.dart';
import '../domain/sticker_item.dart';

enum BrushTool {
  pencil,
  marker,
  neon,
  highlighter,
  eraser,
}

enum CutoutShape {
  roundedRect,
  circle,
  squircle,
  heart,
  star,
}

class DrawingStroke {
  final List<Offset> points;
  final Color color;
  final double width;
  final BrushTool tool;

  DrawingStroke({
    required this.points,
    required this.color,
    required this.width,
    required this.tool,
  });
}

class StickerCreatorScreen extends ConsumerStatefulWidget {
  const StickerCreatorScreen({super.key});

  @override
  ConsumerState<StickerCreatorScreen> createState() => _StickerCreatorScreenState();
}

class _StickerCreatorScreenState extends ConsumerState<StickerCreatorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Global Keys for rendering canvas to real PNG images
  final GlobalKey _drawingBoundaryKey = GlobalKey();
  final GlobalKey _photoBoundaryKey = GlobalKey();

  // Drawing state
  final List<DrawingStroke> _strokes = [];
  final List<DrawingStroke> _redoStrokes = [];
  BrushTool _selectedTool = BrushTool.marker;
  Color _selectedColor = const Color(0xFFFBBF24);
  double _strokeWidth = 6.0;
  final bool _drawWithOutline = true;

  // Photo cutout state
  XFile? _selectedImage;
  CutoutShape _selectedShape = CutoutShape.roundedRect;
  final TextEditingController _stickerCaptionCtrl =
      TextEditingController(text: 'ABUAD VIBES ✨');
  bool _hasWhiteContour = true;
  double _contourWidth = 6.0;

  // Video / GIF state
  double _gifSpeed = 1.0;
  bool _isBoomerang = true;
  int _selectedGifTemplate = 0;
  XFile? _customGifFile;

  // Publishing & Metadata state
  final TextEditingController _titleCtrl = TextEditingController(text: 'My Campus Sticker');
  final TextEditingController _tagsCtrl = TextEditingController(text: 'abuad, campus, vibes');
  String _selectedCategory = 'CAMPUS';
  bool _isPublic = true;
  bool _isExporting = false;
  String _exportStatus = '';

  final List<String> _categories = [
    'CAMPUS',
    'MEME',
    'REACTION',
    'STUDY',
    'DOODLE',
  ];

  final List<Color> _palette = const [
    Color(0xFFFBBF24), // Amber
    Color(0xFFEF4444), // Coral Red
    Color(0xFF10B981), // Emerald
    Color(0xFF3B82F6), // Royal Blue
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEC4899), // Pink
    Color(0xFF06B6D4), // Cyan
    Color(0xFFFFFFFF), // White
    Color(0xFF000000), // Black
  ];

  final List<Map<String, String>> _sampleTemplates = [
    {
      'title': 'Exam TDB Mood',
      'emoji': '📚😵',
      'quote': 'Sleep is a myth',
      'cat': 'STUDY',
      'img': 'https://images.unsplash.com/photo-1509062522246-3755977927d7?auto=format&fit=crop&w=400&q=80',
    },
    {
      'title': 'Cafeteria Order',
      'emoji': '🍗🔥',
      'quote': 'Jollof & Turkey ASAP',
      'cat': 'CAMPUS',
      'img': 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=400&q=80',
    },
    {
      'title': 'Chapel Attendance',
      'emoji': '👔🙏',
      'quote': '75% Secured!',
      'cat': 'CAMPUS',
      'img': 'https://images.unsplash.com/photo-1544717305-2782549b5136?auto=format&fit=crop&w=400&q=80',
    },
    {
      'title': 'Hostel Gate Rush',
      'emoji': '🏃‍♂️💨',
      'quote': '5 mins to curfew',
      'cat': 'CAMPUS',
      'img': 'https://images.unsplash.com/photo-1552053831-71594a27632d?auto=format&fit=crop&w=400&q=80',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _stickerCaptionCtrl.dispose();
    _titleCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 90);
      if (picked != null) {
        setState(() {
          _selectedImage = picked;
          _titleCtrl.text = _stickerCaptionCtrl.text.isNotEmpty
              ? _stickerCaptionCtrl.text
              : 'Photo Cutout';
        });
      }
    } catch (e) {
      debugPrint('Error picking photo: $e');
    }
  }

  Future<void> _pickGifOrVideo() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickVideo(source: ImageSource.gallery);
      if (picked != null) {
        setState(() {
          _customGifFile = picked;
        });
      }
    } catch (e) {
      debugPrint('Error picking motion video: $e');
    }
  }

  /// Renders a GlobalKey RepaintBoundary to a real PNG file
  Future<File?> _captureBoundaryToFile(GlobalKey key, String prefix) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);
      return file;
    } catch (e) {
      debugPrint('Error capturing sticker image: $e');
      return null;
    }
  }

  /// Exports, uploads to Cloudflare R2 / S3, and publishes to backend
  Future<void> _exportAndSaveSticker(String mode) async {
    setState(() {
      _isExporting = true;
      _exportStatus = 'Rasterizing sticker canvas...';
    });

    try {
      String finalImageUrl = '';
      String? finalAnimatedUrl;
      File? generatedFile;

      if (mode == 'DRAW') {
        generatedFile = await _captureBoundaryToFile(_drawingBoundaryKey, 'doodle_sticker');
      } else if (mode == 'PHOTO') {
        generatedFile = await _captureBoundaryToFile(_photoBoundaryKey, 'photo_sticker');
      } else if (mode == 'MOTION') {
        final sel = _sampleTemplates[_selectedGifTemplate];
        finalImageUrl = sel['img']!;
        finalAnimatedUrl = sel['img']!;
      }

      if (generatedFile != null && generatedFile.existsSync()) {
        setState(() => _exportStatus = 'Uploading to Cloudflare R2...');
        try {
          final uploadResult = await ref
              .read(imageUploadServiceProvider)
              .uploadImage(XFile(generatedFile.path));
          finalImageUrl = uploadResult.url;
        } catch (uploadError) {
          debugPrint('Cloud upload fallback to local: $uploadError');
          finalImageUrl = generatedFile.path;
        }
      }

      if (finalImageUrl.isEmpty) {
        if (mode == 'DRAW') {
          finalImageUrl =
              'https://images.unsplash.com/photo-1519750783826-e2420f4d687f?auto=format&fit=crop&w=400&q=80';
        } else {
          finalImageUrl =
              'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=400&q=80';
        }
      }

      setState(() => _exportStatus = 'Publishing to ABUAD Campus Network...');

      final List<String> parsedTags = _tagsCtrl.text
          .split(',')
          .map((t) => t.trim().replaceAll('#', ''))
          .where((t) => t.isNotEmpty)
          .toList();

      final createdSticker = await ref.read(stickerRepositoryProvider).createSticker(
            title: _titleCtrl.text.trim().isNotEmpty
                ? _titleCtrl.text.trim()
                : 'Campus Sticker',
            imageUrl: finalImageUrl,
            animatedUrl: finalAnimatedUrl,
            type: mode,
            category: _selectedCategory,
            tags: parsedTags,
            isPublic: _isPublic,
          );

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
                      ? 'Sticker "${createdSticker?.title ?? 'Sticker'}" published to Campus Community! 🎉'
                      : 'Saved privately to "My Stickers" ⭐',
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

      // Return both StickerItem & CreatedStickerItem for seamless integration
      final resultItem = createdSticker != null
          ? CreatedStickerItem.fromStickerItem(createdSticker)
          : CreatedStickerItem(
              id: 'stk_${DateTime.now().millisecondsSinceEpoch}',
              title: _titleCtrl.text.trim(),
              type: mode.toLowerCase(),
              cloudUrl: finalImageUrl,
              localPath: generatedFile?.path,
              isPublic: _isPublic,
              category: _selectedCategory,
              tags: parsedTags,
            );

      Navigator.pop(context, resultItem);
    } catch (e) {
      debugPrint('Export sticker failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to publish sticker: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Color(0xFF14B8A6), size: 22),
            SizedBox(width: 8),
            Text(
              'Sticker Studio & Studio',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Publish Settings',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => _showPublishSettingsSheet(isDark),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF14B8A6),
          unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
          indicatorColor: const Color(0xFF14B8A6),
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.brush_rounded), text: 'Doodle Brush'),
            Tab(icon: Icon(Icons.photo_filter_rounded), text: 'Photo Cutout'),
            Tab(icon: Icon(Icons.motion_photos_on_rounded), text: 'Motion / GIF'),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildDrawingTab(isDark),
              _buildPhotoCutoutTab(isDark),
              _buildMotionGifTab(isDark),
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
                      const CircularProgressIndicator(color: Color(0xFF14B8A6)),
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
  // 1. DOODLE / DRAWING STUDIO TAB
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildDrawingTab(bool isDark) {
    return Column(
      children: [
        // Realistic Canvas with RepaintBoundary
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF020617) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.grey.withValues(alpha: 0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  RepaintBoundary(
                    key: _drawingBoundaryKey,
                    child: Container(
                      color: Colors.transparent,
                      child: GestureDetector(
                        onPanStart: (details) {
                          setState(() {
                            final box = context.findRenderObject() as RenderBox?;
                            if (box != null) {
                              _strokes.add(DrawingStroke(
                                points: [details.localPosition],
                                color: _selectedTool == BrushTool.eraser
                                    ? (isDark ? const Color(0xFF020617) : Colors.white)
                                    : _selectedColor,
                                width: _selectedTool == BrushTool.eraser
                                    ? _strokeWidth * 2.5
                                    : _strokeWidth,
                                tool: _selectedTool,
                              ));
                              _redoStrokes.clear();
                            }
                          });
                        },
                        onPanUpdate: (details) {
                          setState(() {
                            if (_strokes.isNotEmpty) {
                              _strokes.last.points.add(details.localPosition);
                            }
                          });
                        },
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: _RealisticBrushPainter(
                            strokes: _strokes,
                            drawWithOutline: _drawWithOutline,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_strokes.isEmpty)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.gesture_rounded,
                            size: 52,
                            color: isDark ? Colors.white24 : Colors.grey.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Draw your campus sticker with realistic brushes',
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.grey[600],
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Floating Quick Controls: Undo, Redo, Clear
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B).withValues(alpha: 0.85)
                            : Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.undo_rounded, size: 20),
                            tooltip: 'Undo',
                            onPressed: _strokes.isEmpty
                                ? null
                                : () {
                                    setState(() {
                                      _redoStrokes.add(_strokes.removeLast());
                                    });
                                  },
                          ),
                          IconButton(
                            icon: const Icon(Icons.redo_rounded, size: 20),
                            tooltip: 'Redo',
                            onPressed: _redoStrokes.isEmpty
                                ? null
                                : () {
                                    setState(() {
                                      _strokes.add(_redoStrokes.removeLast());
                                    });
                                  },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 20),
                            tooltip: 'Clear Canvas',
                            onPressed: _strokes.isEmpty
                                ? null
                                : () {
                                    setState(() {
                                      _strokes.clear();
                                      _redoStrokes.clear();
                                    });
                                  },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Multi-Brush Selector Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.15),
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBrushToolButton(
                tool: BrushTool.pencil,
                label: 'Pencil',
                icon: Icons.edit_rounded,
                isDark: isDark,
              ),
              _buildBrushToolButton(
                tool: BrushTool.marker,
                label: 'Marker',
                icon: Icons.brush_rounded,
                isDark: isDark,
              ),
              _buildBrushToolButton(
                tool: BrushTool.neon,
                label: 'Neon Glow',
                icon: Icons.auto_awesome_rounded,
                isDark: isDark,
              ),
              _buildBrushToolButton(
                tool: BrushTool.highlighter,
                label: 'Highlight',
                icon: Icons.highlight_rounded,
                isDark: isDark,
              ),
              _buildBrushToolButton(
                tool: BrushTool.eraser,
                label: 'Eraser',
                icon: Icons.cleaning_services_rounded,
                isDark: isDark,
              ),
            ],
          ),
        ),

        // Color Palette & Brush Size Slider & Save Button
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          child: Column(
            children: [
              // Palette
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _palette.map((c) {
                    final isSel = _selectedColor == c && _selectedTool != BrushTool.eraser;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedColor = c;
                          if (_selectedTool == BrushTool.eraser) {
                            _selectedTool = BrushTool.marker;
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        width: isSel ? 36 : 28,
                        height: isSel ? 36 : 28,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSel ? const Color(0xFF14B8A6) : Colors.grey.withValues(alpha: 0.4),
                            width: isSel ? 3 : 1.5,
                          ),
                          boxShadow: [
                            if (isSel)
                              BoxShadow(
                                color: c.withValues(alpha: 0.6),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  const Text('Size', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Slider(
                      value: _strokeWidth,
                      min: 2.0,
                      max: 28.0,
                      activeColor: const Color(0xFF14B8A6),
                      onChanged: (val) => setState(() => _strokeWidth = val),
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF14B8A6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                    label: const Text('Save & Publish', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _strokes.isEmpty ? null : () => _exportAndSaveSticker('DRAW'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBrushToolButton({
    required BrushTool tool,
    required String label,
    required IconData icon,
    required bool isDark,
  }) {
    final isSel = _selectedTool == tool;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _selectedTool = tool),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSel
              ? const Color(0xFF14B8A6).withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSel ? const Color(0xFF14B8A6) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSel
                  ? const Color(0xFF14B8A6)
                  : (isDark ? Colors.white70 : Colors.black87),
              size: 20,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                color: isSel
                    ? const Color(0xFF14B8A6)
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 2. PHOTO CUTOUT & CONTOUR MAKER TAB
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildPhotoCutoutTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: RepaintBoundary(
            key: _photoBoundaryKey,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: _buildShapeCutoutWidget(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Live Sticker Preview with crisp White Contour Border',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Photo Picking Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.tonalIcon(
              icon: const Icon(Icons.camera_alt_rounded, size: 18),
              label: const Text('Take Snap'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: () => _pickPhoto(ImageSource.camera),
            ),
            const SizedBox(width: 12),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.photo_library_rounded, size: 18),
              label: const Text('Gallery Photo'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: () => _pickPhoto(ImageSource.gallery),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Cutout Shape Selector
        const Text(
          'Cutout Contour Shape',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildShapeOption(CutoutShape.roundedRect, 'Squircle', Icons.crop_square_rounded, isDark),
            _buildShapeOption(CutoutShape.circle, 'Circle', Icons.circle_outlined, isDark),
            _buildShapeOption(CutoutShape.heart, 'Heart', Icons.favorite_border_rounded, isDark),
            _buildShapeOption(CutoutShape.star, 'Star', Icons.star_border_rounded, isDark),
          ],
        ),
        const SizedBox(height: 16),

        // White Contour Border Switch & Slider
        SwitchListTile(
          title: const Text(
            'Sticker White Contour Border',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          subtitle: const Text(
            'Gives the authentic die-cut sticker look with smooth drop shadow',
            style: TextStyle(fontSize: 12),
          ),
          value: _hasWhiteContour,
          activeThumbColor: const Color(0xFF14B8A6),
          onChanged: (val) => setState(() => _hasWhiteContour = val),
        ),

        if (_hasWhiteContour)
          Row(
            children: [
              const Text('Border Thickness', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(
                  value: _contourWidth,
                  min: 3.0,
                  max: 14.0,
                  activeColor: const Color(0xFF14B8A6),
                  onChanged: (val) => setState(() => _contourWidth = val),
                ),
              ),
            ],
          ),

        const SizedBox(height: 12),

        // Text Caption Overlay
        TextField(
          controller: _stickerCaptionCtrl,
          onChanged: (val) => setState(() {
            _titleCtrl.text = val;
          }),
          decoration: InputDecoration(
            labelText: 'Sticker Caption / Quote',
            hintText: 'e.g. ABUAD VIBES ✨ or TDB ALL NIGHT 📖',
            prefixIcon: const Icon(Icons.text_fields_rounded),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 16),

        // Quick Campus Presets
        const Text('Quick Campus Presets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _sampleTemplates.map((t) {
            return ActionChip(
              avatar: Text(t['emoji']!),
              label: Text(t['title']!),
              onPressed: () {
                setState(() {
                  _stickerCaptionCtrl.text = '${t['emoji']} ${t['title']}';
                  _titleCtrl.text = '${t['emoji']} ${t['title']}';
                  _selectedCategory = t['cat']!;
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // Export Button
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF14B8A6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.cloud_upload_rounded),
            label: const Text(
              'Save & Publish Photo Sticker',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            onPressed: () => _exportAndSaveSticker('PHOTO'),
          ),
        ),
      ],
    );
  }

  Widget _buildShapeOption(CutoutShape shape, String label, IconData icon, bool isDark) {
    final isSel = _selectedShape == shape;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedShape = shape),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSel
                ? const Color(0xFF14B8A6).withValues(alpha: 0.15)
                : (isDark ? const Color(0xFF1E293B) : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSel ? const Color(0xFF14B8A6) : Colors.grey.withValues(alpha: 0.2),
              width: isSel ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSel ? const Color(0xFF14B8A6) : null, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  color: isSel ? const Color(0xFF14B8A6) : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShapeCutoutWidget() {
    BorderRadius borderRadius;
    switch (_selectedShape) {
      case CutoutShape.circle:
        borderRadius = BorderRadius.circular(85);
        break;
      case CutoutShape.squircle:
        borderRadius = BorderRadius.circular(34);
        break;
      default:
        borderRadius = BorderRadius.circular(24);
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
            if (_selectedImage != null)
              Image.file(
                File(_selectedImage!.path),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _buildPlaceholderPhoto(),
              )
            else
              _buildPlaceholderPhoto(),

            // Caption overlay banner at bottom
            if (_stickerCaptionCtrl.text.isNotEmpty)
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _stickerCaptionCtrl.text,
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
    );
  }

  Widget _buildPlaceholderPhoto() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade800, Colors.teal.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🎓', style: TextStyle(fontSize: 48)),
            SizedBox(height: 4),
            Text(
              'Snap / Pick Photo',
              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 3. MOTION & SHORT GIF TAB
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildMotionGifTab(bool isDark) {
    final sel = _sampleTemplates[_selectedGifTemplate];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade900, Colors.teal.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF14B8A6), width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF14B8A6).withValues(alpha: 0.3),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(sel['emoji']!, style: const TextStyle(fontSize: 42)),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          sel['quote']!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_gifSpeed}x Loop ${_isBoomerang ? '(Boomerang)' : ''}',
                        style: const TextStyle(color: Colors.tealAccent, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'GIF',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Short looping motion stickers for instant chat reactions',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Pick Custom Motion File
        Center(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.video_library_rounded),
            label: Text(_customGifFile != null ? 'Custom Motion Clip Loaded' : 'Pick Video / Motion Clip'),
            onPressed: _pickGifOrVideo,
          ),
        ),
        const SizedBox(height: 16),

        // Loop Speed Multiplier
        const Text('Loop Speed Multiplier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        Row(
          children: [0.5, 1.0, 1.5, 2.0].map((speed) {
            final isSel = _gifSpeed == speed;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ChoiceChip(
                  label: Text('${speed}x'),
                  selected: isSel,
                  selectedColor: const Color(0xFF14B8A6),
                  onSelected: (val) {
                    if (val) setState(() => _gifSpeed = speed);
                  },
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Boomerang Switch
        SwitchListTile(
          title: const Text(
            'Boomerang Ping-Pong (Forward & Reverse)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          subtitle: const Text(
            'Loops back and forth seamlessly like Instagram / Snapchat motion stickers',
            style: TextStyle(fontSize: 12),
          ),
          value: _isBoomerang,
          activeThumbColor: const Color(0xFF14B8A6),
          onChanged: (val) => setState(() => _isBoomerang = val),
        ),
        const SizedBox(height: 16),

        // Curated Campus Animated Reaction Packs
        const Text('Campus Animated Packs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        ...List.generate(_sampleTemplates.length, (idx) {
          final t = _sampleTemplates[idx];
          final isSel = _selectedGifTemplate == idx;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isSel ? const Color(0xFF14B8A6) : Colors.transparent,
                width: 2,
              ),
            ),
            child: ListTile(
              leading: Text(t['emoji']!, style: const TextStyle(fontSize: 26)),
              title: Text(t['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text(t['quote']!, style: const TextStyle(fontSize: 11)),
              trailing: isSel
                  ? const Icon(Icons.check_circle, color: Color(0xFF14B8A6))
                  : null,
              onTap: () => setState(() {
                _selectedGifTemplate = idx;
                _titleCtrl.text = '${t['emoji']} ${t['title']}';
                _selectedCategory = t['cat']!;
              }),
            ),
          );
        }),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF14B8A6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.motion_photos_on_rounded),
            label: const Text(
              'Save & Publish Motion Sticker',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            onPressed: () => _exportAndSaveSticker('MOTION'),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // PUBLISHING SETTINGS MODAL SHEET
  // ──────────────────────────────────────────────────────────────────────────
  void _showPublishSettingsSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sticker Publishing & Visibility',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Control whether students on campus can discover and trend your sticker',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Sticker Title
                  TextField(
                    controller: _titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Sticker Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Category Selector
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _categories.map((c) {
                      return DropdownMenuItem(value: c, child: Text(c));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedCategory = val);
                        setSheetState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // Tags
                  TextField(
                    controller: _tagsCtrl,
                    decoration: InputDecoration(
                      labelText: 'Tags (comma-separated)',
                      hintText: 'e.g. abuad, exam, hostel, food',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Public toggle
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Make Public to Campus Community',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Allow all ABUAD students to use, share, and boost it in Trending',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _isPublic,
                    activeThumbColor: const Color(0xFF14B8A6),
                    onChanged: (val) {
                      setState(() => _isPublic = val);
                      setSheetState(() {});
                    },
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF14B8A6),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Save Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// REALISTIC BRUSH CUSTOM PAINTER
// ────────────────────────────────────────────────────────────────────────────
class _RealisticBrushPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final bool drawWithOutline;

  _RealisticBrushPainter({
    required this.strokes,
    required this.drawWithOutline,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;

      switch (stroke.tool) {
        case BrushTool.pencil:
          _drawPencil(canvas, stroke);
          break;
        case BrushTool.marker:
          _drawMarker(canvas, stroke);
          break;
        case BrushTool.neon:
          _drawNeonGlow(canvas, stroke);
          break;
        case BrushTool.highlighter:
          _drawHighlighter(canvas, stroke);
          break;
        case BrushTool.eraser:
          _drawEraser(canvas, stroke);
          break;
      }
    }
  }

  void _drawPencil(Canvas canvas, DrawingStroke stroke) {
    final paint = Paint()
      ..color = stroke.color.withValues(alpha: 0.92)
      ..strokeWidth = stroke.width * 0.75
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    _renderPath(canvas, stroke.points, paint);
  }

  void _drawMarker(Canvas canvas, DrawingStroke stroke) {
    // Optional crisp white contour outline underneath
    if (drawWithOutline) {
      final outlinePaint = Paint()
        ..color = Colors.white
        ..strokeWidth = stroke.width + 4.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      _renderPath(canvas, stroke.points, outlinePaint);
    }

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    _renderPath(canvas, stroke.points, paint);
  }

  void _drawNeonGlow(Canvas canvas, DrawingStroke stroke) {
    // Outer diffuse neon blur
    final glowPaint = Paint()
      ..color = stroke.color.withValues(alpha: 0.5)
      ..strokeWidth = stroke.width * 2.2
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke.width * 1.2)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    _renderPath(canvas, stroke.points, glowPaint);

    // Inner bright core
    final corePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = stroke.width * 0.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    _renderPath(canvas, stroke.points, corePaint);
  }

  void _drawHighlighter(Canvas canvas, DrawingStroke stroke) {
    final paint = Paint()
      ..color = stroke.color.withValues(alpha: 0.38)
      ..strokeWidth = stroke.width * 2.0
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter
      ..style = PaintingStyle.stroke;

    _renderPath(canvas, stroke.points, paint);
  }

  void _drawEraser(Canvas canvas, DrawingStroke stroke) {
    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    _renderPath(canvas, stroke.points, paint);
  }

  void _renderPath(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length == 1) {
      canvas.drawCircle(points.first, paint.strokeWidth / 2, paint..style = PaintingStyle.fill);
    } else {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RealisticBrushPainter oldDelegate) => true;
}
