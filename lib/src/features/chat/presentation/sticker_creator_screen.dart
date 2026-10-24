import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CreatedStickerItem {
  final String id;
  final String title;
  final String type; // 'draw', 'photo', 'gif'
  final String? emojiOrText;
  final Color? baseColor;
  final String? localPath;
  final bool isFavorite;

  const CreatedStickerItem({
    required this.id,
    required this.title,
    required this.type,
    this.emojiOrText,
    this.baseColor,
    this.localPath,
    this.isFavorite = true,
  });
}

class StickerCreatorScreen extends StatefulWidget {
  const StickerCreatorScreen({super.key});

  @override
  State<StickerCreatorScreen> createState() => _StickerCreatorScreenState();
}

class _StickerCreatorScreenState extends State<StickerCreatorScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Drawing state
  final List<List<Offset>> _drawnLines = [];
  final List<Color> _lineColors = [];
  final List<double> _lineSizes = [];
  Color _selectedColor = Colors.amber;
  double _strokeWidth = 5.0;

  // Photo sticker state
  XFile? _selectedImage;
  final TextEditingController _stickerCaptionCtrl = TextEditingController(text: 'ABUAD VIBES ✨');
  bool _hasWhiteOutline = true;

  // Video / GIF state
  double _gifSpeed = 1.0;
  bool _isBoomerang = true;
  int _selectedGifTemplate = 0;

  final List<Map<String, String>> _sampleTemplates = [
    {'title': 'Exam Mood', 'emoji': '📚😵', 'quote': 'Sleep is a myth'},
    {'title': 'Talent Cafeteria', 'emoji': '🍗🔥', 'quote': 'Rice & Turkey order'},
    {'title': 'Chapel Sunday', 'emoji': '👔🙏', 'quote': '75% Attendance secure'},
    {'title': 'Hostel Gate', 'emoji': '🏃‍♂️💨', 'quote': 'Curfew in 5 minutes!'},
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
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked != null) {
      setState(() {
        _selectedImage = picked;
      });
    }
  }

  void _finishAndSaveSticker(String type, String title, {String? previewText, Color? color}) {
    final newSticker = CreatedStickerItem(
      id: 'stk_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      type: type,
      emojiOrText: previewText ?? _stickerCaptionCtrl.text,
      baseColor: color ?? _selectedColor,
      localPath: _selectedImage?.path,
      isFavorite: true,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sticker "$title" saved to your collection!'),
        backgroundColor: Colors.teal.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.pop(context, newSticker);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.tealAccent, size: 20),
            SizedBox(width: 8),
            Text('Sticker & GIF Creator'),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.tealAccent,
          indicatorColor: Colors.tealAccent,
          tabs: const [
            Tab(icon: Icon(Icons.brush_rounded), text: 'Doodle / Draw'),
            Tab(icon: Icon(Icons.photo_filter_rounded), text: 'Photo Cutout'),
            Tab(icon: Icon(Icons.gif_box_rounded), text: 'Short GIF / Loop'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDrawingTab(isDark),
          _buildPhotoTab(isDark),
          _buildGifTab(isDark),
        ],
      ),
    );
  }

  // 1. DOODLE / DRAW TAB
  Widget _buildDrawingTab(bool isDark) {
    return Column(
      children: [
        // Compact Canvas preview
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.black : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            child: Stack(
              children: [
                GestureDetector(
                  onPanStart: (details) {
                    setState(() {
                      final box = context.findRenderObject() as RenderBox?;
                      if (box != null) {
                        _drawnLines.add([details.localPosition]);
                        _lineColors.add(_selectedColor);
                        _lineSizes.add(_strokeWidth);
                      }
                    });
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      if (_drawnLines.isNotEmpty) {
                        _drawnLines.last.add(details.localPosition);
                      }
                    });
                  },
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _DoodlePainter(
                      lines: _drawnLines,
                      colors: _lineColors,
                      sizes: _lineSizes,
                    ),
                  ),
                ),
                if (_drawnLines.isEmpty)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.gesture, size: 48, color: Colors.grey.withOpacity(0.4)),
                        const SizedBox(height: 8),
                        Text(
                          'Doodle or draw your sticker with your finger',
                          style: TextStyle(color: Colors.grey.withOpacity(0.7), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Row(
                    children: [
                      IconButton.filledTonal(
                        icon: const Icon(Icons.undo, size: 18),
                        onPressed: _drawnLines.isEmpty
                            ? null
                            : () {
                                setState(() {
                                  _drawnLines.removeLast();
                                  _lineColors.removeLast();
                                  _lineSizes.removeLast();
                                });
                              },
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: _drawnLines.isEmpty
                            ? null
                            : () {
                                setState(() {
                                  _drawnLines.clear();
                                  _lineColors.clear();
                                  _lineSizes.clear();
                                });
                              },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Color palette & stroke width
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: isDark ? Colors.black : Colors.white,
          child: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Colors.amber,
                    Colors.redAccent,
                    Colors.tealAccent,
                    Colors.purpleAccent,
                    Colors.pinkAccent,
                    Colors.lightBlueAccent,
                    Colors.greenAccent,
                    Colors.white,
                  ].map((color) {
                    final isSel = _selectedColor == color;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = color),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSel ? Colors.indigoAccent : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('Brush Size', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value: _strokeWidth,
                      min: 2.0,
                      max: 20.0,
                      activeColor: Colors.tealAccent,
                      onChanged: (val) => setState(() => _strokeWidth = val),
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Save Sticker', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      _finishAndSaveSticker('draw', 'My Hand-Drawn Doodle', previewText: '🎨 Doodle');
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 2. PHOTO CUTOUT TAB
  Widget _buildPhotoTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: isDark ? Colors.black : Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
              border: _hasWhiteOutline
                  ? Border.all(color: Colors.white, width: 4)
                  : Border.all(color: Colors.transparent),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: _selectedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        _selectedImage!.path,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 48, color: Colors.tealAccent),
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🎓', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 4),
                        Text(
                          _stickerCaptionCtrl.text,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Compact preview (~120px) as it will appear in chats & comments',
            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 11),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent.shade700, foregroundColor: Colors.white),
              icon: const Icon(Icons.camera_alt, size: 16),
              label: const Text('Take Snap'),
              onPressed: () => _pickPhoto(ImageSource.camera),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.photo_library, size: 16),
              label: const Text('Pick Image'),
              onPressed: () => _pickPhoto(ImageSource.gallery),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _stickerCaptionCtrl,
          onChanged: (val) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Sticker Text Overlay',
            hintText: 'e.g. ABUAD VIBES ✨ or LAW CRAMMING 📚',
            prefixIcon: const Icon(Icons.text_fields_rounded),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('Sticker White Contour Border', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          subtitle: const Text('Adds a crisp comic sticker outline with drop shadow', style: TextStyle(fontSize: 12)),
          value: _hasWhiteOutline,
          activeColor: Colors.tealAccent,
          onChanged: (val) => setState(() => _hasWhiteOutline = val),
        ),
        const SizedBox(height: 16),
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
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              _finishAndSaveSticker(
                'photo',
                _stickerCaptionCtrl.text.isNotEmpty ? _stickerCaptionCtrl.text : 'Photo Sticker',
                previewText: _stickerCaptionCtrl.text,
              );
            },
            child: const Text('Save Photo Sticker', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  // 3. GIF / VIDEO ANIMATION TAB
  Widget _buildGifTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade900, Colors.teal.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.tealAccent, width: 2),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.gif_rounded, size: 48, color: Colors.tealAccent),
                      Text(
                        _sampleTemplates[_selectedGifTemplate]['quote']!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_gifSpeed}x Loop',
                        style: const TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('GIF', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Short 2-3s animated reaction sticker for quick replies & comments',
            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Loop Speed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Row(
          children: [0.5, 1.0, 1.5, 2.0].map((speed) {
            final isSel = _gifSpeed == speed;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ChoiceChip(
                  label: Text('${speed}x'),
                  selected: isSel,
                  selectedColor: Colors.tealAccent.shade700,
                  onSelected: (val) {
                    if (val) setState(() => _gifSpeed = speed);
                  },
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Boomerang Bounce (Forward & Reverse)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          subtitle: const Text('Loops back and forth seamlessly like Instagram / Snapchat stickers', style: TextStyle(fontSize: 12)),
          value: _isBoomerang,
          activeColor: Colors.tealAccent,
          onChanged: (val) => setState(() => _isBoomerang = val),
        ),
        const SizedBox(height: 16),
        const Text('Choose Campus GIF Template', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        ...List.generate(_sampleTemplates.length, (idx) {
          final t = _sampleTemplates[idx];
          final isSel = _selectedGifTemplate == idx;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: isSel ? Colors.tealAccent : Colors.transparent, width: 1.5),
            ),
            child: ListTile(
              leading: Text(t['emoji']!, style: const TextStyle(fontSize: 24)),
              title: Text(t['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text(t['quote']!, style: const TextStyle(fontSize: 11)),
              trailing: isSel ? const Icon(Icons.check_circle, color: Colors.tealAccent) : null,
              onTap: () => setState(() => _selectedGifTemplate = idx),
            ),
          );
        }),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.tealAccent.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final sel = _sampleTemplates[_selectedGifTemplate];
              _finishAndSaveSticker(
                'gif',
                '${sel['title']} Animated Sticker',
                previewText: '${sel['emoji']} ${sel['quote']}',
              );
            },
            child: const Text('Export & Save Animated Sticker', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}

class _DoodlePainter extends CustomPainter {
  final List<List<Offset>> lines;
  final List<Color> colors;
  final List<double> sizes;

  _DoodlePainter({
    required this.lines,
    required this.colors,
    required this.sizes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) continue;

      final paint = Paint()
        ..color = colors[i]
        ..strokeWidth = sizes[i]
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (line.length == 1) {
        canvas.drawCircle(line.first, sizes[i] / 2, paint..style = PaintingStyle.fill);
      } else {
        final path = Path()..moveTo(line.first.dx, line.first.dy);
        for (int j = 1; j < line.length; j++) {
          path.lineTo(line[j].dx, line[j].dy);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DoodlePainter oldDelegate) => true;
}
