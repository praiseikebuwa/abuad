import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../camera/presentation/camera_screen.dart';
import '../../../core/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/post_repository.dart';
import 'providers/feed_provider.dart';
import '../../shared/presentation/unified_image_editor.dart';
import '../../../core/services/cloud_storage_service.dart';
import '../domain/post.dart';
import '../../auth/data/auth_repository.dart';
import '../../../core/providers/shared_preferences_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/url_validator.dart';
import '../../../shared/widgets/user_avatar.dart';
import 'widgets/link_preview_card.dart';
import 'widgets/document_preview_card.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  final String? initialChannelId;
  final XFile? initialMedia;
  final CameraMode? initialMode;

  const CreatePostScreen({
    super.key,
    this.initialChannelId,
    this.initialMedia,
    this.initialMode,
  });

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _contentController = TextEditingController();
  final _picker = ImagePicker();

  final List<XFile> _selectedImages = [];
  XFile? _selectedVideo;
  PlatformFile? _selectedDocument;

  bool _isPosting = false;
  bool _isAnonymous = false;
  String _channelId = 'general';
  String _visibility = 'everyone'; // 'everyone', 'followers'

  // Tagging State
  String? _mentionQuery;
  String? _hashtagQuery;
  List<AppUser> _userSuggestions = [];
  final List<String> _tagSuggestions = [
    'engineering',
    'medical',
    'abuad',
    'campuslife',
    'tech',
    'general',
    'hostel',
    'confessions',
    'freshers',
  ];
  final LayerLink _layerLink = LayerLink();

  // Poll State
  bool _showPollCreator = false;
  final List<TextEditingController> _pollOptions = [
    TextEditingController(),
    TextEditingController(),
  ];
  String _pollDuration = '1 Day';
  double? _latitude;
  double? _longitude;
  String? _address;
  bool _isLoadingLocation = false;

  // Social Features State
  String _replyPermission = 'everyone'; // 'everyone', 'following', 'mentioned'
  DateTime? _scheduledAt;
  String? _mediaAltText;

  // Drafts
  List<Map<String, dynamic>> _savedDrafts = [];

  final String _giphyApiKey = 'DnmoJ3pdO49O9K45y8zYwe7sZdDNuXOx';

  @override
  void initState() {
    super.initState();
    if (widget.initialChannelId != null) {
      _channelId = widget.initialChannelId!;
    }
    _contentController.addListener(_updateState);
    _loadDrafts();

    if (widget.initialMedia != null) {
      if (widget.initialMode == CameraMode.video) {
        _selectedVideo = widget.initialMedia;
      } else {
        _selectedImages.add(widget.initialMedia!);
      }
    }
  }

  @override
  void dispose() {
    _contentController.removeListener(_updateState);
    _contentController.dispose();
    for (var c in _pollOptions) {
      c.dispose();
    }
    super.dispose();
  }

  void _updateState() {
    _checkTagging();
    setState(() {});
  }

  void _checkTagging() {
    final text = _contentController.text;
    final selection = _contentController.selection;
    if (!selection.isValid || selection.baseOffset == 0) {
      setState(() {
        _mentionQuery = null;
        _hashtagQuery = null;
      });
      return;
    }

    final textBeforeCursor = text.substring(0, selection.baseOffset);
    final lastWordMatch = RegExp(r"(\S+)$").firstMatch(textBeforeCursor);

    if (lastWordMatch != null) {
      final word = lastWordMatch.group(1)!;
      if (word.startsWith('@') && word.length > 1) {
        _mentionQuery = word.substring(1);
        _hashtagQuery = null;
        _fetchUserSuggestions(_mentionQuery!);
      } else if (word.startsWith('#') && word.length > 1) {
        _hashtagQuery = word.substring(1).toLowerCase();
        _mentionQuery = null;
      } else {
        _mentionQuery = null;
        _hashtagQuery = null;
      }
    } else {
      _mentionQuery = null;
      _hashtagQuery = null;
    }
  }

  Future<void> _fetchUserSuggestions(String query) async {
    try {
      final results = await ref.read(userRepositoryProvider).searchUsers(query);
      setState(() {
        _userSuggestions = results.take(5).toList();
      });
    } catch (e) {
      debugPrint("Error fetching suggestions: $e");
    }
  }

  void _applyMention(AppUser user) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final textBeforeCursor = text.substring(0, selection.baseOffset);
    final textAfterCursor = text.substring(selection.baseOffset);

    final lastWordMatch = RegExp(r"(\S+)$").firstMatch(textBeforeCursor);
    if (lastWordMatch != null) {
      final newTextBefore =
          "${textBeforeCursor.substring(0, lastWordMatch.start)}@${user.handle} ";
      _contentController.text = newTextBefore + textAfterCursor;
      _contentController.selection = TextSelection.collapsed(
        offset: newTextBefore.length,
      );
    }

    setState(() {
      _mentionQuery = null;
      _userSuggestions = [];
    });
  }

  void _applyHashtag(String tag) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final textBeforeCursor = text.substring(0, selection.baseOffset);
    final textAfterCursor = text.substring(selection.baseOffset);

    final lastWordMatch = RegExp(r"(\S+)$").firstMatch(textBeforeCursor);
    if (lastWordMatch != null) {
      final newTextBefore =
          "${textBeforeCursor.substring(0, lastWordMatch.start)}#$tag ";
      _contentController.text = newTextBefore + textAfterCursor;
      _contentController.selection = TextSelection.collapsed(
        offset: newTextBefore.length,
      );
    }

    setState(() {
      _hashtagQuery = null;
    });
  }

  bool get _canPost {
    final hasContent = _contentController.text.trim().isNotEmpty;
    final hasMedia =
        _selectedImages.isNotEmpty ||
        _selectedDocument != null ||
        _selectedVideo != null;
    final hasPoll =
        _showPollCreator && _pollOptions.every((c) => c.text.trim().isNotEmpty);
    return (hasContent || hasMedia || hasPoll) && !_isPosting;
  }

  String? get _detectedLinkUrl =>
      UrlValidator.extractFirstUrl(_contentController.text);

  // Unified Media Picker
  void _openUnifiedMediaPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryInk.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: AppColors.primaryInk),
                  ),
                  title: const Text('Choose from Photos', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Select multiple photos (up to 10)'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage();
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryTeal.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.videocam_rounded, color: AppColors.secondaryTeal),
                  ),
                  title: const Text('Choose Video', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Upload a video clip (up to 5 min)'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickVideo();
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.description_rounded, color: Color(0xFFEF4444)),
                  ),
                  title: const Text('Attach Document / File', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('PDF, Word (.docx), PowerPoint (.pptx), Excel'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickDocument();
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.orange),
                  ),
                  title: const Text('Take Photo / Video', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Use camera now'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final result = await context.push('/camera');
                    if (result != null && result is Map) {
                      final file = result['file'] as XFile?;
                      final mode = result['mode'] as CameraMode?;
                      if (file != null) {
                        setState(() {
                          if (mode == CameraMode.video) {
                            _selectedVideo = file;
                            _selectedImages.clear();
                          } else {
                            if (_selectedImages.length < 10) {
                              _selectedImages.add(file);
                            }
                            _selectedVideo = null;
                          }
                          _selectedDocument = null;
                          _showPollCreator = false;
                        });
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage() async {
    try {
      final pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles.isNotEmpty) {
        setState(() {
          for (final f in pickedFiles) {
            if (_selectedImages.length < 10) {
              _selectedImages.add(f);
            }
          }
          _selectedVideo = null;
          _selectedDocument = null;
          _showPollCreator = false;
        });
        return;
      }
    } catch (_) {}

    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        if (_selectedImages.length < 10) {
          _selectedImages.add(pickedFile);
        }
        _selectedVideo = null;
        _selectedDocument = null;
        _showPollCreator = false;
      });
    }
  }

  Future<void> _pickVideo() async {
    final pickedFile = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );
    if (pickedFile != null) {
      setState(() {
        _selectedVideo = pickedFile;
        _selectedImages.clear();
        _selectedDocument = null;
        _showPollCreator = false;
      });
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'txt'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedDocument = result.files.first;
          _selectedImages.clear();
          _selectedVideo = null;
          _showPollCreator = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting document: $e')),
        );
      }
    }
  }

  void _togglePoll() {
    setState(() {
      _showPollCreator = !_showPollCreator;
      if (_showPollCreator) {
        _selectedImages.clear();
        _selectedVideo = null;
        _selectedDocument = null;
        _latitude = null;
        _longitude = null;
        _address = null;
      }
    });
  }

  Future<void> _schedulePost() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 14)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(
          _scheduledAt ?? now.add(const Duration(hours: 1)),
        ),
      );

      if (time != null) {
        setState(() {
          _scheduledAt = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  void _editAltText() {
    final controller = TextEditingController(text: _mediaAltText);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Alt Text'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Describe this image for accessibility...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() => _mediaAltText = controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  static const String _draftsListKey = 'create_post_drafts_list';

  Future<void> _loadDrafts() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final raw = prefs.getString(_draftsListKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(raw);
        setState(() {
          _savedDrafts = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        });
      } catch (_) {}
    }
  }

  Future<void> _saveCurrentAsDraft() async {
    final text = _contentController.text.trim();
    if (text.isEmpty && _selectedImages.isEmpty && _selectedVideo == null) return;
    
    final newDraft = {
      'id': const Uuid().v4(),
      'text': text,
      'createdAt': DateTime.now().toIso8601String(),
      'channelId': _channelId,
    };

    final updated = List<Map<String, dynamic>>.from(_savedDrafts);
    updated.insert(0, newDraft);
    if (updated.length > 20) updated.removeLast();

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_draftsListKey, jsonEncode(updated));
    setState(() {
      _savedDrafts = updated;
    });
  }

  void _showDraftsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            constraints: const BoxConstraints(maxHeight: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Drafts (${_savedDrafts.length})',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (_savedDrafts.isNotEmpty)
                        TextButton(
                          onPressed: () async {
                            final prefs = ref.read(sharedPreferencesProvider);
                            await prefs.remove(_draftsListKey);
                            setState(() => _savedDrafts = []);
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: const Text('Clear all', style: TextStyle(color: Colors.red)),
                        ),
                    ],
                  ),
                ),
                const Divider(),
                if (_savedDrafts.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'No drafts saved yet',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: _savedDrafts.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final d = _savedDrafts[index];
                        final preview = (d['text'] as String?)?.isNotEmpty == true
                            ? d['text'] as String
                            : '[Media draft]';
                        return ListTile(
                          title: Text(
                            preview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            d['createdAt'] != null
                                ? DateTime.tryParse(d['createdAt'])?.toLocal().toString().split('.')[0] ?? ''
                                : '',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                            onPressed: () async {
                              final updated = List<Map<String, dynamic>>.from(_savedDrafts)..removeAt(index);
                              final prefs = ref.read(sharedPreferencesProvider);
                              await prefs.setString(_draftsListKey, jsonEncode(updated));
                              setState(() => _savedDrafts = updated);
                              if (updated.isEmpty && ctx.mounted) Navigator.pop(ctx);
                            },
                          ),
                          onTap: () {
                            setState(() {
                              _contentController.text = d['text'] ?? '';
                              if (d['channelId'] != null) {
                                _channelId = d['channelId'];
                              }
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      final status = await Permission.location.request();
      if (status.isDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location permission denied")),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _address = "Location Attached";
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error getting location: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _showAudienceScopePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  alignment: Alignment.center,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Text(
                    'Choose Audience & Channel',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.public, color: AppColors.primaryInk),
                  title: const Text('Everyone', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Visible to anyone on campus feed'),
                  trailing: _visibility == 'everyone' && _channelId == 'general'
                      ? const Icon(Icons.check, color: AppColors.primaryInk)
                      : null,
                  onTap: () {
                    setState(() {
                      _visibility = 'everyone';
                      _channelId = 'general';
                      _isAnonymous = false;
                    });
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.people_alt_outlined, color: AppColors.secondaryTeal),
                  title: const Text('Followers Only', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Only users who follow your profile'),
                  trailing: _visibility == 'followers'
                      ? const Icon(Icons.check, color: AppColors.secondaryTeal)
                      : null,
                  onTap: () {
                    setState(() {
                      _visibility = 'followers';
                    });
                    Navigator.pop(ctx);
                  },
                ),
                const Divider(indent: 16, endIndent: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Text(
                    'Campus Channels',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    'general',
                    'engineering',
                    'hostel',
                    'confessions',
                    'freshers',
                  ].map((ch) {
                    final isSelected = _channelId == ch;
                    return Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(ch[0].toUpperCase() + ch.substring(1)),
                        selectedColor: AppColors.primaryInk.withValues(alpha: 0.15),
                        checkmarkColor: AppColors.primaryInk,
                        onSelected: (_) {
                          setState(() {
                            _channelId = ch;
                            _isAnonymous = (ch == 'confessions');
                          });
                          Navigator.pop(ctx);
                        },
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showReplyPermissionPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  alignment: Alignment.center,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Text(
                    'Who can reply?',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                  child: Text(
                    'Choose who can reply to this post. Anyone mentioned can always reply.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.public, color: AppColors.primaryInk),
                  title: const Text('Everyone', style: TextStyle(fontWeight: FontWeight.w600)),
                  trailing: _replyPermission == 'everyone'
                      ? const Icon(Icons.check, color: AppColors.primaryInk)
                      : null,
                  onTap: () {
                    setState(() => _replyPermission = 'everyone');
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.people_outline, color: AppColors.primaryInk),
                  title: const Text('People you follow', style: TextStyle(fontWeight: FontWeight.w600)),
                  trailing: _replyPermission == 'following'
                      ? const Icon(Icons.check, color: AppColors.primaryInk)
                      : null,
                  onTap: () {
                    setState(() => _replyPermission = 'following');
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.alternate_email, color: AppColors.primaryInk),
                  title: const Text('Only accounts you mention', style: TextStyle(fontWeight: FontWeight.w600)),
                  trailing: _replyPermission == 'mentioned'
                      ? const Icon(Icons.check, color: AppColors.primaryInk)
                      : null,
                  onTap: () {
                    setState(() => _replyPermission = 'mentioned');
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _submitPost() async {
    if (!_canPost) return;

    setState(() => _isPosting = true);

    final messenger = ScaffoldMessenger.of(rootNavigatorKey.currentContext!);
    final authRepo = ref.read(authRepositoryProvider);
    final user = authRepo.currentUser;
    if (user == null) {
      setState(() => _isPosting = false);
      return;
    }

    final userRepo = ref.read(userRepositoryProvider);
    final postRepo = ref.read(postRepositoryProvider);
    final storage = CloudStorageService();
    final container = ref.container;

    // Capture all UI state before popping
    final content = _contentController.text.trim();
    final linkUrl = _detectedLinkUrl;
    final channelId = _channelId;
    final isAnonymous = _isAnonymous;
    final visibility = _visibility;
    final replyPermission = _replyPermission;
    final scheduledAt = _scheduledAt;
    final mediaAltText = _mediaAltText;
    final selectedImages = List<XFile>.from(_selectedImages);
    final selectedVideo = _selectedVideo;
    final selectedDocument = _selectedDocument;
    final showPollCreator = _showPollCreator;
    final pollOptionsText = _pollOptions.map((c) => c.text.trim()).toList();
    final pollDuration = _pollDuration;
    final latitude = _latitude;
    final longitude = _longitude;

    // Pop immediately
    context.pop();

    messenger.showSnackBar(
      const SnackBar(
        content: Text('📤 Uploading post...'),
        duration: Duration(seconds: 2),
      ),
    );

    // Background process
    () async {
      try {
        final appUser = await userRepo.getUserById(user.uid);

        String mediaUrl = '';
        List<String> mediaUrls = [];
        MediaType mediaType = MediaType.none;

        if (selectedImages.isNotEmpty) {
          final uploadFutures = selectedImages.map(
            (img) => storage.uploadImage(
              img,
              path: 'post_images/${user.uid}/',
            ),
          );
          final results = await Future.wait(uploadFutures);
          mediaUrls = results.where((r) => r.isNotEmpty).toList();
          mediaUrl = mediaUrls.isNotEmpty ? mediaUrls.first : '';
          mediaType = MediaType.image;
        } else if (selectedVideo != null) {
          mediaUrl = await storage.uploadVideo(
            selectedVideo,
            path: 'post_videos/${user.uid}/',
          );
          mediaType = MediaType.video;
        } else if (selectedDocument != null) {
          final docBytes = selectedDocument.bytes ??
              (selectedDocument.path != null
                  ? await File(selectedDocument.path!).readAsBytes()
                  : null);
          if (docBytes != null) {
            mediaUrl = await storage.uploadDocument(
              docBytes,
              selectedDocument.name,
            );
            mediaType = MediaType.document;
          }
        }

        Map<String, dynamic>? pollData;
        if (showPollCreator) {
          final optionsStrings = pollOptionsText
              .where((t) => t.isNotEmpty)
              .toList();
          if (optionsStrings.length >= 2) {
            int days = 1;
            if (pollDuration.contains('3')) days = 3;
            if (pollDuration.contains('7')) days = 7;

            pollData = {
              'options': optionsStrings,
              'votes': List<int>.filled(optionsStrings.length, 0),
              'voters': <String, int>{},
              'ends_at': DateTime.now()
                  .add(Duration(days: days))
                  .toIso8601String(),
            };
          }
        }

        final post = Post(
          id: const Uuid().v4(),
          authorId: user.uid,
          authorName: isAnonymous
              ? 'Anonymous'
              : (appUser?.displayName ?? 'Anonymous'),
          authorHandle: isAnonymous ? '@hidden' : (appUser?.handle ?? '@anon'),
          authorAvatarUrl: isAnonymous ? null : appUser?.avatarUrl,
          content: content,
          mediaUrl: mediaUrl,
          mediaUrls: mediaUrls,
          mediaType: mediaType,
          timestamp: DateTime.now(),
          channelId: channelId,
          isVerified: isAnonymous ? false : (appUser?.isVerified ?? false),
          verificationType: isAnonymous
              ? 'none'
              : (appUser?.verificationType ?? 'none'),
          isAnonymous: isAnonymous,
          pollData: pollData,
          hashtags: RegExp(
            r"#(\w+)",
          ).allMatches(content).map((m) => m.group(1)!.toLowerCase()).toList(),
          mentions: RegExp(
            r"@(\w+)",
          ).allMatches(content).map((m) => m.group(1)!).toList(),
          visibility: visibility,
          latitude: latitude,
          longitude: longitude,
          locationName: _address,
          replyPermission: replyPermission,
          scheduledAt: scheduledAt,
          mediaAltText: selectedDocument != null ? selectedDocument.name : mediaAltText,
          linkUrl: linkUrl,
        );

        await postRepo.addPost(post);
        container.invalidate(paginatedFeedProvider);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Post shared!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('❌ Failed to upload post: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }();
  }

  String get _audiencePillLabel {
    if (_channelId != 'general') {
      return '${_channelId[0].toUpperCase()}${_channelId.substring(1)} ▾';
    }
    if (_visibility == 'followers') {
      return 'Followers ▾';
    }
    return 'Everyone ▾';
  }

  String get _replyPermissionLabel {
    if (_replyPermission == 'following') {
      return 'People you follow can reply';
    } else if (_replyPermission == 'mentioned') {
      return 'Only accounts you mention can reply';
    }
    return 'Everyone can reply';
  }

  IconData get _replyPermissionIcon {
    if (_replyPermission == 'following') {
      return Icons.people_outline;
    } else if (_replyPermission == 'mentioned') {
      return Icons.alternate_email;
    }
    return Icons.public;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUserAsync = ref.watch(currentUserProvider);
    final textLength = _contentController.text.length;
    const maxChars = 280;
    final charRatio = (textLength / maxChars).clamp(0.0, 1.0);
    final remainingChars = maxChars - textLength;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // 1. Top Bar (Clean & Contextual)
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: isDark ? Colors.white : Colors.black87,
            size: 24,
          ),
          onPressed: () async {
            final nav = Navigator.of(context);
            if (_contentController.text.trim().isNotEmpty) {
              await _saveCurrentAsDraft();
            }
            if (mounted) {
              nav.pop();
            }
          },
        ),
        title: null,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Drafts secondary action button on top-right
          TextButton(
            onPressed: _showDraftsSheet,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              foregroundColor: isDark ? Colors.white70 : Colors.black54,
            ),
            child: Text(
              _savedDrafts.isNotEmpty
                  ? 'Drafts (${_savedDrafts.length})'
                  : 'Drafts',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: _savedDrafts.isNotEmpty
                    ? (isDark ? Colors.white : Colors.black87)
                    : Colors.grey,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isPosting) const LinearProgressIndicator(minHeight: 2),
          // 2. Main Compose Area (Borderless Canvas)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Avatar top-left
                  Builder(
                    builder: (context) {
                      final user = currentUserAsync.value ?? ref.watch(authRepositoryProvider).currentUser;
                      return UserAvatar(
                        userId: user?.uid ?? '',
                        avatarUrl: _isAnonymous ? null : user?.avatarUrl,
                        displayName: _isAnonymous ? '?' : (user?.displayName ?? user?.handle ?? 'U'),
                        radius: 20,
                        showStoryRing: false,
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  // Content column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Audience Scope Pill: ONLY [ Everyone ▾ ] next to avatar
                        GestureDetector(
                          onTap: _showAudienceScopePicker,
                          child: Container(
                            margin: const EdgeInsets.only(top: 2, bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              border: Border.all(
                                color: isDark ? Colors.white24 : Colors.grey[400]!,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _audiencePillLabel,
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : Colors.grey[800],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Borderless Text Input Canvas
                        CompositedTransformTarget(
                          link: _layerLink,
                          child: TextField(
                            controller: _contentController,
                            autofocus: true,
                            maxLines: null,
                            decoration: InputDecoration(
                              hintText: "What is happening?!",
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              hintStyle: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w400,
                                color: isDark ? Colors.grey[600] : Colors.grey[400],
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            style: TextStyle(
                              fontSize: 19,
                              height: 1.35,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),

                        // Link preview
                        if (_detectedLinkUrl != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: LinkPreviewCard(url: _detectedLinkUrl),
                          ),

                        // Mention Autocomplete
                        if (_mentionQuery != null && _userSuggestions.isNotEmpty)
                          CompositedTransformFollower(
                            link: _layerLink,
                            showWhenUnlinked: false,
                            offset: const Offset(0, 40),
                            child: Material(
                              elevation: 8,
                              borderRadius: BorderRadius.circular(12),
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              child: Container(
                                constraints: const BoxConstraints(maxHeight: 200),
                                width: 280,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: _userSuggestions.length,
                                  itemBuilder: (context, index) {
                                    final user = _userSuggestions[index];
                                    return ListTile(
                                      leading: CircleAvatar(
                                        radius: 16,
                                        backgroundImage: user.avatarUrl != null
                                            ? CachedNetworkImageProvider(user.avatarUrl!)
                                            : null,
                                        child: user.avatarUrl == null
                                            ? const Icon(Icons.person, size: 18)
                                            : null,
                                      ),
                                      title: Text(
                                        user.displayName,
                                        style: TextStyle(
                                          color: isDark ? Colors.white : Colors.black87,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text(
                                        "@${user.handle}",
                                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                                      ),
                                      onTap: () => _applyMention(user),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),

                        // Hashtag Autocomplete
                        if (_hashtagQuery != null)
                          CompositedTransformFollower(
                            link: _layerLink,
                            showWhenUnlinked: false,
                            offset: const Offset(0, 40),
                            child: Material(
                              elevation: 8,
                              borderRadius: BorderRadius.circular(12),
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              child: Container(
                                constraints: const BoxConstraints(maxHeight: 160),
                                width: 200,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListView(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  children: _tagSuggestions
                                      .where((t) => t.contains(_hashtagQuery!))
                                      .map(
                                        (tag) => ListTile(
                                          title: Text(
                                            "#$tag",
                                            style: TextStyle(
                                              color: isDark ? Colors.white : Colors.black87,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          onTap: () => _applyHashtag(tag),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ),
                          ),

                        // Selected Images Previews
                        if (_selectedImages.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_selectedImages.length == 1)
                                  Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: kIsWeb
                                            ? Image.network(
                                                _selectedImages.first.path,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                                height: 260,
                                              )
                                            : Image.file(
                                                File(_selectedImages.first.path),
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                                height: 260,
                                              ),
                                      ),
                                      Positioned(
                                        top: 8,
                                        right: 48,
                                        child: IconButton(
                                          onPressed: () async {
                                            final edited = await UnifiedImageEditor.open(
                                              context,
                                              file: File(_selectedImages.first.path),
                                            );
                                            if (edited != null && mounted) {
                                              setState(() {
                                                _selectedImages[0] = edited;
                                              });
                                            }
                                          },
                                          icon: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.brush,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                      _buildRemoveButton(
                                        () => setState(() => _selectedImages.removeAt(0)),
                                      ),
                                      Positioned(
                                        bottom: 12,
                                        left: 12,
                                        child: GestureDetector(
                                          onTap: _editAltText,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              _mediaAltText == null ? '+ ALT' : 'ALT',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  SizedBox(
                                    height: 200,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: _selectedImages.length < 10
                                          ? _selectedImages.length + 1
                                          : _selectedImages.length,
                                      separatorBuilder: (context, index) => const SizedBox(width: 10),
                                      itemBuilder: (context, index) {
                                        if (index == _selectedImages.length) {
                                          return GestureDetector(
                                            onTap: _pickImage,
                                            child: Container(
                                              width: 130,
                                              decoration: BoxDecoration(
                                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: isDark ? Colors.white24 : Colors.grey[300]!,
                                                ),
                                              ),
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                    Icons.add_photo_alternate_outlined,
                                                    size: 28,
                                                    color: AppColors.primaryInk,
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    'Add Photo',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: isDark ? Colors.white70 : Colors.grey[800],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }

                                        final img = _selectedImages[index];
                                        return Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(16),
                                              child: Container(
                                                width: 150,
                                                height: 200,
                                                color: isDark ? Colors.grey[900] : Colors.grey[200],
                                                child: kIsWeb
                                                    ? Image.network(
                                                        img.path,
                                                        width: 150,
                                                        height: 200,
                                                        fit: BoxFit.cover,
                                                      )
                                                    : Image.file(
                                                        File(img.path),
                                                        width: 150,
                                                        height: 200,
                                                        fit: BoxFit.cover,
                                                      ),
                                              ),
                                            ),
                                            Positioned(
                                              top: 8,
                                              left: 8,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 7,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withValues(alpha: 0.65),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  '${index + 1}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            _buildRemoveButton(
                                              () => setState(() => _selectedImages.removeAt(index)),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),

                        // Selected Video Preview
                        if (_selectedVideo != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    height: 240,
                                    width: double.infinity,
                                    color: Colors.black,
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.play_circle_fill,
                                            size: 56,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'Video Selected',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            _selectedVideo!.name,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                _buildRemoveButton(
                                  () => setState(() => _selectedVideo = null),
                                ),
                              ],
                            ),
                          ),

                        // Selected Document Preview
                        if (_selectedDocument != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: DocumentPreviewCard(
                              fileName: _selectedDocument!.name,
                              fileSize: _selectedDocument!.size > 0
                                  ? '${(_selectedDocument!.size / (1024 * 1024)).toStringAsFixed(1)} MB'
                                  : null,
                              onRemove: () => setState(() => _selectedDocument = null),
                            ),
                          ),

                        // Location attachment chip
                        if (_latitude != null)
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryInk.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: AppColors.primaryInk,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _address ?? "Location attached",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() {
                                    _latitude = null;
                                    _longitude = null;
                                    _address = null;
                                  }),
                                  child: const Icon(Icons.close, size: 16),
                                ),
                              ],
                            ),
                          ),

                        // Poll Creator Area
                        if (_showPollCreator)
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                for (int i = 0; i < _pollOptions.length; i++)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: TextField(
                                      controller: _pollOptions[i],
                                      decoration: InputDecoration(
                                        hintText: "Choice ${i + 1}",
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        prefixIcon: const Icon(Icons.add, size: 16),
                                      ),
                                    ),
                                  ),
                                if (_pollOptions.length < 4)
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _pollOptions.add(TextEditingController());
                                      });
                                    },
                                    child: const Text("Add another choice"),
                                  ),
                                const Divider(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("Poll Length"),
                                    TextButton(
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => SimpleDialog(
                                            title: const Text("Poll Duration"),
                                            children: ['1 Day', '3 Days', '7 Days'].map((d) {
                                              return SimpleDialogOption(
                                                onPressed: () {
                                                  setState(() => _pollDuration = d);
                                                  Navigator.pop(context);
                                                },
                                                child: Text(d),
                                              );
                                            }).toList(),
                                          ),
                                        );
                                      },
                                      child: Text(_pollDuration),
                                    ),
                                  ],
                                ),
                                TextButton(
                                  onPressed: _togglePoll,
                                  child: const Text(
                                    "Remove Poll",
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Middle / Context Line (Pre-Keyboard Anchor: Reply Permission)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF222834) : Colors.grey[200]!,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _showReplyPermissionPicker,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _replyPermissionIcon,
                        size: 16,
                        color: AppColors.primaryInk,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$_replyPermissionLabel ▾',
                        style: const TextStyle(
                          color: AppColors.primaryInk,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 4. Bottom Action Bar (Streamlined & Accessible)
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF1E2530) : Colors.grey[200]!,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Consolidated left tools: Media (unified), GIF, Poll, Pin, Clock
                  _ToolbarIcon(
                    icon: Icons.image_outlined,
                    onTap: _openUnifiedMediaPicker,
                  ),
                  _ToolbarIcon(
                    icon: Icons.upload_file_rounded,
                    onTap: _pickDocument,
                    isActive: _selectedDocument != null,
                  ),
                  _ToolbarIcon(
                    icon: Icons.ballot_outlined,
                    onTap: _togglePoll,
                    isActive: _showPollCreator,
                  ),
                  _ToolbarIcon(
                    icon: Icons.location_on_outlined,
                    onTap: _isLoadingLocation ? null : _getCurrentLocation,
                    isActive: _latitude != null,
                    isLoading: _isLoadingLocation,
                  ),
                  _ToolbarIcon(
                    icon: Icons.schedule_outlined,
                    onTap: _schedulePost,
                    isActive: _scheduledAt != null,
                  ),

                  const Spacer(),

                  // Character Counter ring
                  if (textLength > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              value: charRatio,
                              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                              color: remainingChars < 0
                                  ? Colors.red
                                  : remainingChars < 20
                                      ? Colors.amber
                                      : AppColors.primaryInk,
                              strokeWidth: 2.2,
                            ),
                          ),
                          if (remainingChars < 20)
                            Text(
                              '$remainingChars',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: remainingChars < 0 ? Colors.red : Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),

                  // Thumb-Zone Primary Action: Post button
                  SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      onPressed: _canPost ? _submitPost : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryInk,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: isDark
                            ? const Color(0xFF223550)
                            : AppColors.primaryInk.withValues(alpha: 0.35),
                        disabledForegroundColor: isDark
                            ? Colors.white38
                            : Colors.white70,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      child: _isPosting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "Post",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemoveButton(VoidCallback onTap) {
    return Positioned(
      top: 8,
      right: 8,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

class _ToolbarIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool isActive;
  final bool isLoading;

  const _ToolbarIcon({
    required this.icon,
    required this.onTap,
    this.isActive = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryInk),
          ),
        ),
      );
    }
    return IconButton(
      icon: Icon(
        icon,
        color: isActive ? AppColors.primaryInk : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
        size: 22,
      ),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
    );
  }
}
