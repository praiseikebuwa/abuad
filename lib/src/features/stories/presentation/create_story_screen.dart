import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/story_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/story.dart';
import '../../shared/presentation/unified_image_editor.dart';
import '../../../core/utils/url_validator.dart';

/// Screen for creating a new story
/// Allows user to take a photo or select from gallery
class CreateStoryScreen extends ConsumerStatefulWidget {
  final String? initialImagePath;
  final Story? resharedStory;
  const CreateStoryScreen({
    super.key,
    this.initialImagePath,
    this.resharedStory,
  });

  @override
  ConsumerState<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends ConsumerState<CreateStoryScreen> {
  XFile? _selectedMedia;
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _textController = TextEditingController();
  final bool _isUploading = false;
  bool _isTextMode = false;
  Color _backgroundColor = const Color(0xFFEF5350); // Default Coral Red
  Color _textColor = Colors.white;
  String _fontFamily = 'Roboto';
  TextAlign _textAlign = TextAlign.center;
  String? _linkUrl;
  String _visibility = 'everyone';

  // Enhanced Text Status Capabilities
  double _fontSize = 32.0;
  bool _hasTextBackground = false;
  bool _hasShadow = true;
  bool _isGradientMode = false;
  int _selectedGradientIndex = 0;

  final List<List<Color>> _gradientPresets = const [
    [Color(0xFFEF5350), Color(0xFFE91E63)], // Coral to Rose
    [Color(0xFF00E5FF), Color(0xFF1F5F5B)], // ABUAD Teal / Emerald
    [Color(0xFF8B5CF6), Color(0xFFEC4899)], // Purple to Neon Berry
    [Color(0xFFFF512F), Color(0xFFDD2476)], // Sunset Blaze
    [Color(0xFF00F260), Color(0xFF0575E6)], // Northern Lights
    [Color(0xFF4776E6), Color(0xFF8E54E9)], // Electric Indigo
    [Color(0xFFFF8008), Color(0xFFFFC837)], // Warm Mango
    [Color(0xFF0F2027), Color(0xFF2C5364)], // Midnight Cyan
    [Color(0xFF2E3192), Color(0xFF1BFFFF)], // Oceanic Blue
    [Color(0xFF8A2387), Color(0xFFF27121)], // Cyberpunk
    [Color(0xFF134E5E), Color(0xFF71B280)], // Lush Botanical
    [Color(0xFF212121), Color(0xFF424242)], // Obsidian Slate
  ];

  final List<String> _quickStatusPrompts = const [
    'Studying for exams 📚',
    'Cafeteria run 🍔',
    'Hostel vibes 🛏️',
    'In lecture 📝',
    'College vibes 🎓',
    'Gym grind 💪',
    'Weekend energy 🎉',
    'Late night chill 🌙',
    'Project deadline ⏳',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialImagePath != null) {
      _selectedMedia = XFile(widget.initialImagePath!);
    }
  }

  final List<Color> _backgroundColors = const [
    Color(0xFFEF5350), // Coral Red
    Color(0xFFE53935), // Crimson
    Color(0xFFEC4899), // Neon Pink
    Color(0xFFD81B60), // Vivid Magenta
    Color(0xFF8B5CF6), // Royal Purple
    Color(0xFF673AB7), // Deep Violet
    Color(0xFF3F51B5), // Indigo
    Color(0xFF42A5F5), // Sky Blue
    Color(0xFF1E88E5), // Electric Blue
    Color(0xFF00E5FF), // Cyan Glow
    Color(0xFF009688), // Mint Teal
    Color(0xFF26A69A), // Emerald
    Color(0xFF4CAF50), // Leaf Green
    Color(0xFF76FF03), // Lime Neon
    Color(0xFFFFB300), // Amber Gold
    Color(0xFFFF9800), // Sunset Orange
    Color(0xFFE65100), // Deep Orange
    Color(0xFFBF360C), // Terracotta
    Color(0xFF607D8B), // Slate Grey
    Color(0xFF263238), // Charcoal
    Color(0xFF000000), // Pure Black
    Color(0xFF4E342E), // Espresso
    Color(0xFF9C27B0), // Berry Purple
    Color(0xFFFF6F61), // Living Coral
  ];

  final List<Color> _textColors = const [
    Colors.white,
    Colors.black,
    Color(0xFFFFF176), // Neon Lemon
    Color(0xFFFFD54F), // Gold Amber
    Color(0xFF00E5FF), // Electric Cyan
    Color(0xFF69F0AE), // Mint Neon
    Color(0xFFFF6E40), // Bright Coral
    Color(0xFFFF4081), // Rose Pink
    Color(0xFFE1BEE7), // Soft Lavender
    Color(0xFF40C4FF), // Sky Blue
    Color(0xFFFF9100), // Vibrant Orange
    Color(0xFFAB47BC), // Purple Neon
    Color(0xFFEF5350), // Red
    Color(0xFF66BB6A), // Green
  ];

  final List<String> _fonts = const [
    'Roboto',
    'Serif',
    'Monospace',
    'cursive',
    'sans-serif-black',
    'sans-serif-condensed',
  ];

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
        return Material(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                  onTap: () async {
                    Navigator.pop(context);
                    final result = await context.push(
                      '/camera',
                      extra: {'isForStory': true},
                    );
                    if (result != null && result is Map) {
                      final file = result['file'] as XFile?;
                      if (file != null) {
                        setState(() {
                          _selectedMedia = file;
                        });
                      }
                    }
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
        return Material(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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

  void _uploadStory() async {
    if (_selectedMedia == null &&
        !_isTextMode &&
        widget.resharedStory == null) {
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

    final authUser =
        ref.read(authRepositoryProvider).currentUser ??
        ref.read(currentUserProvider).value;
    final currentUid =
        authUser?.uid ?? ref.read(authRepositoryProvider).currentUserId;

    if (currentUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User session invalid. Please sign in again.'),
        ),
      );
      return;
    }

    final repo = ref.read(storyRepositoryProvider);

    // Capture all UI state before popping
    final selectedMedia = _selectedMedia;
    final isTextMode = _isTextMode;
    final resharedStory = widget.resharedStory;
    final captionText = _captionController.text.trim();
    final textContent = _textController.text.trim();
    final bgColor = (_isTextMode && _isGradientMode)
        ? _gradientPresets[_selectedGradientIndex].first.toARGB32()
        : _backgroundColor.toARGB32();
    final txtColor = _textColor.toARGB32();
    final fontFamily = _fontFamily;
    final textAlignName = _textAlign.name;
    final linkUrl = _linkUrl;
    final visibility = _visibility;

    final messenger = ScaffoldMessenger.of(context);

    // Pop immediately
    if (mounted) {
      Navigator.pop(context);
    }

    messenger.showSnackBar(
      const SnackBar(
        content: Text('📤 Sharing story...'),
        duration: Duration(seconds: 2),
      ),
    );

    // Background process
    try {
      String content = '';
      String type = 'image';
      String? caption = captionText.isEmpty ? null : captionText;
      int? backgroundColor;
      int? textColor;
      bool isRawContent = false;

      if (resharedStory != null) {
        content = resharedStory.content;
        type = resharedStory.type;
        isRawContent = true;
      } else if (isTextMode) {
        content = textContent;
        type = 'text';
        caption = textContent;
        backgroundColor = bgColor;
        textColor = txtColor;
      }

      // Extract mentions
      final List<String> mentions = [];
      final String mentionSource = isTextMode ? content : (caption ?? '');
      final RegExp mentionRegex = RegExp(r'@(\w+)');
      for (final match in mentionRegex.allMatches(mentionSource)) {
        if (match.group(1) != null) {
          mentions.add(match.group(1)!);
        }
      }

      await repo.createStory(
        mediaFile: isTextMode || resharedStory != null ? null : selectedMedia,
        type: type,
        caption: caption,
        content: content,
        isRawContent: isRawContent,
        mentions: mentions,
        linkUrl: resharedStory != null
            ? 'https://abuadapp.com.ng/post/${resharedStory.id}'
            : linkUrl,
        visibility: visibility,
        backgroundColor: backgroundColor,
        textColor: textColor,
        fontFamily: isTextMode ? fontFamily : null,
        textAlign: isTextMode ? textAlignName : null,
        reshareAuthorId: resharedStory?.authorId,
        reshareAuthorName: resharedStory?.userName,
        reshareStoryId: resharedStory?.id,
      );

      messenger.showSnackBar(
        const SnackBar(
          content: Text('✅ Story shared!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('❌ Failed to share story: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
                            _textController.text.trim().isNotEmpty) ||
                        widget.resharedStory != null) &&
                    !_isUploading
                ? _uploadStory
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient:
                    ((_selectedMedia != null) ||
                            (_isTextMode &&
                                _textController.text.trim().isNotEmpty) ||
                            widget.resharedStory != null) &&
                        !_isUploading
                    ? const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                      )
                    : null,
                color:
                    ((_selectedMedia != null) ||
                            (_isTextMode &&
                                _textController.text.trim().isNotEmpty) ||
                            widget.resharedStory != null) &&
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
                                  _textController.text.trim().isNotEmpty) ||
                              widget.resharedStory != null) &&
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
      body: widget.resharedStory != null
          ? _buildResharePreview(isDark)
          : (_isTextMode
                ? _buildTextPreview(isDark)
                : (_selectedMedia == null
                      ? _buildEmptyState(isDark)
                      : _buildPreview(isDark))),
      floatingActionButton: null,
    );
  }

  Widget _buildResharePreview(bool isDark) {
    if (widget.resharedStory == null) return const SizedBox();

    final story = widget.resharedStory!;

    return Stack(
      children: [
        // Background blurred or gradient
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.purple.shade900, Colors.black],
            ),
          ),
        ),

        // Centered story content snapshot
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: AspectRatio(
                    aspectRatio: 9 / 16,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (story.type == 'text')
                          Container(
                            color: Color(story.backgroundColor ?? 0xFF000000),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              story.content,
                              textAlign: story.textAlign == 'left'
                                  ? TextAlign.left
                                  : (story.textAlign == 'right'
                                        ? TextAlign.right
                                        : TextAlign.center),
                              style: TextStyle(
                                color: Color(story.textColor ?? 0xFFFFFFFF),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: story.fontFamily ?? 'Roboto',
                              ),
                            ),
                          )
                        else
                          (story.content.isNotEmpty &&
                                  UrlValidator.isValidUrl(story.content))
                              ? CachedNetworkImage(
                                  imageUrl: story.content,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) =>
                                      Container(
                                        color: Colors.black,
                                        child: const Center(
                                          child: Icon(
                                            Icons.broken_image,
                                            color: Colors.white54,
                                            size: 48,
                                          ),
                                        ),
                                      ),
                                )
                              : Container(
                                  color: Colors.black,
                                  child: const Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      color: Colors.white54,
                                      size: 48,
                                    ),
                                  ),
                                ),

                        // Dark overlay and username at bottom
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black87],
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundImage:
                                      (story.userAvatar.isNotEmpty &&
                                          UrlValidator.isValidUrl(
                                            story.userAvatar,
                                          ))
                                      ? CachedNetworkImageProvider(
                                          story.userAvatar,
                                        )
                                      : null,
                                  backgroundColor: const Color(0xFF8B5CF6),
                                  child:
                                      (story.userAvatar.isEmpty ||
                                          !UrlValidator.isValidUrl(
                                            story.userAvatar,
                                          ))
                                      ? Text(
                                          story.userName.isNotEmpty
                                              ? story.userName[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    story.userName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
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
              const SizedBox(height: 24),
              const Text(
                'Resharing to your story',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
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
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      kIsWeb
                          ? Image.network(
                              _selectedMedia!.path,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: Colors.black,
                                    child: const Center(
                                      child: Icon(
                                        Icons.broken_image,
                                        color: Colors.white54,
                                        size: 48,
                                      ),
                                    ),
                                  ),
                            )
                          : Image.file(
                              File(_selectedMedia!.path),
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: Colors.black,
                                    child: const Center(
                                      child: Icon(
                                        Icons.broken_image,
                                        color: Colors.white54,
                                        size: 48,
                                      ),
                                    ),
                                  ),
                            ),
                      Positioned(
                        top: 16,
                        right: 16,
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          child: IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white),
                            onPressed: () async {
                              final edited = await UnifiedImageEditor.open(
                                context,
                                file: File(_selectedMedia!.path),
                              );
                              if (edited != null && mounted) {
                                setState(() {
                                  _selectedMedia = edited;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  )
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
              GlassmorphicContainer(
                width: double.infinity,
                height: 50,
                borderRadius: 25,
                blur: 20,
                alignment: Alignment.center,
                border: 1,
                linearGradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.05),
                    isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.02),
                  ],
                  stops: const [0.1, 1],
                ),
                borderGradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    isDark
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.1),
                    isDark
                        ? Colors.white.withValues(alpha: 0.0)
                        : Colors.black.withValues(alpha: 0.0),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _captionController,
                    maxLength: 200,
                    maxLines: 1,
                    decoration: InputDecoration(
                      hintText: 'Add a caption...',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                      ),
                      border: InputBorder.none,
                      counterText: '',
                      contentPadding: const EdgeInsets.only(bottom: 2),
                    ),
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
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
                          ? () async {
                              final edited = await UnifiedImageEditor.open(
                                context,
                                file: File(_selectedMedia!.path),
                              );
                              if (edited != null && mounted) {
                                setState(() {
                                  _selectedMedia = edited;
                                });
                              }
                            }
                          : null,
                      icon: const Icon(Icons.brush, size: 20),
                      label: const Text('Edit Photo'),
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
                  const SizedBox(width: 8),
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
    final effectiveBgColor = _backgroundColor;
    final effectiveGradient = _isGradientMode
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _gradientPresets[_selectedGradientIndex],
          )
        : null;

    return Stack(
      children: [
        // 1. Background Canvas
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
            },
            child: Container(
              color: !_isGradientMode ? effectiveBgColor : null,
              decoration: _isGradientMode
                  ? BoxDecoration(gradient: effectiveGradient)
                  : null,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 80.0),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      inputDecorationTheme: const InputDecorationTheme(
                        filled: false,
                        fillColor: Colors.transparent,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                      ),
                    ),
                    child: TextField(
                      controller: _textController,
                      textAlign: _textAlign,
                      onChanged: (val) {
                        setState(() {});
                      },
                      style: TextStyle(
                        color: _textColor,
                        fontSize: _fontSize,
                        fontWeight: FontWeight.bold,
                        fontFamily: _fontFamily,
                        shadows: _hasShadow
                            ? [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      maxLines: null,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Type a status...',
                        hintStyle: TextStyle(
                          color: _textColor.withValues(alpha: 0.55),
                          fontSize: _fontSize,
                          fontFamily: _fontFamily,
                          fontWeight: FontWeight.w600,
                        ),
                        filled: _hasTextBackground,
                        fillColor: _hasTextBackground
                            ? Colors.black.withValues(alpha: 0.55)
                            : Colors.transparent,
                        border: _hasTextBackground
                            ? OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              )
                            : InputBorder.none,
                        enabledBorder: _hasTextBackground
                            ? OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              )
                            : InputBorder.none,
                        focusedBorder: _hasTextBackground
                            ? OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              )
                            : InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: _hasTextBackground
                            ? const EdgeInsets.symmetric(horizontal: 20, vertical: 14)
                            : EdgeInsets.zero,
                      ),
                      autofocus: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // 2. Top Header Controls (Visibility, Card Preview, Gradient Mode, Link)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(
              16,
              12 + MediaQuery.of(context).padding.top,
              16,
              12,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Visibility Selector
                GestureDetector(
                  onTap: _showVisibilitySelector,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _visibility != 'everyone'
                            ? const Color(0xFF00E5FF)
                            : Colors.white24,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _visibility == 'everyone'
                              ? Icons.public
                              : (_visibility == 'followers' ? Icons.people : Icons.star),
                          color: Colors.white,
                          size: 15,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _visibility == 'everyone'
                              ? 'Public'
                              : (_visibility == 'followers' ? 'Followers' : 'Close Friends'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Right Utility Buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Card Preview Button
                    GestureDetector(
                      onTap: _showCardPreviewBottomSheet,
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.remove_red_eye_outlined, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text('Preview', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),

                    // Solid vs Gradient Toggle
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isGradientMode = !_isGradientMode;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: _isGradientMode ? const Color(0xFF00E5FF) : Colors.black.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Icon(
                          _isGradientMode ? Icons.gradient : Icons.circle,
                          color: _isGradientMode ? Colors.black : Colors.white,
                          size: 18,
                        ),
                      ),
                    ),

                    // Link Dialog Button
                    GestureDetector(
                      onTap: _showLinkDialog,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: _linkUrl != null
                              ? const Color(0xFF00E5FF)
                              : Colors.black.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.link,
                          color: _linkUrl != null ? Colors.black : Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // 3. Bottom Controls Panel
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(
              0,
              10,
              0,
              10 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.85),
                  Colors.black.withValues(alpha: 0.4),
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Quick Inspiration Chips Row
                SizedBox(
                  height: 28,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: _quickStatusPrompts.length,
                    itemBuilder: (context, index) {
                      final prompt = _quickStatusPrompts[index];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _textController.text = prompt;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white24),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            prompt,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),

                // Font & Style Controls Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      // Font Selector
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
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 11),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    font == 'sans-serif-black'
                                        ? 'Impact'
                                        : (font == 'sans-serif-condensed'
                                            ? 'Tall'
                                            : font),
                                    style: TextStyle(
                                      color: isSelected ? Colors.black : Colors.white,
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontFamily: font,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Text Size Toggle (Tt)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (_fontSize == 32.0) {
                              _fontSize = 42.0;
                            } else if (_fontSize == 42.0) {
                              _fontSize = 24.0;
                            } else {
                              _fontSize = 32.0;
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _fontSize == 42.0 ? 'XL' : (_fontSize == 24.0 ? 'SM' : 'MD'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),

                      // Highlight Badge Toggle (A*)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _hasTextBackground = !_hasTextBackground;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: _hasTextBackground
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'A*',
                            style: TextStyle(
                              color: _hasTextBackground ? Colors.black : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),

                      // Text Alignments
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildAlignmentButton(TextAlign.left, Icons.format_align_left),
                          const SizedBox(width: 3),
                          _buildAlignmentButton(TextAlign.center, Icons.format_align_center),
                          const SizedBox(width: 3),
                          _buildAlignmentButton(TextAlign.right, Icons.format_align_right),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Background Color / Gradient Palette Row
                SizedBox(
                  height: 32,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 14, right: 6),
                        child: Icon(
                          _isGradientMode ? Icons.gradient : Icons.palette,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      Expanded(
                        child: _isGradientMode
                            ? ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _gradientPresets.length,
                                itemBuilder: (context, index) {
                                  final grad = _gradientPresets[index];
                                  final isSelected = _selectedGradientIndex == index;
                                  return GestureDetector(
                                    onTap: () => setState(() => _selectedGradientIndex = index),
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: grad,
                                        ),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected ? Colors.white : Colors.white38,
                                          width: isSelected ? 2.5 : 1,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              )
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _backgroundColors.length,
                                itemBuilder: (context, index) {
                                  final color = _backgroundColors[index];
                                  final isSelected = _backgroundColor == color;
                                  return GestureDetector(
                                    onTap: () => setState(() => _backgroundColor = color),
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected ? Colors.white : Colors.white30,
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
                const SizedBox(height: 10),

                // Text Color Palette Row
                SizedBox(
                  height: 28,
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 14, right: 6),
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
                                    color: isSelected ? Colors.white : Colors.white30,
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
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showCardPreviewBottomSheet() {
    final text = _textController.text.trim().isEmpty ? 'Your Status Preview' : _textController.text.trim();
    final effectiveBgColor = _isGradientMode
        ? _gradientPresets[_selectedGradientIndex].first
        : _backgroundColor;
    final currentUser = ref.read(currentUserProvider).value;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  'Feed Status Card Preview',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'How your status card appears to friends on the stories shelf',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 18),
                Center(
                  child: Container(
                    width: 160,
                    height: 220,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: !_isGradientMode ? effectiveBgColor : null,
                      gradient: _isGradientMode
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: _gradientPresets[_selectedGradientIndex],
                            )
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(10, 16, 10, 48),
                            alignment: Alignment.center,
                            child: Text(
                              text,
                              textAlign: _textAlign,
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _textColor,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                fontFamily: _fontFamily,
                                shadows: _hasShadow
                                    ? [
                                        Shadow(
                                          color: Colors.black.withValues(alpha: 0.4),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.7),
                                ],
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: const Color(0xFF00E5FF),
                                  backgroundImage: (currentUser?.avatarUrl != null &&
                                          currentUser!.avatarUrl!.isNotEmpty)
                                      ? CachedNetworkImageProvider(currentUser.avatarUrl!)
                                      : null,
                                  child: (currentUser?.avatarUrl == null ||
                                          currentUser!.avatarUrl!.isEmpty)
                                      ? Text(
                                          (currentUser?.displayName.isNotEmpty == true)
                                              ? currentUser!.displayName[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    currentUser?.displayName ?? 'You',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Back to Editor', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlignmentButton(TextAlign alignment, IconData icon) {
    final isSelected = _textAlign == alignment;
    return GestureDetector(
      onTap: () => setState(() => _textAlign = alignment),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.black : Colors.white,
          size: 18,
        ),
      ),
    );
  }
}
