import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../data/story_repository.dart';
import '../../user/data/user_repository.dart';

/// Screen for creating a new story
/// Allows user to take a photo or select from gallery
class CreateStoryScreen extends ConsumerStatefulWidget {
  final String? initialImagePath;
  const CreateStoryScreen({super.key, this.initialImagePath});

  @override
  ConsumerState<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends ConsumerState<CreateStoryScreen> {
  XFile? _selectedMedia;
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _textController = TextEditingController();
  bool _isUploading = false;
  bool _isTextMode = false;
  Color _backgroundColor = const Color(0xFFEF5350); // Default Red
  Color _textColor = Colors.white;
  String _fontFamily = 'Roboto';
  TextAlign _textAlign = TextAlign.center;
  String? _linkUrl;
  String _visibility = 'everyone';

  @override
  void initState() {
    super.initState();
    if (widget.initialImagePath != null) {
      _selectedMedia = XFile(widget.initialImagePath!);
    }
  }

  final List<Color> _backgroundColors = [
    const Color(0xFFEF5350), // Red
    const Color(0xFFAB47BC), // Purple
    const Color(0xFF42A5F5), // Blue
    const Color(0xFF26A69A), // Teal
    const Color(0xFF66BB6A), // Green
    const Color(0xFFFFA726), // Orange
    const Color(0xFF78909C), // Blue Grey
    const Color(0xFF212121), // Black
    const Color(0xFF5D4037), // Brown
    const Color(0xFF303F9F), // Indigo
  ];

  final List<Color> _textColors = [
    Colors.white,
    Colors.black,
    const Color(0xFFEF5350),
    const Color(0xFF42A5F5),
    const Color(0xFF66BB6A),
    const Color(0xFFFFA726),
    const Color(0xFFAB47BC),
  ];

  final List<String> _fonts = ['Roboto', 'Serif', 'Monospace'];

  @override
  void dispose() {
    _captionController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedMedia = image;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  Future<void> _showImageSourceSelector() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  title: const Text(
                    'Take Photo',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.photo_library,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  title: const Text(
                    'Choose from Gallery',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showLinkDialog() async {
    final controller = TextEditingController(text: _linkUrl);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Link'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'https://example.com',
            labelText: 'URL',
          ),
          autofocus: true,
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _linkUrl = result.trim().isEmpty ? null : result.trim();
      });
    }
  }

  void _showVisibilitySelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Who can see this?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildVisibilityTile(
                  'everyone',
                  'Everyone',
                  Icons.public,
                  isDark,
                ),
                _buildVisibilityTile(
                  'followers',
                  'Followers',
                  Icons.people,
                  isDark,
                ),
                _buildVisibilityTile(
                  'close_friends',
                  'Close Friends',
                  Icons.star,
                  isDark,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVisibilityTile(
    String value,
    String title,
    IconData icon,
    bool isDark,
  ) {
    final isSelected = _visibility == value;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected
            ? const Color(0xFF8B5CF6)
            : (isDark ? Colors.white70 : Colors.black54),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected
              ? const Color(0xFF8B5CF6)
              : (isDark ? Colors.white70 : Colors.black54),
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: Color(0xFF8B5CF6))
          : null,
      onTap: () {
        setState(() {
          _visibility = value;
        });
        Navigator.pop(context);
      },
    );
  }

  Future<void> _uploadStory() async {
    if (_selectedMedia == null && !_isTextMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image first')),
      );
      return;
    }

    if (_isTextMode && _textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter some text')));
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final repo = ref.read(storyRepositoryProvider);
      final currentUser = ref.read(currentUserProvider).value;

      if (currentUser == null) {
        throw Exception('User profile not found');
      }

      // ... (inside _uploadStory)
      String content = '';
      String type = 'image';
      String? caption = _captionController.text.trim().isEmpty
          ? null
          : _captionController.text.trim();
      int? backgroundColor;
      int? textColor;

      if (_isTextMode) {
        content = _textController.text.trim();
        type = 'text';
        caption = null;
        backgroundColor = _backgroundColor.toARGB32();
        textColor = _textColor.toARGB32();
      }

      // Extract mentions from caption or text
      final List<String> mentions = [];
      final String mentionSource = _isTextMode ? content : (caption ?? '');
      final RegExp mentionRegex = RegExp(r'@(\w+)');
      for (final match in mentionRegex.allMatches(mentionSource)) {
        if (match.group(1) != null) {
          mentions.add(match.group(1)!);
        }
      }

      await repo.createStory(
        mediaFile: _isTextMode ? null : _selectedMedia!,
        type: type,
        caption: caption,
        content: content,
        mentions: mentions,
        linkUrl: _linkUrl,
        visibility: _visibility,
        backgroundColor: backgroundColor,
        textColor: textColor,
        fontFamily: _isTextMode ? _fontFamily : null,
        textAlign: _isTextMode ? _textAlign.name : null,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Story posted!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error uploading story: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create Story',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed:
                ((_selectedMedia != null) ||
                        (_isTextMode &&
                            _textController.text.trim().isNotEmpty)) &&
                    !_isUploading
                ? _uploadStory
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient:
                    ((_selectedMedia != null) ||
                            (_isTextMode &&
                                _textController.text.trim().isNotEmpty)) &&
                        !_isUploading
                    ? const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                      )
                    : null,
                color:
                    ((_selectedMedia != null) ||
                            (_isTextMode &&
                                _textController.text.trim().isNotEmpty)) &&
                        !_isUploading
                    ? null
                    : (isDark ? Colors.grey[800] : Colors.grey[200]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Post',
                style: TextStyle(
                  color:
                      ((_selectedMedia != null) ||
                              (_isTextMode &&
                                  _textController.text.trim().isNotEmpty)) &&
                          !_isUploading
                      ? Colors.white
                      : (isDark ? Colors.grey[600] : Colors.grey[400]),
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isTextMode
          ? _buildTextPreview(isDark)
          : (_selectedMedia == null
                ? _buildEmptyState(isDark)
                : _buildPreview(isDark)),
      floatingActionButton: null,
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(Icons.add_a_photo, size: 64, color: Colors.white),
          ),
          const SizedBox(height: 32),
          const Text(
            'Share a Story',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            'Photo or video that disappears after 24 hours',
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _showImageSourceSelector,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              foregroundColor: isDark ? Colors.white : Colors.black,
              elevation: isDark ? 0 : 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Add Photo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              setState(() {
                _isTextMode = true;
                _selectedMedia = null;
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.white70 : Colors.black54,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.text_fields, size: 20),
                SizedBox(width: 8),
                Text(
                  'Text Status',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(bool isDark) {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            color: Colors.black,
            child: _selectedMedia != null
                ? Image.file(File(_selectedMedia!.path), fit: BoxFit.contain)
                : const SizedBox(),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              TextField(
                controller: _captionController,
                maxLength: 200,
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: 'Add a caption...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  counterText: '',
                ),
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showVisibilitySelector,
                      icon: Icon(
                        _visibility == 'everyone'
                            ? Icons.public
                            : (_visibility == 'followers'
                                  ? Icons.people
                                  : Icons.star),
                        size: 20,
                        color: _visibility != 'everyone'
                            ? const Color(0xFF8B5CF6)
                            : null,
                      ),
                      label: Text(
                        _visibility == 'everyone'
                            ? 'Public'
                            : (_visibility == 'followers'
                                  ? 'Followers'
                                  : 'Close Friends'),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: _visibility != 'everyone'
                              ? const Color(0xFF8B5CF6)
                              : (isDark
                                    ? Colors.grey[700]!
                                    : Colors.grey[300]!),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showLinkDialog,
                      icon: Icon(
                        Icons.link,
                        size: 20,
                        color: _linkUrl != null
                            ? const Color(0xFF8B5CF6)
                            : null,
                      ),
                      label: Text(_linkUrl == null ? 'Add Link' : 'Link Added'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: _linkUrl != null
                              ? const Color(0xFF8B5CF6)
                              : (isDark
                                    ? Colors.grey[700]!
                                    : Colors.grey[300]!),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _selectedMedia != null && !_isUploading
                          ? () {
                              setState(() {
                                _selectedMedia = null;
                                _captionController.clear();
                                _linkUrl = null;
                              });
                            }
                          : null,
                      icon: const Icon(Icons.refresh, size: 20),
                      label: const Text('Change Photo'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_isUploading) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text(
                  'Uploading story...',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextPreview(bool isDark) {
    return Stack(
      children: [
        // Top Controls (Link and Visibility)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(
              16,
              16 + MediaQuery.of(context).padding.top,
              16,
              12,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Visibility
                GestureDetector(
                  onTap: _showVisibilitySelector,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _visibility != 'everyone'
                            ? const Color(0xFF8B5CF6)
                            : Colors.white24,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _visibility == 'everyone'
                              ? Icons.public
                              : (_visibility == 'followers'
                                    ? Icons.people
                                    : Icons.star),
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _visibility == 'everyone'
                              ? 'Public'
                              : (_visibility == 'followers'
                                    ? 'Followers'
                                    : 'Close Friends'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Link
                GestureDetector(
                  onTap: _showLinkDialog,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _linkUrl != null
                          ? const Color(0xFF8B5CF6)
                          : Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.link,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Background
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              // Focus text field when tapping background
              FocusScope.of(context).unfocus();
            },
            child: Container(
              color: _backgroundColor,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: TextField(
                    controller: _textController,
                    textAlign: _textAlign,
                    onChanged: (val) {
                      setState(() {}); // Rebuild to update Post button
                    },
                    style: TextStyle(
                      color: _textColor,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      fontFamily: _fontFamily,
                    ),
                    maxLines: null,
                    decoration: const InputDecoration(
                      hintText: 'Type a status...',
                      hintStyle: TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                    ),
                    autofocus: true,
                  ),
                ),
              ),
            ),
          ),
        ),

        // Controls
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(
              0,
              12,
              0,
              12 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.7),
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Font and Alignment Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // Font Selector (Smaller)
                      Expanded(
                        child: SizedBox(
                          height: 32,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _fonts.length,
                            itemBuilder: (context, index) {
                              final font = _fonts[index];
                              final isSelected = _fontFamily == font;
                              return GestureDetector(
                                onTap: () => setState(() => _fontFamily = font),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    font,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.black
                                          : Colors.white,
                                      fontSize: 13,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontFamily: font,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Alignment Selector (Icons only)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildAlignmentButton(
                            TextAlign.left,
                            Icons.format_align_left,
                          ),
                          const SizedBox(width: 4),
                          _buildAlignmentButton(
                            TextAlign.center,
                            Icons.format_align_center,
                          ),
                          const SizedBox(width: 4),
                          _buildAlignmentButton(
                            TextAlign.right,
                            Icons.format_align_right,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Text and Background Color Row
                SizedBox(
                  height: 32,
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 16, right: 8),
                        child: Icon(
                          Icons.palette,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _backgroundColors.length,
                          itemBuilder: (context, index) {
                            final color = _backgroundColors[index];
                            final isSelected = _backgroundColor == color;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _backgroundColor = color),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white30,
                                    width: isSelected ? 2.5 : 1,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Secondary Colors (Text) Row
                SizedBox(
                  height: 28,
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 16, right: 8),
                        child: Icon(
                          Icons.text_format,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _textColors.length,
                          itemBuilder: (context, index) {
                            final color = _textColors[index];
                            final isSelected = _textColor == color;
                            return GestureDetector(
                              onTap: () => setState(() => _textColor = color),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white30,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlignmentButton(TextAlign alignment, IconData icon) {
    final isSelected = _textAlign == alignment;
    return GestureDetector(
      onTap: () => setState(() => _textAlign = alignment),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white
              : Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.black : Colors.white,
          size: 20,
        ),
      ),
    );
  }
}
