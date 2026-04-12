import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:photo_view/photo_view.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
// import 'package:giphy_get/giphy_get.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gal/gal.dart';
import 'package:dio/dio.dart';

import '../../../core/widgets/verification_badge.dart';
import '../../../core/theme/app_colors.dart';
import '../data/chat_repository.dart';
import '../domain/chat_channel.dart';
import '../domain/chat_message.dart';
import '../../user/data/user_repository.dart';
import '../../../core/services/image_upload_service.dart';
import '../../camera/presentation/camera_screen.dart';
import '../../../shared/widgets/user_avatar.dart';
import './widgets/shared_post_preview.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String channelId;
  const ChatScreen({super.key, required this.channelId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _typingTimer;
  bool _isTyping = false;
  ChatMessage? _replyingTo;
  ChatMessage? _editingMessage;
  String? _mentionQuery;
  List<AppUser> _userSuggestions = [];
  String? _wallpaperPath;
  Color _themeColor = AppColors.secondaryTeal;
  bool _showEmojiPicker = false;
  bool _hasText = false;

  // Recording & Giphy state
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isLocked = false;
  DateTime? _recordingStartTime;
  Timer? _recordingTimer;
  double _dragOffset = 0.0;

  // Snap Upload State
  final Map<String, double> _uploadingSnaps = {};

  // Audio Player for voice notes
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingUrl;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    // Mark messages as read when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatRepositoryProvider).markMessagesAsRead(widget.channelId);
      _loadSettings();
    });
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _wallpaperPath = prefs.getString('chat_wallpaper_${widget.channelId}');
        final themeName =
            prefs.getString('chat_theme_${widget.channelId}') ?? 'Teal';
        _themeColor = _getThemeColor(themeName);
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Color _getThemeColor(String name) {
    switch (name) {
      case 'Blue':
        return Colors.blue;
      case 'Purple':
        return Colors.purple;
      case 'Gold':
        return const Color(0xFFFFD700);
      default:
        return AppColors.secondaryTeal;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _recordingTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged(String text) {
    _checkMentions();
    final hasText = text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }

    if (text.isNotEmpty && !_isTyping) {
      setState(() => _isTyping = true);
      ref.read(chatRepositoryProvider).setTypingStatus(widget.channelId, true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        setState(() => _isTyping = false);
        ref
            .read(chatRepositoryProvider)
            .setTypingStatus(widget.channelId, false);
      }
    });
  }

  void _checkMentions() {
    final text = _messageController.text;
    final selection = _messageController.selection;
    if (!selection.isValid || selection.baseOffset == 0) {
      if (_userSuggestions.isNotEmpty) {
        setState(() => _userSuggestions = []);
      }
      return;
    }

    final textBeforeCursor = text.substring(0, selection.baseOffset);
    final lastWordMatch = RegExp(r"(\S+)$").firstMatch(textBeforeCursor);

    if (lastWordMatch != null) {
      final word = lastWordMatch.group(1)!;
      if (word.startsWith('@')) {
        _mentionQuery = word.substring(1);
        _fetchUserSuggestions(_mentionQuery!);
      } else {
        if (_userSuggestions.isNotEmpty) {
          setState(() => _userSuggestions = []);
        }
      }
    } else {
      if (_userSuggestions.isNotEmpty) {
        setState(() => _userSuggestions = []);
      }
    }
  }

  Future<void> _fetchUserSuggestions(String query) async {
    final repo = ref.read(chatRepositoryProvider);
    final channel = await repo.getChannel(widget.channelId);
    if (channel == null) return;

    final List<AppUser> members = [];
    for (var entry in channel.memberNames.entries) {
      members.add(
        AppUser(
          uid: entry.key,
          displayName: entry.value,
          email: '${entry.key}@abuad.edu.ng', // Fallback email
          avatarUrl: channel.memberAvatars[entry.key],
          handle: entry.value.replaceAll(' ', '').toLowerCase(),
        ),
      );
    }

    final everyone = AppUser(
      uid: 'all',
      displayName: 'All Members',
      email: 'all@abuad.edu.ng',
      handle: 'all',
    );

    final suggestions = [everyone, ...members]
        .where((u) {
          final nameMatches = u.displayName.toLowerCase().contains(
            query.toLowerCase(),
          );
          final handleMatches = u.handle.toLowerCase().contains(
            query.toLowerCase(),
          );
          return nameMatches || handleMatches;
        })
        .take(5)
        .toList();

    setState(() {
      _userSuggestions = suggestions;
    });
  }

  void _applyMention(AppUser user) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    final textBeforeCursor = text.substring(0, selection.baseOffset);
    final textAfterCursor = text.substring(selection.baseOffset);

    final lastWordMatch = RegExp(r"(\S+)$").firstMatch(textBeforeCursor);
    if (lastWordMatch != null) {
      final newTextBefore =
          "${textBeforeCursor.substring(0, lastWordMatch.start)}@${user.handle} ";
      _messageController.text = newTextBefore + textAfterCursor;
      _messageController.selection = TextSelection.collapsed(
        offset: newTextBefore.length,
      );
    }

    setState(() {
      _mentionQuery = null;
      _userSuggestions = [];
    });
  }

  // Obsolete GIPHY logic removed in favor of local picker.

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        final path =
            '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() {
          _isRecording = true;
          _isLocked = false;
          _recordingStartTime = DateTime.now();
          _dragOffset = 0.0;
        });

        // Start timer for UI updates
        _recordingTimer?.cancel();
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {});
        });
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording({bool send = true}) async {
    try {
      _recordingTimer?.cancel();
      final path = await _audioRecorder.stop();

      if (send && path != null && _recordingStartTime != null) {
        final duration = DateTime.now()
            .difference(_recordingStartTime!)
            .inSeconds;
        if (duration >= 1) {
          _sendVoiceMessage(path, duration);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message too short'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      } else if (!send && path != null) {
        // Delete the file if cancelled
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }

      setState(() {
        _isRecording = false;
        _isLocked = false;
        _recordingStartTime = null;
        _dragOffset = 0.0;
      });
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      setState(() {
        _isRecording = false;
        _isLocked = false;
      });
    }
  }

  Future<void> _cancelRecording() async {
    HapticFeedback.mediumImpact();
    await _stopRecording(send: false);
  }

  void _lockRecording() {
    if (!_isLocked) {
      HapticFeedback.heavyImpact();
      setState(() {
        _isLocked = true;
        _dragOffset = 0.0; // Reset offset for locked UI
      });
    }
  }

  Widget _buildLockedUI() {
    final duration = _recordingStartTime != null
        ? DateTime.now().difference(_recordingStartTime!).inSeconds
        : 0;
    final minutes = (duration ~/ 60).toString().padLeft(2, '0');
    final seconds = (duration % 60).toString().padLeft(2, '0');

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 28),
          onPressed: _cancelRecording,
        ),
        Expanded(
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.fiber_manual_record,
                  color: Colors.red,
                  size: 12,
                ),
                const SizedBox(width: 8),
                Text(
                  '$minutes:$seconds',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        GestureDetector(
          onTap: () => _stopRecording(send: true),
          child: Container(
            height: 48,
            width: 48,
            decoration: const BoxDecoration(
              color: AppColors.secondaryTeal,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.send, color: Colors.white, size: 24),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingUI(bool isDark) {
    final duration = _recordingStartTime != null
        ? DateTime.now().difference(_recordingStartTime!).inSeconds
        : 0;
    final minutes = (duration ~/ 60).toString().padLeft(2, '0');
    final seconds = (duration % 60).toString().padLeft(2, '0');

    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              const SizedBox(width: 8),
              const Icon(Icons.mic, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Text(
                '$minutes:$seconds',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  '< Slide to cancel',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        // Mic Button with Lock Animation
        GestureDetector(
          onLongPressMoveUpdate: (details) {
            // Drag Up to Lock (dy is negative)
            if (details.localPosition.dy < -50) {
              _lockRecording();
            } else {
              setState(() => _dragOffset = details.localPosition.dy);
            }

            // Drag Left to Cancel (dx is negative)
            if (details.localPosition.dx < -100) {
              _cancelRecording();
            }
          },
          onLongPressEnd: (details) {
            if (_isLocked) return;
            // If dragging far enough left or up, action handled in update
            _stopRecording(send: true);
          },
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Bounding Lock Icon
              if (_dragOffset < -10)
                Positioned(
                  top: _dragOffset - 40, // Float above finger
                  child: Column(
                    children: [
                      const Icon(Icons.lock_open, color: Colors.grey),
                      const Icon(Icons.keyboard_arrow_up, color: Colors.grey),
                    ],
                  ),
                ),

              // Mic Button (Scaled Up)
              Transform.scale(
                scale: 1.5,
                child: Container(
                  height: 50,
                  width: 50,
                  decoration: const BoxDecoration(
                    color: AppColors.secondaryTeal,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _sendVoiceMessage(String path, int duration) async {
    try {
      final imageService = ref.read(imageUploadServiceProvider);

      // Use specialized audio upload
      final result = await imageService.uploadAudio(
        XFile(path),
        path: 'chat_audio/${widget.channelId}/',
      );

      await ref
          .read(chatRepositoryProvider)
          .sendMessage(
            widget.channelId,
            '🎤 Voice Message',
            type: 'voice',
            audioUrl: result.url,
            duration: duration,
          );
    } catch (e) {
      debugPrint('Error uploading voice message: $e');
    }
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    // Detect mentions in content
    final List<String> mentions = [];
    // Ideally we'd map handles to IDs here, but for now we'll pass handles or rely on repo
    // To keep it clean, we'll just parse @ mentions for now.

    if (_editingMessage != null) {
      ref
          .read(chatRepositoryProvider)
          .editMessage(widget.channelId, _editingMessage!.id, content);
      setState(() => _editingMessage = null);
    } else {
      ref
          .read(chatRepositoryProvider)
          .sendMessage(
            widget.channelId,
            content,
            replyToId: _replyingTo?.id,
            replyToContent: _replyingTo?.content,
            replyToSenderId: _replyingTo?.senderId,
          );
    }

    _messageController.clear();
    setState(() {
      _replyingTo = null;
      _editingMessage = null;
    });
    _isTyping = false;
    _typingTimer?.cancel();
  }

  Future<void> _sendImage({bool isSnap = false}) async {
    try {
      final imageService = ref.read(imageUploadServiceProvider);
      final imageFile = await imageService.pickImage();

      if (imageFile == null) return;

      // Show loading
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isSnap ? 'Sending Snap...' : 'Uploading image...'),
        ),
      );

      final result = await imageService.uploadImage(
        imageFile,
        path: isSnap
            ? 'chat_snaps/${widget.channelId}/'
            : 'chat_media/${widget.channelId}/',
      );

      await ref
          .read(chatRepositoryProvider)
          .sendMessage(
            widget.channelId,
            isSnap ? '📸 Snap' : '📷 Photo',
            type: 'image',
            imageUrl: result.url,
            imageWidth: result.width,
            imageHeight: result.height,
            isSnap: isSnap,
            replyToId: _replyingTo?.id,
            replyToContent: _replyingTo?.content,
            replyToSenderId: _replyingTo?.senderId,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error uploading image: $e')));
    }
  }

  Future<void> _sendLocation() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled')),
          );
        }
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions are denied')),
            );
          }
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition();
      ref
          .read(chatRepositoryProvider)
          .sendMessage(
            widget.channelId,
            'Shared Location',
            type: 'location',
            latitude: position.latitude,
            longitude: position.longitude,
            replyToId: _replyingTo?.id,
            replyToContent: _replyingTo?.content,
            replyToSenderId: _replyingTo?.senderId,
          );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Location shared!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sharing location: $e')));
      }
    }
  }

  Future<void> _sendSnap() async {
    try {
      final imageService = ref.read(imageUploadServiceProvider);
      final imageFile = await imageService.pickImage();

      if (imageFile == null) return;

      // Show loading
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sending Snap...')));

      final result = await imageService.uploadImage(
        imageFile,
        path: 'chat_snaps/${widget.channelId}/',
      );

      await ref
          .read(chatRepositoryProvider)
          .sendMessage(
            widget.channelId,
            '📸 Snap',
            type: 'image',
            imageUrl: result.url,
            imageWidth: result.width,
            imageHeight: result.height,
            isSnap: true,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sending snap: $e')));
    }
  }

  Future<void> _handleCameraMedia(XFile file, CameraMode mode) async {
    try {
      final imageService = ref.read(imageUploadServiceProvider);
      final isSnap =
          mode == CameraMode.photo; // In chat, treat photos as snaps (optional)

      // Show loading
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mode == CameraMode.photo
                ? 'Sending Photo...'
                : 'Uploading Video...',
          ),
        ),
      );

      final result = await (mode == CameraMode.photo
          ? imageService.uploadImage(
              file,
              path: 'chat_media/${widget.channelId}/',
            )
          : imageService.uploadVideo(
              file,
              path: 'chat_media/${widget.channelId}/',
            ));

      await ref
          .read(chatRepositoryProvider)
          .sendMessage(
            widget.channelId,
            mode == CameraMode.photo ? '📷 Photo' : '🎥 Video',
            type: mode == CameraMode.photo ? 'image' : 'video',
            imageUrl: result.url,
            imageWidth: result.width,
            imageHeight: result.height,
            isSnap: isSnap,
            replyToId: _replyingTo?.id,
            replyToContent: _replyingTo?.content,
            replyToSenderId: _replyingTo?.senderId,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error uploading media: $e')));
    }
  }

  Widget _buildRichText(String text, bool isMe, bool isDark) {
    final List<TextSpan> spans = [];
    final pattern = RegExp(r"(@\w+)");
    int start = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > start) {
        spans.add(
          TextSpan(
            text: text.substring(start, match.start),
            style: TextStyle(
              color: isMe
                  ? Colors.white
                  : (isDark ? Colors.white : Colors.black87),
              fontSize: 16,
            ),
          ),
        );
      }

      spans.add(
        TextSpan(
          text: match.group(0),
          style: const TextStyle(
            color: AppColors.secondaryTeal,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      );
      start = match.end;
    }

    if (start < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(start),
          style: TextStyle(
            color: isMe
                ? Colors.white
                : (isDark ? Colors.white : Colors.black87),
            fontSize: 16,
          ),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  void _viewImage(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {
                  Share.share(url, subject: 'Image from ABUAD Nest Chat');
                },
              ),
            ],
          ),
          body: PhotoView(
            imageProvider: CachedNetworkImageProvider(url),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
          ),
        ),
      ),
    );
  }

  Future<void> _viewSnap(ChatMessage message, ChatRepository repo) async {
    if (message.imageUrl == null) return;

    // Open specialized viewer
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(
                child: CachedNetworkImage(
                  imageUrl: message.imageUrl!,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
              Positioned(
                top: 50,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'Snap will close after viewing',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // After closing, mark as read/viewed
    if (message.senderId != repo.currentUserId) {
      await repo.viewSnap(widget.channelId, message.id);
    }
  }

  Future<void> _viewSnapDirectly(
    ChatMessage message,
    ChatRepository repo,
  ) async {
    if (message.imageUrl == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  message.savedBy.contains(repo.currentUserId)
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  color: Colors.white,
                ),
                onPressed: () async {
                  await repo.toggleSaveMessage(widget.channelId, message.id);
                  Navigator.pop(
                    context,
                  ); // Refresh by closing and reopening or just pop
                },
              ),
              IconButton(
                icon: const Icon(Icons.download, color: Colors.white),
                onPressed: () => _saveImageToGallery(message.imageUrl!),
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: message.imageUrl!,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageMessage(
    ChatMessage message,
    bool isMe,
    bool isDark,
    ChatRepository repo,
  ) {
    final isReadByMe = message.readBy.contains(repo.currentUserId);
    final isSnap = message.isSnap;

    if (isSnap) {
      if (isMe) {
        // I sent the snap
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.secondaryTeal.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.secondaryTeal, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.camera_alt,
                color: AppColors.secondaryTeal,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                message.readBy.length > 1 ? 'Opened' : 'Delivered',
                style: const TextStyle(
                  color: AppColors.secondaryTeal,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      } else {
        // Someone sent me a snap
        if (isReadByMe && message.savedBy.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white12 : Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.camera_alt_outlined,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Opened',
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        } else if (message.savedBy.isNotEmpty) {
          // Saved Snap - Show image directly
          return _buildSavedSnapPreview(message, isMe, isDark, repo);
        } else {
          // New Snap!
          return GestureDetector(
            onTap: () => _viewSnap(message, repo),
            child:
                Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryTeal,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.secondaryTeal.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.camera_alt, color: Colors.white, size: 24),
                          SizedBox(width: 12),
                          Text(
                            'Tap to view Snap',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    )
                    .animate(
                      onPlay: (controller) => controller.repeat(reverse: true),
                    )
                    .shimmer(duration: 2.seconds, color: Colors.white24),
          );
        }
      }
    }

    // Regular image
    return GestureDetector(
      onTap: () => _viewImage(message.imageUrl!),
      onLongPress: () => _saveImageToGallery(message.imageUrl!),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CachedNetworkImage(
          imageUrl: message.imageUrl!,
          width: message.imageWidth != null
              ? min(message.imageWidth!.toDouble(), 250.0)
              : 250.0,
          height: message.imageHeight != null
              ? min(message.imageHeight!.toDouble(), 300.0)
              : null,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 250,
            height: 200,
            color: isDark ? Colors.black38 : Colors.grey[100],
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, url, error) => Container(
            width: 250,
            height: 200,
            color: isDark ? Colors.black38 : Colors.grey[100],
            child: const Icon(Icons.error, color: Colors.red),
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceMessageBubble(ChatMessage message, bool isMe, bool isDark) {
    final isPlaying = _currentlyPlayingUrl == message.audioUrl && _isPlaying;

    return StreamBuilder<Duration>(
      stream: _audioPlayer.onPositionChanged,
      builder: (context, snapshot) {
        final position = isPlaying
            ? (snapshot.data ?? Duration.zero)
            : Duration.zero;
        final duration = Duration(seconds: message.duration ?? 1);
        final progress = position.inMilliseconds / duration.inMilliseconds;

        return Container(
          width: 240,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMe
                ? AppColors.secondaryTeal
                : (isDark ? Colors.white.withOpacity(0.08) : Colors.white),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
            ],
          ),
          child: Row(
            children: [
              // Play/Pause Button
              GestureDetector(
                onTap: () async {
                  if (message.audioUrl == null) return;
                  if (isPlaying) {
                    await _audioPlayer.pause();
                    setState(() => _isPlaying = false);
                  } else {
                    await _audioPlayer.play(UrlSource(message.audioUrl!));
                    setState(() {
                      _currentlyPlayingUrl = message.audioUrl;
                      _isPlaying = true;
                    });
                    _audioPlayer.onPlayerComplete.listen((_) {
                      if (mounted) setState(() => _isPlaying = false);
                    });
                  }
                },
                child: Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: isMe
                        ? Colors.white.withOpacity(0.25)
                        : (isDark
                              ? AppColors.secondaryTeal
                              : AppColors.primaryInk),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Waveform with progress
                    SizedBox(
                      height: 24,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: List.generate(40, (index) {
                          final isActive = (index / 40) <= progress;
                          // Create a more dynamic, "premium" looking waveform
                          final double seed =
                              (index * 0.2) + (message.id.hashCode % 100) * 0.1;
                          final barHeight =
                              6 + (sin(seed) * 10).abs() + (index % 4);

                          return Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(
                                horizontal: 0.5,
                              ),
                              height: isPlaying ? barHeight : 6,
                              decoration: BoxDecoration(
                                color: isMe
                                    ? (isActive
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.3))
                                    : (isActive
                                          ? (isDark
                                                ? AppColors.secondaryTeal
                                                : AppColors.primaryInk)
                                          : Colors.grey[400]),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(isPlaying ? position : Duration.zero),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isMe ? Colors.white70 : Colors.grey[600],
                          ),
                        ),
                        Text(
                          '${message.duration ?? 0}s',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isMe ? Colors.white70 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  String _formatTime(DateTime time) {
    return DateFormat('HH:mm').format(time);
  }

  void _showMessageOptions(ChatMessage message, bool isMe, bool isAdmin) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final repo = ref.read(chatRepositoryProvider);
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 12,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Indicator
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              // Reactions Bar
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ['❤️', '😂', '😮', '😢', '😡', '👍'].map((emoji) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        ref
                            .read(chatRepositoryProvider)
                            .toggleReaction(
                              widget.channelId,
                              message.id,
                              emoji,
                            );
                      },
                      child: Text(emoji, style: const TextStyle(fontSize: 28)),
                    );
                  }).toList(),
                ),
              ),
              // Vertical Menu Items
              _buildMenuAction(
                icon: Icons.info_outline,
                label: 'Info',
                onTap: () {
                  Navigator.pop(context);
                  _showMessageInfo(message);
                },
              ),
              if (message.isSnap && message.imageUrl != null)
                _buildMenuAction(
                  icon: message.savedBy.contains(repo.currentUserId)
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  label: message.savedBy.contains(repo.currentUserId)
                      ? 'Keep in Chat'
                      : 'Save in Chat',
                  onTap: () {
                    Navigator.pop(context);
                    ref
                        .read(chatRepositoryProvider)
                        .toggleSaveMessage(widget.channelId, message.id);
                  },
                ),
              if (message.imageUrl != null || message.audioUrl != null)
                _buildMenuAction(
                  icon: Icons.download_rounded,
                  label: 'Save to Phone',
                  onTap: () {
                    Navigator.pop(context);
                    if (message.imageUrl != null) {
                      _saveImageToGallery(message.imageUrl!);
                    }
                  },
                ),
              _buildMenuAction(
                icon: Icons.copy_rounded,
                label: 'Copy',
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: message.content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                },
              ),
              if (message.type == 'text' && isMe)
                _buildMenuAction(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _editingMessage = message;
                      _messageController.text = message.content;
                      _replyingTo = null;
                    });
                  },
                ),
              _buildMenuAction(
                icon: Icons.push_pin_outlined,
                label: 'Pin',
                onTap: () {
                  Navigator.pop(context);
                  ref
                      .read(chatRepositoryProvider)
                      .togglePinMessage(
                        widget.channelId,
                        message.id,
                        !message.isPinned,
                      );
                },
              ),
              _buildMenuAction(
                icon: Icons.delete_outline,
                label: 'Delete',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteOptions(message, isMe, isAdmin);
                },
              ),
              _buildMenuAction(
                icon: Icons.forward_rounded,
                label: 'Forward',
                onTap: () {
                  Navigator.pop(context);
                  _showForwardSelector(message);
                },
              ),
              _buildMenuAction(
                icon: Icons.reply_rounded,
                label: 'Reply',
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _replyingTo = message);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSavedSnapPreview(
    ChatMessage message,
    bool isMe,
    bool isDark,
    ChatRepository repo,
  ) {
    return GestureDetector(
      onTap: () => _viewSnapDirectly(message, repo),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              CachedNetworkImage(
                imageUrl: message.imageUrl!,
                width: 250,
                height: 300,
                fit: BoxFit.cover,
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.6),
                      ],
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.bookmark, color: Colors.white, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'Saved in Chat',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
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
    );
  }

  Future<void> _saveImageToGallery(String url) async {
    try {
      final hasPermission = await Gal.hasAccess();
      if (!hasPermission) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Permission denied to save gallery'),
              ),
            );
          }
          return;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saving to gallery...')));
      }

      final tempDir = await getTemporaryDirectory();
      final path =
          '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      await Dio().download(url, path);
      await Gal.putImage(path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved to gallery! ✨'),
            backgroundColor: AppColors.secondaryTeal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    }
  }

  Widget _buildUploadingSnapBubble(
    String fileName,
    double progress,
    bool isDark,
  ) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.secondaryTeal.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.secondaryTeal.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_upload_outlined,
                  color: AppColors.secondaryTeal,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Sending Snap...',
                  style: TextStyle(
                    color: AppColors.secondaryTeal,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 120,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: isDark ? Colors.white10 : Colors.black12,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.secondaryTeal,
                  ),
                  minHeight: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Icon(
              icon,
              color: color ?? (isDark ? Colors.white70 : Colors.black87),
              size: 24,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: color ?? (isDark ? Colors.white : Colors.black87),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageInfo(ChatMessage message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Message Info',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Icon(Icons.done_all, color: Colors.blue, size: 20),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Read by',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        message.readBy.length <= 1
                            ? 'No one yet'
                            : '${message.readBy.length - 1} people',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.done, color: Colors.grey, size: 20),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Delivered',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _formatTime(message.timestamp),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteOptions(ChatMessage message, bool isMe, bool isAdmin) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Delete Message?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text(
                    'Delete for Everyone',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await ref
                        .read(chatRepositoryProvider)
                        .deleteMessage(
                          widget.channelId,
                          message.id,
                          forEveryone: true,
                        );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Delete for Me',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await ref
                      .read(chatRepositoryProvider)
                      .deleteMessage(
                        widget.channelId,
                        message.id,
                        forEveryone: false,
                      );
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showForwardSelector(ChatMessage message) {
    // For now, show a simplified list of recent chats
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text(
                'Forward to...',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Consumer(
                  builder: (context, ref, child) {
                    final channelsAsync = ref.watch(chatChannelsProvider);
                    return channelsAsync.when(
                      data: (channels) => ListView.builder(
                        itemCount: channels.length,
                        itemBuilder: (context, index) {
                          final channel = channels[index];
                          final isCurrent = channel.id == widget.channelId;
                          if (isCurrent) return const SizedBox();

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: channel.displayAvatarUrl != null
                                  ? CachedNetworkImageProvider(
                                      channel.displayAvatarUrl!,
                                    )
                                  : null,
                              child: channel.displayAvatarUrl == null
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            title: Text(channel.displayName ?? 'Direct Chat'),
                            trailing: const Icon(
                              Icons.send_rounded,
                              color: AppColors.secondaryTeal,
                            ),
                            onTap: () async {
                              Navigator.pop(context);
                              await ref
                                  .read(chatRepositoryProvider)
                                  .forwardMessage(channel.id, message);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Forwarded to ${channel.displayName}',
                                    ),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      ),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, s) => Center(child: Text('Error: $e')),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAttachmentMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDarkElevated : Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(
                  Icons.camera_alt,
                  Colors.pink,
                  'Snap',
                  () {
                    Navigator.pop(context);
                    _sendSnap();
                  },
                ),
                _buildAttachmentOption(
                  Icons.image,
                  Colors.purple,
                  'Gallery',
                  () {
                    Navigator.pop(context);
                    _sendImage(isSnap: false);
                  },
                ),
                _buildAttachmentOption(
                  Icons.location_on,
                  Colors.green,
                  'Location',
                  () {
                    Navigator.pop(context);
                    _sendLocation();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption(
    IconData icon,
    Color color,
    String label,
    VoidCallback onTap,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Future<void> _launchExternalMap(double latitude, double longitude) async {
    final googleMapsUrl =
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    final appleMapsUrl = 'https://maps.apple.com/?q=$latitude,$longitude';

    if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
      await launchUrl(Uri.parse(googleMapsUrl));
    } else if (await canLaunchUrl(Uri.parse(appleMapsUrl))) {
      await launchUrl(Uri.parse(appleMapsUrl));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch map application')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(chatRepositoryProvider);
    final messagesStream = repo.watchMessages(widget.channelId);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<ChatChannel?>(
      stream: repo.watchChannel(widget.channelId),
      builder: (context, channelSnapshot) {
        final channel = channelSnapshot.data;
        final isGroup = channel?.type == 'group';

        final otherUserId = isGroup
            ? null
            : channel?.memberIds.firstWhere(
                (id) => id != repo.currentUserId,
                orElse: () => 'Unknown',
              );

        final displayName = isGroup
            ? (channel?.displayName ?? 'Group Chat')
            : (channel?.memberNames[otherUserId] ?? 'Chat');

        final displayAvatar = isGroup
            ? channel?.displayAvatarUrl
            : channel?.memberAvatars[otherUserId];

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            centerTitle: false,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: isGroup
                ? _buildGroupChatTitle(
                    channel,
                    displayName,
                    displayAvatar,
                    repo,
                  )
                : _buildDirectChatTitle(
                    channel,
                    displayName,
                    displayAvatar,
                    otherUserId,
                    repo,
                  ),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: Colors.white70,
                ),
                offset: const Offset(0, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: (value) async {
                  if (value == 'info') {
                    context.push('/chat/${widget.channelId}/info');
                  } else if (value == 'settings') {
                    await context.push('/chat/${widget.channelId}/settings');
                    _loadSettings();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'info',
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 20),
                        const SizedBox(width: 12),
                        Text(isGroup ? 'Group Info' : 'User Info'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(Icons.settings_outlined, size: 20),
                        SizedBox(width: 12),
                        Text('Chat Settings'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
          extendBodyBehindAppBar: true,
          body: Stack(
            children: [
              // Premium Background
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              const Color(0xFF0F172A),
                              const Color(0xFF1E293B),
                              const Color(0xFF0F172A),
                            ]
                          : [
                              const Color(0xFFF8FAFC),
                              const Color(0xFFE2E8F0),
                              const Color(0xFFF1F5F9),
                            ],
                    ),
                  ),
                ),
              ),
              // Subtle Mesh Gradient Overlay
              Positioned.fill(
                child: Opacity(
                  opacity: 0.4,
                  child: CustomPaint(
                    painter: MeshGradientPainter(
                      color: AppColors.secondaryTeal.withOpacity(0.1),
                    ),
                  ),
                ),
              ),
              if (_wallpaperPath != null)
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.6,
                    child: Image.file(File(_wallpaperPath!), fit: BoxFit.cover),
                  ),
                ),
              Column(
                children: [
                  Expanded(
                    child: StreamBuilder<List<ChatMessage>>(
                      stream: messagesStream,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final messages = snapshot.data!;

                        // Combine real messages with uploading snaps
                        final List<dynamic> items = List.from(messages);
                        _uploadingSnaps.forEach((fileName, progress) {
                          // Add a virtual message for the uploading snap
                          items.insert(0, {
                            'fileName': fileName,
                            'progress': progress,
                            'isUploading': true,
                          });
                        });

                        if (items.isEmpty) {
                          return const Center(child: Text('Say hello! 👋'));
                        }

                        return ListView.builder(
                          reverse: true,
                          controller: _scrollController,
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];

                            if (item is Map && item['isUploading'] == true) {
                              return _buildUploadingSnapBubble(
                                item['fileName'] as String,
                                item['progress'] as double,
                                isDark,
                              );
                            }

                            final message = item as ChatMessage;
                            final isMe = message.senderId == repo.currentUserId;
                            final isRead = message.readBy.length > 1;

                            final nextMessageItem = index + 1 < items.length
                                ? items[index + 1]
                                : null;

                            final nextMessage = nextMessageItem is ChatMessage
                                ? nextMessageItem
                                : null;
                            final isNewDay =
                                nextMessage == null ||
                                message.timestamp.day !=
                                    nextMessage.timestamp.day ||
                                message.timestamp.month !=
                                    nextMessage.timestamp.month ||
                                message.timestamp.year !=
                                    nextMessage.timestamp.year;

                            final messageItem = Slidable(
                              key: Key(message.id),
                              startActionPane: ActionPane(
                                motion: const BehindMotion(),
                                extentRatio: 0.25,
                                dismissible: DismissiblePane(
                                  onDismissed: () {
                                    setState(() {
                                      _replyingTo = message;
                                    });
                                    HapticFeedback.heavyImpact();
                                  },
                                  closeOnCancel: true,
                                  confirmDismiss: () async {
                                    setState(() {
                                      _replyingTo = message;
                                    });
                                    HapticFeedback.mediumImpact();
                                    return false; // Don't actually dismiss the message
                                  },
                                ),
                                children: [
                                  CustomSlidableAction(
                                    onPressed: (context) {
                                      setState(() {
                                        _replyingTo = message;
                                      });
                                      HapticFeedback.lightImpact();
                                    },
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: AppColors.secondaryTeal,
                                    child: const Icon(
                                      Icons.reply_rounded,
                                      size: 28,
                                    ),
                                  ),
                                ],
                              ),
                              child: Align(
                                alignment: isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: GestureDetector(
                                  onLongPress: () {
                                    final isAdmin =
                                        channel?.adminIds.contains(
                                          repo.currentUserId,
                                        ) ??
                                        false;
                                    _showMessageOptions(message, isMe, isAdmin);
                                  },
                                  child: Container(
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                          0.75,
                                    ),
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: isMe
                                          ? CrossAxisAlignment.end
                                          : CrossAxisAlignment.start,
                                      children: [
                                        if (message.forwardedFrom != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 4,
                                              left: 4,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.forward_rounded,
                                                  size: 12,
                                                  color: isMe
                                                      ? Colors.white70
                                                      : Colors.grey[600],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Forwarded',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontStyle: FontStyle.italic,
                                                    color: isMe
                                                        ? Colors.white70
                                                        : Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (message.isPinned)
                                          Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 4,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _themeColor.withOpacity(
                                                0.2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.push_pin,
                                                  size: 10,
                                                  color: _themeColor,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Pinned',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark
                                                        ? Colors.white70
                                                        : AppColors.primaryInk,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (message.isDeleted)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? Colors.white10
                                                  : Colors.grey[100],
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: Colors.grey.withOpacity(
                                                  0.3,
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.block,
                                                  size: 14,
                                                  color: Colors.grey[500],
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'This message was deleted',
                                                  style: TextStyle(
                                                    fontStyle: FontStyle.italic,
                                                    color: Colors.grey[500],
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        else ...[
                                          // Reply Preview in Bubble
                                          if (message.replyToContent != null)
                                            Container(
                                              margin: const EdgeInsets.only(
                                                bottom: 4,
                                              ),
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? Colors.black26
                                                    : Colors.black.withOpacity(
                                                        0.05,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border(
                                                  left: BorderSide(
                                                    color: _themeColor,
                                                    width: 3,
                                                  ),
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    message.replyToSenderId ==
                                                            repo.currentUserId
                                                        ? 'You'
                                                        : (channel?.memberNames[message
                                                                  .replyToSenderId] ??
                                                              'User'),
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                      color: _themeColor,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    message.replyToContent!,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: isDark
                                                          ? Colors.white70
                                                          : Colors.black87,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),

                                          Row(
                                            mainAxisAlignment: isMe
                                                ? MainAxisAlignment.end
                                                : MainAxisAlignment.start,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              if (!isMe) ...[
                                                const SizedBox(width: 4),
                                              ],
                                              Flexible(
                                                child:
                                                    message.type == 'image' &&
                                                        message.imageUrl != null
                                                    ? _buildImageMessage(
                                                        message,
                                                        isMe,
                                                        isDark,
                                                        repo,
                                                      )
                                                    : message.type == 'giphy'
                                                    ? ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        child: CachedNetworkImage(
                                                          imageUrl:
                                                              message.imageUrl!,
                                                          width:
                                                              message
                                                                  .imageWidth ??
                                                              200,
                                                          height:
                                                              message
                                                                  .imageHeight ??
                                                              200,
                                                          fit: BoxFit.cover,
                                                          placeholder: (context, url) => Container(
                                                            width:
                                                                message
                                                                    .imageWidth ??
                                                                200,
                                                            height:
                                                                message
                                                                    .imageHeight ??
                                                                200,
                                                            color: isDark
                                                                ? Colors.black38
                                                                : Colors
                                                                      .grey[100],
                                                            child: const Center(
                                                              child:
                                                                  CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2,
                                                                  ),
                                                            ),
                                                          ),
                                                          errorWidget:
                                                              (
                                                                context,
                                                                url,
                                                                error,
                                                              ) => const Icon(
                                                                Icons.error,
                                                              ),
                                                        ),
                                                      )
                                                    : message.type == 'voice'
                                                    ? _buildVoiceMessageBubble(
                                                        message,
                                                        isMe,
                                                        isDark,
                                                      )
                                                    : message.type == 'location'
                                                    ? GestureDetector(
                                                        onTap: () {
                                                          // Offer to open in external maps
                                                          _launchExternalMap(
                                                            message.latitude!,
                                                            message.longitude!,
                                                          );
                                                        },
                                                        child: Container(
                                                          width: 200,
                                                          padding:
                                                              const EdgeInsets.all(
                                                                12,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: isMe
                                                                ? AppColors
                                                                      .primaryInk
                                                                : (isDark
                                                                      ? Colors
                                                                            .white10
                                                                      : Colors
                                                                            .white),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  16,
                                                                ),
                                                            border: Border.all(
                                                              color: isMe
                                                                  ? Colors
                                                                        .white24
                                                                  : Colors
                                                                        .black12,
                                                            ),
                                                          ),
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Row(
                                                                children: [
                                                                  Icon(
                                                                    Icons
                                                                        .location_on,
                                                                    color: isMe
                                                                        ? Colors
                                                                              .white
                                                                        : _themeColor,
                                                                    size: 20,
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 8,
                                                                  ),
                                                                  Text(
                                                                    'Shared Location',
                                                                    style: TextStyle(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      color:
                                                                          isMe
                                                                          ? Colors.white
                                                                          : null,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              const SizedBox(
                                                                height: 12,
                                                              ),
                                                              ClipRRect(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      8,
                                                                    ),
                                                                child: Container(
                                                                  height: 100,
                                                                  width: double
                                                                      .infinity,
                                                                  color: isDark
                                                                      ? Colors
                                                                            .black38
                                                                      : Colors
                                                                            .grey[100],
                                                                  child: Stack(
                                                                    children: [
                                                                      // Simple map preview placeholder
                                                                      Center(
                                                                        child: Icon(
                                                                          Icons
                                                                              .map,
                                                                          size:
                                                                              40,
                                                                          color:
                                                                              isDark
                                                                              ? Colors.white12
                                                                              : Colors.black12,
                                                                        ),
                                                                      ),
                                                                      Positioned(
                                                                        bottom:
                                                                            8,
                                                                        right:
                                                                            8,
                                                                        child: Container(
                                                                          padding: const EdgeInsets.symmetric(
                                                                            horizontal:
                                                                                8,
                                                                            vertical:
                                                                                4,
                                                                          ),
                                                                          decoration: BoxDecoration(
                                                                            color:
                                                                                _themeColor,
                                                                            borderRadius: BorderRadius.circular(
                                                                              12,
                                                                            ),
                                                                          ),
                                                                          child: const Text(
                                                                            'View Map',
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
                                                            ],
                                                          ),
                                                        ),
                                                      )
                                                    : GestureDetector(
                                                        onLongPress: () {
                                                          final isAdmin =
                                                              channel?.adminIds
                                                                  .contains(
                                                                    repo.currentUserId,
                                                                  ) ??
                                                              false;
                                                          _showMessageOptions(
                                                            message,
                                                            isMe,
                                                            isAdmin,
                                                          );
                                                        },
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 12,
                                                                vertical: 8,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            gradient: isMe
                                                                ? LinearGradient(
                                                                    begin: Alignment
                                                                        .topLeft,
                                                                    end: Alignment
                                                                        .bottomRight,
                                                                    colors: [
                                                                      AppColors
                                                                          .primaryInk,
                                                                      _themeColor,
                                                                    ],
                                                                  )
                                                                : null,
                                                            color: isMe
                                                                ? null
                                                                : (isDark
                                                                      ? AppColors
                                                                            .surfaceDarkElevated
                                                                      : Colors
                                                                            .white),
                                                            borderRadius: BorderRadius.only(
                                                              topLeft:
                                                                  const Radius.circular(
                                                                    16,
                                                                  ),
                                                              topRight:
                                                                  const Radius.circular(
                                                                    16,
                                                                  ),
                                                              bottomLeft:
                                                                  Radius.circular(
                                                                    isMe
                                                                        ? 16
                                                                        : 4,
                                                                  ),
                                                              bottomRight:
                                                                  Radius.circular(
                                                                    isMe
                                                                        ? 4
                                                                        : 16,
                                                                  ),
                                                            ),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: Colors
                                                                    .black
                                                                    .withOpacity(
                                                                      0.05,
                                                                    ),
                                                                blurRadius: 2,
                                                                offset:
                                                                    const Offset(
                                                                      0,
                                                                      1,
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              // Sender Name (Group & Not Me)
                                                              if (isGroup &&
                                                                  !isMe &&
                                                                  message.senderId !=
                                                                      'me')
                                                                StreamBuilder<
                                                                  AppUser?
                                                                >(
                                                                  stream: ref
                                                                      .read(
                                                                        userRepositoryProvider,
                                                                      )
                                                                      .watchUser(
                                                                        message
                                                                            .senderId,
                                                                      ),
                                                                  builder:
                                                                      (
                                                                        context,
                                                                        snapshot,
                                                                      ) {
                                                                        final user =
                                                                            snapshot.data;
                                                                        final name =
                                                                            user?.displayName ??
                                                                            channel?.memberNames[message.senderId] ??
                                                                            'Unknown';
                                                                        return Padding(
                                                                          padding: const EdgeInsets.only(
                                                                            bottom:
                                                                                4,
                                                                          ),
                                                                          child: Text(
                                                                            name,
                                                                            style: TextStyle(
                                                                              fontWeight: FontWeight.bold,
                                                                              color: _themeColor,
                                                                              fontSize: 12,
                                                                            ),
                                                                          ),
                                                                        );
                                                                      },
                                                                ),

                                                              // Shared Post Preview
                                                              if (message
                                                                      .sharedPostId !=
                                                                  null)
                                                                SharedPostPreview(
                                                                  postId: message
                                                                      .sharedPostId!,
                                                                ),

                                                              // Message Content
                                                              _buildRichText(
                                                                message.content,
                                                                isMe,
                                                                isDark,
                                                              ),

                                                              if (message
                                                                  .isEdited)
                                                                Padding(
                                                                  padding:
                                                                      const EdgeInsets.only(
                                                                        top: 2,
                                                                      ),
                                                                  child: Text(
                                                                    'edited',
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          9,
                                                                      fontStyle:
                                                                          FontStyle
                                                                              .italic,
                                                                      color:
                                                                          isMe
                                                                          ? Colors.white70
                                                                          : Colors.grey,
                                                                    ),
                                                                  ),
                                                                ),

                                                              // Timestamp
                                                              const SizedBox(
                                                                height: 4,
                                                              ),
                                                              Align(
                                                                alignment: Alignment
                                                                    .bottomRight,
                                                                child: Row(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    Text(
                                                                      _formatTime(
                                                                        message
                                                                            .timestamp,
                                                                      ),
                                                                      style: TextStyle(
                                                                        fontSize:
                                                                            10,
                                                                        color:
                                                                            isMe
                                                                            ? Colors.white70
                                                                            : (isDark
                                                                                  ? Colors.white60
                                                                                  : Colors.grey[600]),
                                                                      ),
                                                                    ),
                                                                    if (isMe) ...[
                                                                      const SizedBox(
                                                                        width:
                                                                            4,
                                                                      ),
                                                                      Icon(
                                                                        isRead
                                                                            ? Icons.done_all
                                                                            : Icons.done,
                                                                        size:
                                                                            14,
                                                                        color:
                                                                            isRead
                                                                            ? (isDark
                                                                                  ? AppColors.secondaryTeal
                                                                                  : Colors.blue)
                                                                            : (isDark
                                                                                  ? Colors.white54
                                                                                  : Colors.grey),
                                                                      ),
                                                                    ],
                                                                  ],
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                              ),
                                            ],
                                          ),
                                          // Reactions display
                                          if (message.reactions.isNotEmpty)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 4,
                                                  ),
                                              child: Wrap(
                                                spacing: 4,
                                                children: message.reactions.entries.map((
                                                  e,
                                                ) {
                                                  return Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: isDark
                                                          ? Colors.white12
                                                          : Colors.grey[200],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                      border: Border.all(
                                                        color: isDark
                                                            ? Colors.white10
                                                            : Colors.black12,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      e.value,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            ),
                                          if (isMe) ...[
                                            const SizedBox(height: 2),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                Icon(
                                                  isRead
                                                      ? Icons.done_all
                                                      : Icons.done,
                                                  size: 16,
                                                  color: isRead
                                                      ? AppColors.secondaryTeal
                                                      : Colors.grey,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );

                            if (isNewDay) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildDateSeparator(message.timestamp),
                                  messageItem,
                                ],
                              );
                            }

                            return messageItem;
                          },
                        );
                      },
                    ),
                  ),

                  // Reply Banner
                  // Mention Suggestions Overlay
                  if (_userSuggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surfaceDarkElevated
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _userSuggestions.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            color: isDark ? Colors.white10 : Colors.grey[200],
                          ),
                          itemBuilder: (context, index) {
                            final user = _userSuggestions[index];
                            return ListTile(
                              leading: user.uid == 'all'
                                  ? CircleAvatar(
                                      backgroundColor: AppColors.secondaryTeal
                                          .withOpacity(0.1),
                                      child: const Icon(
                                        Icons.groups,
                                        color: AppColors.secondaryTeal,
                                        size: 20,
                                      ),
                                    )
                                  : CircleAvatar(
                                      backgroundImage: user.avatarUrl != null
                                          ? NetworkImage(user.avatarUrl!)
                                          : null,
                                      child: user.avatarUrl == null
                                          ? Text(user.displayName[0])
                                          : null,
                                    ),
                              title: Text(user.displayName),
                              subtitle: Text("@${user.handle}"),
                              dense: true,
                              onTap: () => _applyMention(user),
                            );
                          },
                        ),
                      ),
                    ),

                  // Input Area
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.surfaceDarkElevated
                          : Colors.white,
                      border: Border(
                        top: BorderSide(
                          color: isDark
                              ? Colors.white10
                              : Colors.black.withOpacity(0.05),
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_replyingTo != null) _buildReplyPreview(isDark),
                          _isRecording
                              ? Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: _isLocked
                                      ? _buildLockedUI()
                                      : _buildRecordingUI(isDark),
                                )
                              : Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      _buildEmojiToggle(isDark),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? Colors.white.withOpacity(0.05)
                                                : Colors.grey[100],
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                            border: Border.all(
                                              color: isDark
                                                  ? Colors.white10
                                                  : Colors.black.withOpacity(
                                                      0.05,
                                                    ),
                                            ),
                                          ),
                                          child: TextField(
                                            controller: _messageController,
                                            onChanged: _onTextChanged,
                                            maxLines: 5,
                                            minLines: 1,
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                            decoration: InputDecoration(
                                              hintText: "Message",
                                              hintStyle: TextStyle(
                                                color: isDark
                                                    ? Colors.white38
                                                    : Colors.grey[500],
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 10,
                                                  ),
                                              border: InputBorder.none,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      _buildActionButtons(isDark),
                                    ],
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                  if (_showEmojiPicker) _buildEmojiStickerPicker(isDark),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReplyPreview(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: AppColors.secondaryTeal, width: 4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Replying to",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondaryTeal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _replyingTo!.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _replyingTo = null),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiToggle(bool isDark) {
    return IconButton(
      icon: Icon(
        _showEmojiPicker
            ? Icons.keyboard_rounded
            : Icons.sentiment_satisfied_alt_rounded,
        color: isDark ? Colors.white70 : Colors.grey[700],
      ),
      onPressed: () {
        setState(() {
          _showEmojiPicker = !_showEmojiPicker;
          if (_showEmojiPicker) {
            FocusScope.of(context).unfocus();
          }
        });
      },
    );
  }

  // TextField build integrated directly.

  Widget _buildActionButtons(bool isDark) {
    if (_hasText) {
      return GestureDetector(
        onTap: _sendMessage,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.secondaryTeal,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.secondaryTeal.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            Icons.attach_file_rounded,
            color: isDark ? Colors.white70 : Colors.grey[700],
          ),
          onPressed: _showAttachmentMenu,
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        IconButton(
          icon: Icon(
            Icons.camera_alt_rounded,
            color: isDark ? Colors.white70 : Colors.grey[700],
          ),
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CameraScreen(isForStory: false),
              ),
            );
            if (result != null && result is Map) {
              _handleCameraMedia(
                result['file'] as XFile,
                result['mode'] as CameraMode,
              );
            }
          },
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        // Mic Button Placeholder/Trigger
        GestureDetector(
          onLongPressStart: (_) => _startRecording(),
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Icon(
              Icons.mic_rounded,
              color: isDark ? Colors.white70 : Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmojiStickerPicker(bool isDark) {
    return DefaultTabController(
      length: 2,
      child: Container(
        height: 300,
        color: isDark ? AppColors.surfaceDarkElevated : Colors.white,
        child: Column(
          children: [
            TabBar(
              tabs: const [
                Tab(icon: Icon(Icons.sentiment_satisfied_rounded)),
                Tab(icon: Icon(Icons.sticky_note_2_rounded)),
              ],
              labelColor: AppColors.secondaryTeal,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppColors.secondaryTeal,
            ),
            Expanded(
              child: TabBarView(
                children: [_buildEmojiGrid(isDark), _buildStickerGrid(isDark)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmojiGrid(bool isDark) {
    final emojis = [
      '😀',
      '😃',
      '😄',
      '😁',
      '😆',
      '😅',
      '😂',
      '🤣',
      '😊',
      '😇',
      '🙂',
      '🙃',
      '😉',
      '😌',
      '😍',
      '🥰',
      '😘',
      '😗',
      '😙',
      '😚',
      '😋',
      '😛',
      '😝',
      '😜',
      '🤪',
      '🤨',
      '🧐',
      '🤓',
      '😎',
      '🤩',
      '🥳',
      '😏',
      '😒',
      '😞',
      '😔',
      '😟',
      '😕',
      '🙁',
      '😣',
      '😖',
      '😫',
      '😩',
      '🥺',
      '😢',
      '😭',
      '😤',
      '😠',
      '😡',
      '🤬',
      '🤯',
      '😳',
      '🥵',
      '🥶',
      '😱',
      '😨',
      '😰',
      '😥',
      '😓',
      '🤗',
      '🤔',
      '🤭',
      '🤫',
      '🤥',
      '😶',
      '😐',
      '😑',
      '😬',
      '🙄',
      '😯',
      '😦',
      '😧',
      '😮',
      '😲',
      '🥱',
      '😴',
      '🤤',
      '😪',
      '😵',
      '🤐',
      '🥴',
      '🤢',
      '🤮',
      '🤧',
      '🤨',
      '🤫',
      '🤥',
      '🤡',
      '💩',
      '👻',
      '💀',
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: emojis.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            _messageController.text += emojis[index];
          },
          child: Center(
            child: Text(emojis[index], style: const TextStyle(fontSize: 24)),
          ),
        );
      },
    );
  }

  Widget _buildStickerGrid(bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  "Recent Stickers",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _showStickerCreatorComingSoon,
                icon: const Icon(Icons.add, size: 16),
                label: const Text("Create"),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.secondaryTeal,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.sticky_note_2_outlined,
                  size: 48,
                  color: isDark ? Colors.white24 : Colors.grey[300],
                ),
                const SizedBox(height: 12),
                Text(
                  "No stickers yet",
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    String text;
    if (messageDate == today) {
      text = 'Today';
    } else if (messageDate == yesterday) {
      text = 'Yesterday';
    } else {
      text = DateFormat('MMMM d, y').format(date);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          const Expanded(child: Divider(indent: 40, endIndent: 10)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          const Expanded(child: Divider(indent: 10, endIndent: 40)),
        ],
      ),
    );
  }

  void _showStickerCreatorComingSoon() {
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Sticker creator is coming soon!',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? Colors.grey[900] : Colors.grey[100],
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildGroupChatTitle(
    ChatChannel? channel,
    String displayName,
    String? displayAvatar,
    ChatRepository repo,
  ) {
    return Row(
      children: [
        UserAvatar(
          userId: channel?.id ?? '',
          avatarUrl: displayAvatar,
          displayName: displayName,
          radius: 18,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
              _buildTypingIndicator(repo, channel, isGroup: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDirectChatTitle(
    ChatChannel? channel,
    String displayName,
    String? displayAvatar,
    String? otherUserId,
    ChatRepository repo,
  ) {
    return StreamBuilder<AppUser?>(
      stream: otherUserId != null && otherUserId != 'Unknown'
          ? ref.read(userRepositoryProvider).watchUser(otherUserId)
          : const Stream.empty(),
      builder: (context, userSnapshot) {
        final user = userSnapshot.data;
        final name = user?.displayName ?? displayName;
        final avatar = user?.avatarUrl ?? displayAvatar;
        final verification = user?.verificationType ?? 'none';

        return Row(
          children: [
            UserAvatar(
              userId: otherUserId ?? '',
              avatarUrl: avatar,
              displayName: name,
              radius: 18,
              showStoryRing: true,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      VerificationBadge(type: verification, size: 14),
                    ],
                  ),
                  _buildTypingIndicator(repo, channel, isGroup: false),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTypingIndicator(
    ChatRepository repo,
    ChatChannel? channel, {
    required bool isGroup,
  }) {
    return StreamBuilder<Map<String, bool>>(
      stream: repo.watchTypingStatus(widget.channelId),
      builder: (context, snapshot) {
        final typingMap = snapshot.data ?? {};
        final typingUserIds = typingMap.entries
            .where((e) => e.value && e.key != repo.currentUserId)
            .map((e) => e.key)
            .toList();

        if (typingUserIds.isEmpty) {
          if (!isGroup && channel != null && channel.streakCount > 0) {
            return Row(
              children: [
                const Text("🔥", style: TextStyle(fontSize: 10)),
                const SizedBox(width: 4),
                Text(
                  "${channel.streakCount}",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            );
          }
          return Text(
            isGroup ? 'Group' : 'Active now',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 11,
            ),
          );
        }

        String typingText;
        if (isGroup) {
          final names = typingUserIds
              .map((id) => channel?.memberNames[id] ?? 'Someone')
              .toList();
          typingText = names.length == 1
              ? '${names[0]} is typing...'
              : '${names.length} people typing...';
        } else {
          typingText = 'typing...';
        }

        return Text(
          typingText,
          style: const TextStyle(
            color: AppColors.secondaryTeal,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        );
      },
    );
  }
}

class ChatBackgroundPainter extends CustomPainter {
  final Color color;
  ChatBackgroundPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final random = Random(42);

    for (var i = 0; i < 40; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final shapeType = random.nextInt(3);

      if (shapeType == 0) {
        canvas.drawCircle(Offset(x, y), 8 + random.nextDouble() * 10, paint);
      } else if (shapeType == 1) {
        final path = Path();
        path.moveTo(x, y);
        path.lineTo(x + 15, y + 25);
        path.lineTo(x - 15, y + 25);
        path.close();
        canvas.drawPath(path, paint);
      } else {
        final path = Path();
        path.moveTo(x, y);
        path.quadraticBezierTo(x + 10, y - 10, x + 20, y);
        path.quadraticBezierTo(x + 30, y + 10, x + 40, y);
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MeshGradientPainter extends CustomPainter {
  final Color color;
  MeshGradientPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50);

    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.2), 150, paint);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.8), 200, paint);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.5), 100, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
