import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:giphy_get/giphy_get.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../data/post_repository.dart';
import '../../user/data/user_repository.dart';
import '../../../core/services/firebase_storage_service.dart';
import '../domain/post.dart';
import '../../auth/data/auth_repository.dart';
import '../../../core/theme/app_colors.dart'; // Ensure we have access to colors

class CreatePostScreen extends ConsumerStatefulWidget {
  final String? initialChannelId;
  const CreatePostScreen({super.key, this.initialChannelId});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _contentController = TextEditingController();
  final _picker = ImagePicker();

  XFile? _selectedImage;
  XFile? _selectedVideo;
  GiphyGif? _selectedGif;

  bool _isPosting = false;
  bool _isAnonymous = false;
  String _channelId = 'general'; // Default to general
  String _visibility = 'everyone'; // everyone, followers

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
  final String _pollDuration = '1 Day';

  // API Key (Moved to a secure config in real app, but here for now)
  final String _giphyApiKey = 'DnmoJ3pdO49O9K45y8zYwe7sZdDNuXOx';

  @override
  void initState() {
    super.initState();
    if (widget.initialChannelId != null) {
      _channelId = widget.initialChannelId!;
    }
    _contentController.addListener(_updateState);
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
      final results = await ref
          .read(userRepositoryProvider)
          .searchUsers(query)
          .first;
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

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = pickedFile;
        _selectedVideo = null;
        _selectedGif = null;
        _showPollCreator =
            false; // Twitter disables polls if media attached usually
      });
    }
  }

  Future<void> _pickVideo() async {
    final pickedFile = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 5), // Limit video length
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
      }
    });
  }

  Future<String> _uploadImage(XFile image, String uid) async {
    try {
      final storage = FirebaseStorageService();
      return await storage.uploadImage(image, path: 'post_images/$uid/');
    } catch (e) {
      debugPrint("Firebase Storage Upload Error: $e");
      return '';
    }
  }

  Future<String> _uploadVideo(XFile video, String uid) async {
    try {
      final storage = FirebaseStorageService();
      return await storage.uploadVideo(video, path: 'post_videos/$uid/');
    } catch (e) {
      debugPrint("Firebase Storage Video Upload Error: $e");
      return '';
    }
  }

  Future<void> _submitPost() async {
    if (!_canPost) return;

    setState(() => _isPosting = true);

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final user = authRepo.currentUser;
      if (user == null) throw Exception("Not logged in");

      final userRepo = ref.read(userRepositoryProvider);
      final appUser = await userRepo.getUserById(user.uid);

      String mediaUrl = '';
      MediaType mediaType = MediaType.none;

      if (_selectedImage != null) {
        mediaUrl = await _uploadImage(_selectedImage!, user.uid);
        mediaType = MediaType.image;
      } else if (_selectedVideo != null) {
        mediaUrl = await _uploadVideo(_selectedVideo!, user.uid);
        mediaType = MediaType.video;
      } else if (_selectedGif != null) {
        mediaUrl =
            _selectedGif!.images?.fixedWidth.url ??
            _selectedGif!.images?.original?.url ??
            '';
        mediaType = MediaType.gif;
      }

      Map<String, dynamic>? pollData;
      if (_showPollCreator) {
        pollData = {
          'options': _pollOptions
              .map((c) => {'text': c.text.trim(), 'votes': 0})
              .toList(),
          'duration': _pollDuration,
          'endsAt': DateTime.now()
              .add(const Duration(days: 1))
              .toIso8601String(), // Simplified duration logic
        };
      }

      final post = Post(
        id: const Uuid().v4(),
        authorId: user.uid,
        authorName: _isAnonymous
            ? 'Anonymous'
            : (appUser?.displayName ?? 'Anonymous'),
        authorHandle: _isAnonymous ? '@hidden' : (appUser?.handle ?? '@anon'),
        authorAvatarUrl: _isAnonymous ? null : appUser?.avatarUrl,
        content: _contentController.text.trim(),
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        timestamp: DateTime.now(),
        channelId: _channelId,
        isVerified: _isAnonymous ? false : (appUser?.isVerified ?? false),
        verificationType: _isAnonymous
            ? 'none'
            : (appUser?.verificationType ?? 'none'),
        isAnonymous: _isAnonymous,
        pollData: pollData,
        hashtags: RegExp(r"#(\w+)")
            .allMatches(_contentController.text)
            .map((m) => m.group(1)!.toLowerCase())
            .toList(),
        mentions: RegExp(
          r"@(\w+)",
        ).allMatches(_contentController.text).map((m) => m.group(1)!).toList(),
        visibility: _visibility,
      );

      await ref.read(postRepositoryProvider).addPost(post);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
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
          onPressed: () => context.pop(),
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
                  disabledBackgroundColor: AppColors.primaryInk.withOpacity(
                    0.5,
                  ),
                  disabledForegroundColor: Colors.white.withOpacity(0.5),
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
                  // Avatar
                  currentUserAsync.when(
                    data: (user) => CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey[300],
                      backgroundImage:
                          (user?.avatarUrl != null && !_isAnonymous)
                          ? CachedNetworkImageProvider(user!.avatarUrl!)
                          : null,
                      child: (user?.avatarUrl == null || _isAnonymous)
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                    loading: () => const CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey,
                    ),
                    error: (_, __) => const CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Input Area
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              // Audience Selector
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

                              // Channel Selector
                              PopupMenuButton<String>(
                                initialValue: _channelId,
                                onSelected: (val) => setState(() {
                                  _channelId = val;
                                  if (val == 'confessions') {
                                    _isAnonymous = true;
                                  }
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
                                  child: Image.file(
                                    File(_selectedImage!.path),
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    // limit height if needed
                                    height: 300,
                                  ),
                                ),
                                _buildRemoveButton(
                                  () => setState(() => _selectedImage = null),
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
                                          Icon(
                                            Icons.play_circle_fill,
                                            size: 64,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Video Selected',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            _selectedVideo!.name,
                                            style: TextStyle(
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

                        // Poll Creator
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
                                      onPressed: () {}, // Todo duration picker
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

          // Bottom Toolbar (Twitter Style)
          Container(
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
                Row(
                  children: [
                    Text(
                      "Everyone can reply",
                      style: TextStyle(
                        color: AppColors.secondaryTeal,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.public,
                      size: 14,
                      color: AppColors.secondaryTeal,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _ToolbarIcon(icon: Icons.image_outlined, onTap: _pickImage),
                    _ToolbarIcon(
                      icon: Icons.missed_video_call_outlined,
                      onTap: _pickVideo,
                    ), // Video Icon
                    _ToolbarIcon(icon: Icons.gif_box_outlined, onTap: _pickGif),
                    _ToolbarIcon(
                      icon: Icons.poll_outlined,
                      onTap: _togglePoll,
                      isActive: _showPollCreator,
                    ),
                    _ToolbarIcon(
                      icon: Icons.location_on_outlined,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Location coming soon!"),
                          ),
                        );
                      },
                    ),
                    const Spacer(),

                    // Character Count (Circle)
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

                    // Removed redundant "Add" button
                  ],
                ),
              ],
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
  final VoidCallback onTap;
  final bool isActive;

  const _ToolbarIcon({
    required this.icon,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        icon,
        color: isActive ? AppColors.secondaryTeal : AppColors.secondaryTeal,
      ),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
    );
  }
}
