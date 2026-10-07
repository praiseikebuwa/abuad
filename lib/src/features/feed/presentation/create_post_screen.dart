import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../camera/presentation/camera_screen.dart';
import '../../../core/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:giphy_get/giphy_get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/post_repository.dart';
import 'providers/feed_provider.dart';
import '../../shared/presentation/unified_image_editor.dart';
import '../../../core/services/firebase_storage_service.dart';
import '../domain/post.dart';
import '../../auth/data/auth_repository.dart';
import '../../../core/providers/shared_preferences_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/url_validator.dart';
import '../../../shared/widgets/user_avatar.dart';
import 'widgets/link_preview_card.dart';

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

  XFile? _selectedImage;
  XFile? _selectedVideo;
  GiphyGif? _selectedGif;

  final bool _isPosting = false;
  bool _isAnonymous = false;
  String _channelId = 'general';
  String _visibility = 'everyone';

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
  String _replyPermission = 'everyone';
  DateTime? _scheduledAt;
  String? _mediaAltText;

  final String _giphyApiKey = 'DnmoJ3pdO49O9K45y8zYwe7sZdDNuXOx';

  @override
  void initState() {
    super.initState();
    if (widget.initialChannelId != null) {
      _channelId = widget.initialChannelId!;
    }
    _contentController.addListener(_updateState);
    _loadDraft();

    if (widget.initialMedia != null) {
      if (widget.initialMode == CameraMode.video) {
        _selectedVideo = widget.initialMedia;
      } else {
        _selectedImage = widget.initialMedia;
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
      if (word.startsWith('@') && word.length > 2) {
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
      final results = await ref
          .read(userRepositoryProvider)
          .searchUsers(query);
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
        _selectedImage != null ||
        _selectedGif != null ||
        _selectedVideo != null;
    final hasPoll =
        _showPollCreator && _pollOptions.every((c) => c.text.trim().isNotEmpty);
    return (hasContent || hasMedia || hasPoll) && !_isPosting;
  }

  String? get _detectedLinkUrl =>
      UrlValidator.extractFirstUrl(_contentController.text);

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = pickedFile;
        _selectedVideo = null;
        _selectedGif = null;
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
        _selectedImage = null;
        _selectedGif = null;
        _showPollCreator = false;
      });
    }
  }

  Future<void> _pickGif() async {
    final gif = await GiphyGet.getGif(
      context: context,
      apiKey: _giphyApiKey,
      lang: GiphyLanguage.english,
      randomID: const Uuid().v4(),
    );

    if (gif != null) {
      setState(() {
        _selectedGif = gif;
        _selectedImage = null;
        _selectedVideo = null;
        _showPollCreator = false;
      });
    }
  }

  void _togglePoll() {
    setState(() {
      _showPollCreator = !_showPollCreator;
      if (_showPollCreator) {
        _selectedImage = null;
        _selectedVideo = null;
        _selectedGif = null;
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

  static const String _draftKey = 'create_post_draft';

  Future<void> _loadDraft() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final draft = prefs.getString(_draftKey);
    if (draft != null && draft.isNotEmpty && mounted) {
      final shouldLoad = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Resume Draft?'),
          content: const Text(
            'You have an unsaved post. Would you like to resume?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Discard'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Resume'),
            ),
          ],
        ),
      );

      if (shouldLoad == true) {
        setState(() => _contentController.text = draft);
      } else {
        await prefs.remove(_draftKey);
      }
    }
  }

  Future<void> _saveDraft() async {
    if (_contentController.text.trim().isEmpty) return;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_draftKey, _contentController.text.trim());
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

  void _submitPost() async {
    if (!_canPost) return;

    final messenger = ScaffoldMessenger.of(rootNavigatorKey.currentContext!);
    final authRepo = ref.read(authRepositoryProvider);
    final user = authRepo.currentUser;
    if (user == null) return;

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
    final selectedImage = _selectedImage;
    final selectedVideo = _selectedVideo;
    final selectedGif = _selectedGif;
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
        MediaType mediaType = MediaType.none;

        if (selectedImage != null) {
          mediaUrl = await storage.uploadImage(
            selectedImage,
            path: 'post_images/${user.uid}/',
          );
          mediaType = MediaType.image;
        } else if (selectedVideo != null) {
          mediaUrl = await storage.uploadVideo(
            selectedVideo,
            path: 'post_videos/${user.uid}/',
          );
          mediaType = MediaType.video;
        } else if (selectedGif != null) {
          mediaUrl =
              selectedGif.images?.fixedWidth.url ??
              selectedGif.images?.original?.url ??
              '';
          mediaType = MediaType.gif;
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
          mediaAltText: mediaAltText,
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
              onPressed: () {
                // In a full implementation, we might save the failed post to a 'Drafts' list here.
              },
            ),
          ),
        );
      }
    }();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUserAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leadingWidth: 80,
        leading: TextButton(
          onPressed: () async {
            final nav = Navigator.of(context);
            if (_contentController.text.isNotEmpty) {
              await _saveDraft();
            }
            if (mounted) {
              nav.pop();
            }
          },
          child: Icon(
            Icons.close,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        title: null,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: SizedBox(
              height: 32,
              child: ElevatedButton(
                onPressed: _canPost ? _submitPost : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryInk,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primaryInk.withValues(
                    alpha: 0.5,
                  ),
                  disabledForegroundColor: Colors.white.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isPosting) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  currentUserAsync.when(
                    data: (user) => UserAvatar(
                      userId: user?.uid ?? '',
                      avatarUrl: _isAnonymous ? null : user?.avatarUrl,
                      displayName: _isAnonymous ? '?' : user?.displayName,
                      radius: 20,
                      showStoryRing: false,
                    ),
                    loading: () => const CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey,
                    ),
                    error: (_, _) => const CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              PopupMenuButton<String>(
                                onSelected: (val) =>
                                    setState(() => _visibility = val),
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'everyone',
                                    child: Text('Everyone'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'followers',
                                    child: Text('Followers Only'),
                                  ),
                                ],
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: AppColors.secondaryTeal,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _visibility == 'everyone'
                                            ? 'Everyone'
                                            : 'Followers Only',
                                        style: const TextStyle(
                                          color: AppColors.secondaryTeal,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.keyboard_arrow_down,
                                        color: AppColors.secondaryTeal,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              PopupMenuButton<String>(
                                onSelected: (val) =>
                                    setState(() => _replyPermission = val),
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'everyone',
                                    child: ListTile(
                                      leading: Icon(Icons.public, size: 20),
                                      title: Text('Everyone'),
                                      dense: true,
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'following',
                                    child: ListTile(
                                      leading: Icon(Icons.people, size: 20),
                                      title: Text('People you follow'),
                                      dense: true,
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'mentioned',
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.alternate_email,
                                        size: 20,
                                      ),
                                      title: Text('Only mentioned people'),
                                      dense: true,
                                    ),
                                  ),
                                ],
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey[400]!,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _replyPermission == 'everyone'
                                            ? Icons.public
                                            : _replyPermission == 'following'
                                            ? Icons.people
                                            : Icons.alternate_email,
                                        size: 14,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _replyPermission == 'everyone'
                                            ? 'Everyone can reply'
                                            : _replyPermission == 'following'
                                            ? 'Followers can reply'
                                            : 'Only mentioned can reply',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              PopupMenuButton<String>(
                                initialValue: _channelId,
                                onSelected: (val) => setState(() {
                                  _channelId = val;
                                  if (val == 'confessions') _isAnonymous = true;
                                }),
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'general',
                                    child: Text('General'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'engineering',
                                    child: Text('Engineering'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'hostel',
                                    child: Text('Hostel'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'confessions',
                                    child: Text('Confessions'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'freshers',
                                    child: Text('Freshers'),
                                  ),
                                ],
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.grey[600]!,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _channelId[0].toUpperCase() +
                                            _channelId.substring(1),
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.grey[700],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Icon(
                                        Icons.keyboard_arrow_down,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.grey[700],
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        CompositedTransformTarget(
                          link: _layerLink,
                          child: TextField(
                            controller: _contentController,
                            autofocus: true,
                            maxLines: null,
                            decoration: const InputDecoration(
                              hintText: "What is happening?!",
                              border: InputBorder.none,
                              hintStyle: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                              contentPadding: EdgeInsets.zero,
                            ),
                            style: TextStyle(
                              fontSize: 18,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                        if (_detectedLinkUrl != null)
                          LinkPreviewCard(url: _detectedLinkUrl),

                        if (_mentionQuery != null &&
                            _userSuggestions.isNotEmpty)
                          CompositedTransformFollower(
                            link: _layerLink,
                            showWhenUnlinked: false,
                            offset: const Offset(0, 40),
                            child: Material(
                              elevation: 8,
                              borderRadius: BorderRadius.circular(12),
                              color: isDark ? Colors.grey[900] : Colors.white,
                              child: Container(
                                constraints: const BoxConstraints(
                                  maxHeight: 200,
                                ),
                                width: 300,
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
                                            ? CachedNetworkImageProvider(
                                                user.avatarUrl!,
                                              )
                                            : null,
                                        child: user.avatarUrl == null
                                            ? const Icon(Icons.person, size: 20)
                                            : null,
                                      ),
                                      title: Text(
                                        user.displayName,
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                          fontSize: 14,
                                        ),
                                      ),
                                      subtitle: Text(
                                        "@${user.handle}",
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                      onTap: () => _applyMention(user),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),

                        if (_hashtagQuery != null)
                          CompositedTransformFollower(
                            link: _layerLink,
                            showWhenUnlinked: false,
                            offset: const Offset(0, 40),
                            child: Material(
                              elevation: 8,
                              borderRadius: BorderRadius.circular(12),
                              color: isDark ? Colors.grey[900] : Colors.white,
                              child: Container(
                                constraints: const BoxConstraints(
                                  maxHeight: 150,
                                ),
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
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black,
                                              fontSize: 14,
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

                        // Media Previews
                        if (_selectedImage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: kIsWeb
                                      ? Image.network(
                                          _selectedImage!.path,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          height: 300,
                                        )
                                      : Image.file(
                                          File(_selectedImage!.path),
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          height: 300,
                                        ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 48,
                                  child: IconButton(
                                    onPressed: () async {
                                      final edited = await UnifiedImageEditor.open(
                                        context,
                                        file: File(_selectedImage!.path),
                                      );
                                      if (edited != null && mounted) {
                                        setState(() {
                                          _selectedImage = edited;
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
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                                _buildRemoveButton(
                                  () => setState(() => _selectedImage = null),
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
                            ),
                          ),

                        if (_selectedVideo != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    height: 300,
                                    width: double.infinity,
                                    color: Colors.black,
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.play_circle_fill,
                                            size: 64,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'Video Selected',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
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

                        if (_selectedGif != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: CachedNetworkImage(
                                    imageUrl:
                                        _selectedGif!.images?.fixedWidth.url ??
                                        '',
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    height: 300,
                                  ),
                                ),
                                _buildRemoveButton(
                                  () => setState(() => _selectedGif = null),
                                ),
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(4),
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

                        if (_latitude != null)
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryTeal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: AppColors.secondaryTeal,
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

                        if (_showPollCreator)
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isDark
                                    ? Colors.grey[800]!
                                    : Colors.grey[300]!,
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
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                        prefixIcon: const Icon(
                                          Icons.add,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (_pollOptions.length < 4)
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _pollOptions.add(
                                          TextEditingController(),
                                        );
                                      });
                                    },
                                    child: const Text("Add another choice"),
                                  ),
                                const Divider(),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("Poll Length"),
                                    TextButton(
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => SimpleDialog(
                                            title: const Text("Poll Duration"),
                                            children:
                                                [
                                                  '1 Day',
                                                  '3 Days',
                                                  '7 Days',
                                                ].map((d) {
                                                  return SimpleDialogOption(
                                                    onPressed: () {
                                                      setState(
                                                        () => _pollDuration = d,
                                                      );
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

          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: 8,
              ),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _ToolbarIcon(
                        icon: Icons.camera_alt_outlined,
                        onTap: () async {
                          final result = await context.push('/camera');
                          if (result != null && result is Map) {
                            final file = result['file'] as XFile?;
                            if (file != null) {
                              setState(() {
                                _selectedImage = file;
                                _selectedVideo = null;
                                _selectedGif = null;
                                _showPollCreator = false;
                              });
                            }
                          }
                        },
                      ),
                      _ToolbarIcon(
                        icon: Icons.image_outlined,
                        onTap: _pickImage,
                      ),
                      _ToolbarIcon(
                        icon: Icons.missed_video_call_outlined,
                        onTap: _pickVideo,
                      ),
                      _ToolbarIcon(
                        icon: Icons.gif_box_outlined,
                        onTap: _pickGif,
                      ),
                      _ToolbarIcon(
                        icon: Icons.poll_outlined,
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
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          value: _contentController.text.length / 280,
                          backgroundColor: Colors.grey[300],
                          color: _contentController.text.length > 280
                              ? Colors.red
                              : AppColors.secondaryTeal,
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
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
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondaryTeal),
          ),
        ),
      );
    }
    return IconButton(
      icon: Icon(icon, color: AppColors.secondaryTeal),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
    );
  }
}
