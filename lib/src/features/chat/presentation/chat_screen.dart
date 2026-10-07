import 'dart:convert';
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
import '../../../core/services/media_saver.dart';

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
  bool _showAttachmentDrawer = false;
  bool _hideAnnouncement = false;
  bool _hasText = false;

  // Recording & Giphy state
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isLocked = false;
  DateTime? _recordingStartTime;
  Timer? _recordingTimer;
  double _dragOffset = 0.0;
  double _horizontalDragOffset = 0.0;

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

  double _wallpaperDim = 0.3;

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        final channelWallpaper = prefs.getString('chat_wallpaper_${widget.channelId}');
        _wallpaperPath = (channelWallpaper != null && channelWallpaper.isNotEmpty)
            ? channelWallpaper
            : prefs.getString('global_chat_wallpaper');
        final themeName = prefs.getString('chat_theme_${widget.channelId}') ??
            prefs.getString('global_chat_theme') ??
            'Teal';
        _themeColor = _getThemeColor(themeName);
        _wallpaperDim = prefs.getDouble('chat_wallpaper_dim') ?? 0.3;
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Color _getThemeColor(String name) {
    switch (name) {
      case 'Blue':
        return const Color(0xFF3B82F6);
      case 'Purple':
        return const Color(0xFF8B5CF6);
      case 'Gold':
        return const Color(0xFFF59E0B);
      case 'Rose':
        return const Color(0xFFEC4899);
      case 'Emerald':
        return const Color(0xFF10B981);
      default:
        return AppColors.secondaryTeal;
    }
  }

  Widget _buildWallpaperWidget() {
    if (_wallpaperPath == null) return const SizedBox.shrink();
    if (_wallpaperPath!.startsWith('preset_')) {
      final presets = {
        'preset_obsidian': const [Color(0xFF050505), Color(0xFF1A1A24)],
        'preset_aurora': const [Color(0xFF1E1B4B), Color(0xFF4C1D95)],
        'preset_teal': const [Color(0xFF064E3B), Color(0xFF022C22)],
        'preset_sunset': const [Color(0xFF4C0519), Color(0xFF831843)],
        'preset_emerald': const [Color(0xFF022C22), Color(0xFF065F46)],
      };
      final colors = presets[_wallpaperPath] ?? const [Color(0xFF0F172A), Color(0xFF1E293B)];
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );
    }

    if (File(_wallpaperPath!).existsSync()) {
      return Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: FileImage(File(_wallpaperPath!)),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: _wallpaperDim),
              BlendMode.darken,
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
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
          _horizontalDragOffset = 0.0;
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
        _horizontalDragOffset = 0.0;
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
        _dragOffset = 0.0;
        _horizontalDragOffset = 0.0;
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
              Expanded(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: (_dragOffset < -10 || _horizontalDragOffset < -20)
                      ? 0.0
                      : 1.0,
                  child: const Text(
                    '< Slide to cancel',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Mic Button with Lock Animation
        GestureDetector(
          onLongPressMoveUpdate: (details) {
            // dy is negative when dragging up
            final dragY = details.localPosition.dy;
            final dragX = details.localPosition.dx;

            // Drag Up to Lock
            if (dragY < -60) {
              _lockRecording();
            } else {
              setState(() {
                _dragOffset = dragY.clamp(-60.0, 20.0);
                _horizontalDragOffset = dragX;
              });
            }

            // Drag Left to Cancel threshold
            if (dragX < -150) {
              _cancelRecording();
            }
          },
          onLongPressEnd: (details) {
            if (_isLocked) return;
            _stopRecording(send: true);
          },
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Static Lock Icon that changes as you drag near it
              Positioned(
                top: -80,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 100),
                  opacity: _dragOffset < -20 ? 1.0 : 0.3,
                  child: Column(
                    children: [
                      Icon(
                        _dragOffset < -50 ? Icons.lock : Icons.lock_open,
                        color: _dragOffset < -50
                            ? AppColors.secondaryTeal
                            : Colors.grey,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Icon(
                            Icons.keyboard_arrow_up,
                            color: Colors.grey,
                            size: 16,
                          )
                          .animate(onPlay: (controller) => controller.repeat())
                          .moveY(
                            begin: 0,
                            end: -5,
                            duration: 600.ms,
                            curve: Curves.easeInOut,
                          ),
                    ],
                  ),
                ),
              ),

              // Mic Button (Moves with finger)
              Transform.translate(
                offset: Offset(0, _dragOffset),
                child:
                    Transform.scale(
                          scale: 1.3,
                          child: Container(
                            height: 50,
                            width: 50,
                            decoration: BoxDecoration(
                              color: AppColors.secondaryTeal,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.secondaryTeal.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.mic,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        )
                        .animate(onPlay: (controller) => controller.repeat())
                        .shimmer(duration: 2.seconds, color: Colors.white24),
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
                  Share.share(url, subject: 'Image from Abuad life Chat');
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
            color: AppColors.secondaryTeal.withValues(alpha: 0.15),
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
                            color: AppColors.secondaryTeal.withValues(
                              alpha: 0.3,
                            ),
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
          width: 250,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMe
                ? const Color(0xFF4F46E5)
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isMe ? 20 : 6),
              bottomRight: Radius.circular(isMe ? 6 : 20),
            ),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
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
                  height: 36,
                  width: 36,
                  decoration: BoxDecoration(
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.25)
                        : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: isMe ? Colors.white : (isDark ? Colors.white : const Color(0xFF334155)),
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          _formatDuration(isPlaying ? position : Duration(seconds: message.duration ?? 14)),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isMe ? Colors.white : (isDark ? Colors.white : const Color(0xFF0F172A)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Waveform with progress
                        Expanded(
                          child: SizedBox(
                            height: 18,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: List.generate(24, (index) {
                                final isActive = (index / 24) <= progress;
                                final double seed = (index * 0.3) + (message.id.hashCode % 50) * 0.1;
                                final barHeight = 4.0 + (sin(seed) * 8).abs() + (index % 3) * 2;

                                return Expanded(
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 0.7),
                                    height: barHeight,
                                    decoration: BoxDecoration(
                                      color: isMe
                                          ? (isActive ? Colors.white : Colors.white.withValues(alpha: 0.35))
                                          : (isActive
                                              ? const Color(0xFF4F46E5)
                                              : (isDark ? Colors.white24 : const Color(0xFFCBD5E1))),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe ? Colors.white70 : (isDark ? Colors.white54 : Colors.grey[500]),
                        ),
                      ),
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
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 12,
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
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: ['❤️', '😂', '😮', '😢', '😡', '👍'].map((
                        emoji,
                      ) {
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
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 28),
                          ),
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
            ),
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
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
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
                        Colors.black.withValues(alpha: 0.6),
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saving image...')),
      );
    }
    final success = await MediaSaver.saveImage(url);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Saved to gallery! ✨' : 'Could not save image'),
        backgroundColor: success ? AppColors.secondaryTeal : Colors.red,
      ),
    );
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
          color: AppColors.secondaryTeal.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.secondaryTeal.withValues(alpha: 0.3),
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
          child: SafeArea(
            top: false,
            child: Padding(
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
            ),
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
          child: SafeArea(
            top: false,
            child: Padding(
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
                      leading: const Icon(
                        Icons.delete_forever,
                        color: Colors.red,
                      ),
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
                    leading: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                    ),
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
            ),
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
          child: SafeArea(
            top: false,
            child: Padding(
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
                                  backgroundImage:
                                      channel.displayAvatarUrl != null
                                      ? CachedNetworkImageProvider(
                                          channel.displayAvatarUrl!,
                                        )
                                      : null,
                                  child: channel.displayAvatarUrl == null
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                title: Text(
                                  channel.displayName ?? 'Direct Chat',
                                ),
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
            ),
          ),
        );
      },
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
              color: color.withValues(alpha: 0.1),
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
        final isGroup = channel?.type == 'group' || widget.channelId.startsWith('group_');

        String? otherUserId = isGroup
            ? null
            : channel?.memberIds.firstWhere(
                (id) => id != repo.currentUserId,
                orElse: () => '',
              );

        if (!isGroup && (otherUserId == null || otherUserId.isEmpty)) {
          if (widget.channelId.startsWith('channel_')) {
            otherUserId = widget.channelId.substring(8);
          } else {
            otherUserId = widget.channelId;
          }
        }

        final displayName = isGroup
            ? (channel?.displayName ?? 'Group Chat')
            : (channel?.memberNames[otherUserId] ?? 'Chat');

        final displayAvatar = isGroup
            ? channel?.displayAvatarUrl
            : channel?.memberAvatars[otherUserId];

        final isAiChat = !isGroup && (
          displayName.toLowerCase().contains('abuad ai') ||
          displayName.toLowerCase().contains('ai bot') ||
          displayName.toLowerCase() == 'ai' ||
          (otherUserId != null && (otherUserId.toLowerCase().contains('ai') || otherUserId == 'abuad_ai')) ||
          (channel?.memberNames.values.any((name) => name.toLowerCase().contains('abuad ai')) ?? false)
        );

        final headerTextColor = isAiChat
            ? Colors.white
            : (isDark ? Colors.white : AppColors.primaryInk);

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            centerTitle: false,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: headerTextColor,
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
                    isDark,
                  )
                : _buildDirectChatTitle(
                    channel,
                    displayName,
                    displayAvatar,
                    otherUserId,
                    repo,
                    isDark,
                  ),
            actions: [
              IconButton(
                icon: Icon(
                  Icons.videocam_outlined,
                  color: headerTextColor.withValues(alpha: 0.9),
                  size: 24,
                ),
                onPressed: () => _startCall(
                  isVideo: true,
                  name: displayName,
                  avatar: displayAvatar,
                ),
              ),
              if (isGroup)
                IconButton(
                  icon: Icon(
                    Icons.search_rounded,
                    color: headerTextColor.withValues(alpha: 0.9),
                    size: 23,
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Search in conversation...')),
                    );
                  },
                )
              else
                IconButton(
                  icon: Icon(
                    Icons.phone_outlined,
                    color: headerTextColor.withValues(alpha: 0.9),
                    size: 21,
                  ),
                  onPressed: () => _startCall(
                    isVideo: false,
                    name: displayName,
                    avatar: displayAvatar,
                  ),
                ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_horiz_rounded,
                  color: headerTextColor.withValues(alpha: 0.9),
                  size: 24,
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
              const SizedBox(width: 4),
            ],
          ),
          extendBodyBehindAppBar: true,
          body: Stack(
            children: [
              // Premium Background
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: isAiChat
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF030712), // Deep Obsidian Void
                              Color(0xFF0B132B), // Cosmic Midnight
                              Color(0xFF062C22), // Glowing Cyber Teal Hue
                              Color(0xFF080D1A),
                            ],
                            stops: [0.0, 0.35, 0.75, 1.0],
                          )
                        : LinearGradient(
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
              if (isAiChat) ...[
                // Glowing Cyber Radial Ambient Orbs
                Positioned(
                  top: -80,
                  right: -60,
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.secondaryTeal.withValues(alpha: 0.28),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 140,
                  left: -80,
                  child: Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF8B5CF6).withValues(alpha: 0.22), // Cyber Violet glow
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              // Subtle Mesh Gradient Overlay
              Positioned.fill(
                child: Opacity(
                  opacity: isAiChat ? 0.6 : 0.4,
                  child: CustomPaint(
                    painter: MeshGradientPainter(
                      color: (isAiChat ? const Color(0xFF14B8A6) : AppColors.secondaryTeal)
                          .withValues(alpha: isAiChat ? 0.18 : 0.1),
                    ),
                  ),
                ),
              ),
              if (_wallpaperPath != null)
                Positioned.fill(
                  child: _buildWallpaperWidget(),
                ),
              Column(
                children: [
                  if (isGroup) _buildAnnouncementBanner(channel, isDark),
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
                          if (isAiChat) {
                            return Center(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF14B8A6),
                                            Color(0xFF8B5CF6),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF14B8A6).withValues(alpha: 0.4),
                                            blurRadius: 20,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.auto_awesome,
                                        color: Colors.white,
                                        size: 38,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    const Text(
                                      "ABUAD AI Companion",
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "Send a message to chat! Ask about lectures, exams, campus life, or just text naturally.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[400],
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        _buildAiPromptChip("✨ Hi ABUAD AI! How are you?"),
                                        _buildAiPromptChip("📚 Campus study spots?"),
                                        _buildAiPromptChip("🎨 Generate a cool campus artwork"),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
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
                                              color: _themeColor.withValues(
                                                alpha: 0.2,
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
                                                color: Colors.grey.withValues(
                                                  alpha: 0.3,
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
                                                    : Colors.black.withValues(
                                                        alpha: 0.05,
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
                                              if (!isMe && isGroup) ...[
                                                Padding(
                                                  padding: const EdgeInsets.only(right: 8, bottom: 2),
                                                  child: UserAvatar(
                                                    userId: message.senderId,
                                                    avatarUrl: channel?.memberAvatars[message.senderId],
                                                    displayName: channel?.memberNames[message.senderId] ?? 'User',
                                                    radius: 16,
                                                  ),
                                                ),
                                              ] else if (!isMe) ...[
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
                                                    : (message.type == 'document' || message.content.startsWith('📄 Document:'))
                                                    ? _buildDocumentCard(message, isMe, isDark)
                                                    : (message.type == 'poll' || message.content.startsWith('{"question"'))
                                                    ? _buildPollCard(message, isMe, isDark)
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
                                                                ? const LinearGradient(
                                                                    begin: Alignment.topLeft,
                                                                    end: Alignment.bottomRight,
                                                                    colors: [
                                                                      Color(0xFF4F46E5),
                                                                      Color(0xFF6366F1),
                                                                    ],
                                                                  )
                                                                : null,
                                                            color: isMe
                                                                ? null
                                                                : (isDark
                                                                      ? const Color(0xFF1E293B)
                                                                      : const Color(0xFFF1F5F9)),
                                                            borderRadius: BorderRadius.only(
                                                              topLeft: const Radius.circular(20),
                                                              topRight: const Radius.circular(20),
                                                              bottomLeft: Radius.circular(isMe ? 20 : 4),
                                                              bottomRight: Radius.circular(isMe ? 4 : 20),
                                                            ),
                                                            boxShadow: [
                                                              if (!isDark)
                                                                BoxShadow(
                                                                  color: Colors.black.withValues(alpha: 0.04),
                                                                  blurRadius: 4,
                                                                  offset: const Offset(0, 2),
                                                                ),
                                                            ],
                                                          ),
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment.start,
                                                            mainAxisSize:
                                                                MainAxisSize.min,
                                                            children: [
                                                              // Sender Name & Role Badge (Group & Not Me)
                                                              if (isGroup && !isMe && message.senderId != 'me')
                                                                StreamBuilder<AppUser?>(
                                                                  stream: ref
                                                                      .read(userRepositoryProvider)
                                                                      .watchUser(message.senderId),
                                                                  builder: (context, snapshot) {
                                                                    final user = snapshot.data;
                                                                    final name = user?.displayName ??
                                                                        channel?.memberNames[message.senderId] ??
                                                                        'Member';
                                                                    final isAdmin = channel?.adminIds.contains(message.senderId) ?? false;
                                                                    final isRep = name.toLowerCase().contains('rep') || name.toLowerCase().contains('liam');

                                                                    return Padding(
                                                                      padding: const EdgeInsets.only(bottom: 6),
                                                                      child: Row(
                                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                        children: [
                                                                          Row(
                                                                            mainAxisSize: MainAxisSize.min,
                                                                            children: [
                                                                              Text(
                                                                                name,
                                                                                style: TextStyle(
                                                                                  fontWeight: FontWeight.bold,
                                                                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                                                  fontSize: 13,
                                                                                ),
                                                                              ),
                                                                              if (isAdmin || isRep) ...[
                                                                                const SizedBox(width: 6),
                                                                                Container(
                                                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                                                  decoration: BoxDecoration(
                                                                                    color: const Color(0xFFE2E8F0),
                                                                                    borderRadius: BorderRadius.circular(6),
                                                                                  ),
                                                                                  child: Text(
                                                                                    isRep ? 'Class Rep' : 'Admin',
                                                                                    style: const TextStyle(
                                                                                      fontSize: 10,
                                                                                      fontWeight: FontWeight.w600,
                                                                                      color: Color(0xFF475569),
                                                                                    ),
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            ],
                                                                          ),
                                                                          Text(
                                                                            DateFormat('h:mm a').format(message.timestamp),
                                                                            style: TextStyle(
                                                                              fontSize: 11,
                                                                              color: isDark ? Colors.white38 : Colors.grey[400],
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    );
                                                                  },
                                                                ),

                                                              // Shared Post Preview
                                                              if (message.sharedPostId != null)
                                                                SharedPostPreview(
                                                                  postId: message.sharedPostId!,
                                                                ),

                                                              // Message Content
                                                              _buildRichText(
                                                                message.content,
                                                                isMe,
                                                                isDark,
                                                              ),

                                                              if (message.isEdited)
                                                                Padding(
                                                                  padding: const EdgeInsets.only(top: 2),
                                                                  child: Text(
                                                                    'edited',
                                                                    style: TextStyle(
                                                                      fontSize: 9,
                                                                      fontStyle: FontStyle.italic,
                                                                      color: isMe ? Colors.white70 : Colors.grey,
                                                                    ),
                                                                  ),
                                                                ),

                                                              // Timestamp & Read Receipts
                                                              const SizedBox(height: 4),
                                                              Align(
                                                                alignment: Alignment.bottomRight,
                                                                child: Row(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: [
                                                                    Text(
                                                                      _formatTime(message.timestamp),
                                                                      style: TextStyle(
                                                                        fontSize: 10,
                                                                        color: isMe
                                                                            ? Colors.white70
                                                                            : (isDark
                                                                                ? Colors.white54
                                                                                : Colors.grey[500]),
                                                                      ),
                                                                    ),
                                                                    if (isMe) ...[
                                                                      const SizedBox(width: 4),
                                                                      if (isRead)
                                                                        const Text(
                                                                          'Read ',
                                                                          style: TextStyle(
                                                                            fontSize: 10,
                                                                            color: Colors.white70,
                                                                          ),
                                                                        ),
                                                                      Icon(
                                                                        isRead
                                                                            ? Icons.done_all_rounded
                                                                            : Icons.done_rounded,
                                                                        size: 14,
                                                                        color: Colors.white,
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
                                              padding: const EdgeInsets.only(top: 2, right: 4),
                                              child: Row(
                                                mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 3,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: isDark
                                                          ? const Color(0xFF0F172A)
                                                          : Colors.white,
                                                      borderRadius: BorderRadius.circular(14),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black.withValues(alpha: 0.1),
                                                          blurRadius: 6,
                                                          offset: const Offset(0, 2),
                                                        ),
                                                      ],
                                                      border: Border.all(
                                                        color: isDark
                                                            ? Colors.white12
                                                            : const Color(0xFFE2E8F0),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: message.reactions.values.toSet().map((emoji) {
                                                        return Padding(
                                                          padding: const EdgeInsets.symmetric(horizontal: 2),
                                                          child: Text(
                                                            emoji,
                                                            style: const TextStyle(fontSize: 13),
                                                          ),
                                                        );
                                                      }).toList(),
                                                    ),
                                                  ),
                                                ],
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
                            color: Colors.black.withValues(alpha: 0.1),
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
                                          .withValues(alpha: 0.1),
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
                              : Colors.black.withValues(alpha: 0.05),
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
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
                          _buildLiveTypingBanner(channel, displayName, isDark),
                          if (_replyingTo != null) _buildReplyPreview(isDark),
                          if (_showAttachmentDrawer) _buildAttachmentDrawer(isDark),
                          _isRecording
                              ? Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: _isLocked
                                      ? _buildLockedUI()
                                      : _buildRecordingUI(isDark),
                                )
                              : Padding(
                                  padding: EdgeInsets.only(
                                    left: 12,
                                    right: 12,
                                    top: 6,
                                    bottom: max(MediaQuery.of(context).padding.bottom > 0 ? 8 : 12, 12),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // Plus Attachment Button on Left
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _showAttachmentDrawer = !_showAttachmentDrawer;
                                            if (_showAttachmentDrawer) {
                                              _showEmojiPicker = false;
                                              FocusScope.of(context).unfocus();
                                            }
                                          });
                                        },
                                        child: Container(
                                          height: 42,
                                          width: 42,
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? Colors.white.withValues(alpha: 0.08)
                                                : const Color(0xFFF1F5F9),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            _showAttachmentDrawer ? Icons.close_rounded : Icons.add_rounded,
                                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Message Pill Input
                                      Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? Colors.white.withValues(alpha: 0.06)
                                                : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(24),
                                            border: Border.all(
                                              color: isDark
                                                  ? Colors.white10
                                                  : Colors.black.withValues(alpha: 0.04),
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 14),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: TextField(
                                                  controller: _messageController,
                                                  onChanged: _onTextChanged,
                                                  maxLines: 4,
                                                  minLines: 1,
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                  ),
                                                  decoration: InputDecoration(
                                                    hintText: isGroup ? "Message $displayName..." : "Message...",
                                                    hintStyle: TextStyle(
                                                      color: isDark ? Colors.white38 : Colors.grey[400],
                                                      fontSize: 15,
                                                    ),
                                                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                                    border: InputBorder.none,
                                                    isDense: true,
                                                  ),
                                                ),
                                              ),
                                              _buildEmojiToggle(isDark),
                                              _buildCameraButton(isDark),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildMainActionButton(isDark),
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
      margin: const EdgeInsets.only(bottom: 8, left: 12, right: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: Color(0xFF6366F1), width: 4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Replying to",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6366F1),
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
    return GestureDetector(
      onTap: () {
        setState(() {
          _showEmojiPicker = !_showEmojiPicker;
          if (_showEmojiPicker) {
            _showAttachmentDrawer = false;
            FocusScope.of(context).unfocus();
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Icon(
          _showEmojiPicker ? Icons.keyboard_rounded : Icons.sentiment_satisfied_alt_rounded,
          color: isDark ? Colors.white54 : Colors.grey[500],
          size: 22,
        ),
      ),
    );
  }

  Widget _buildCameraButton(bool isDark) {
    return GestureDetector(
      onTap: () async {
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Icon(
          Icons.camera_alt_outlined,
          color: isDark ? Colors.white54 : Colors.grey[500],
          size: 22,
        ),
      ),
    );
  }

  Widget _buildMainActionButton(bool isDark) {
    return GestureDetector(
      onTap: _hasText ? _sendMessage : null,
      onLongPressStart: !_hasText
          ? (_) {
              HapticFeedback.heavyImpact();
              _startRecording();
            }
          : null,
      onLongPressEnd: !_hasText ? (_) => _stopRecording(send: !_isLocked) : null,
      child: Container(
        height: 42,
        width: 42,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            _hasText ? Icons.send_rounded : Icons.near_me_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
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
              color: Colors.black.withValues(alpha: 0.05),
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

    Widget _buildGroupAvatarCluster(ChatChannel? channel, String? displayAvatar, String displayName) {
    if (displayAvatar != null && displayAvatar.isNotEmpty) {
      return UserAvatar(
        userId: channel?.id ?? '',
        avatarUrl: displayAvatar,
        displayName: displayName,
        radius: 19,
      );
    }

    final avatars = (channel?.memberAvatars.values.where((a) => a != null && a.isNotEmpty).cast<String>().toList() ?? []);
    if (avatars.length >= 3) {
      return SizedBox(
        width: 38,
        height: 38,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              child: CircleAvatar(
                radius: 11,
                backgroundImage: NetworkImage(avatars[0]),
                backgroundColor: const Color(0xFF6366F1),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: CircleAvatar(
                radius: 11,
                backgroundImage: NetworkImage(avatars[1]),
                backgroundColor: const Color(0xFF10B981),
              ),
            ),
            Positioned(
              left: 8,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: CircleAvatar(
                  radius: 11,
                  backgroundImage: NetworkImage(avatars[2]),
                  backgroundColor: const Color(0xFFF59E0B),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'G',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildAnnouncementBanner(ChatChannel? channel, bool isDark) {
    if (_hideAnnouncement) return const SizedBox.shrink();
    const text = "Midterm on Friday, Room 402 @ 10 AM — Liam (Class Rep)";

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFBFDBFE),
        ),
      ),
      child: Row(
        children: [
          const Text('📌', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : const Color(0xFF1E3A8A),
                  height: 1.3,
                ),
                children: [
                  const TextSpan(
                    text: 'ANNOUNCEMENT: ',
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.2),
                  ),
                  TextSpan(text: text),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() => _hideAnnouncement = true),
            child: Icon(
              Icons.close_rounded,
              size: 16,
              color: isDark ? Colors.white54 : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupChatTitle(
    ChatChannel? channel,
    String displayName,
    String? displayAvatar,
    ChatRepository repo,
    bool isDark,
  ) {
    final titleColor = isDark ? Colors.white : AppColors.primaryInk;
    return Row(
      children: [
        _buildGroupAvatarCluster(channel, displayAvatar, displayName),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: TextStyle(
                  fontSize: 16,
                  color: titleColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
              _buildTypingIndicator(repo, channel, isGroup: true, isDark: isDark),
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
    bool isDark,
  ) {
    final titleColor = isDark ? Colors.white : AppColors.primaryInk;
    return StreamBuilder<AppUser?>(
      stream: otherUserId != null && otherUserId.isNotEmpty && otherUserId != 'Unknown'
          ? ref.read(userRepositoryProvider).watchUser(otherUserId)
          : const Stream.empty(),
      builder: (context, userSnapshot) {
        final user = userSnapshot.data;
        final name = user?.displayName ?? (displayName != 'Chat' ? displayName : (otherUserId ?? 'Chat'));
        final avatar = user?.avatarUrl ?? displayAvatar;
        final verification = user?.verificationType ?? 'none';

        return Row(
          children: [
            GestureDetector(
              onTap: () {
                if (otherUserId != null && otherUserId.isNotEmpty && !otherUserId.contains('ai')) {
                  context.push('/profile/$otherUserId');
                }
              },
              child: UserAvatar(
                userId: otherUserId ?? '',
                avatarUrl: avatar,
                displayName: name,
                radius: 18,
                showStoryRing: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (otherUserId != null && otherUserId.isNotEmpty && !otherUserId.contains('ai')) {
                    context.push('/profile/$otherUserId');
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 16,
                              color: titleColor,
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
                    _buildTypingIndicator(repo, channel, isGroup: false, isDark: isDark),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAiPromptChip(String text) {
    return ActionChip(
      label: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      backgroundColor: const Color(0xFF1E293B).withValues(alpha: 0.8),
      side: BorderSide(
        color: const Color(0xFF14B8A6).withValues(alpha: 0.4),
        width: 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      onPressed: () {
        _messageController.text = text.replaceAll(RegExp(r'^[^\w]+'), '').trim();
        _sendMessage();
      },
    );
  }

  Widget _buildTypingIndicator(
    ChatRepository repo,
    ChatChannel? channel, {
    required bool isGroup,
    required bool isDark,
  }) {
    final textColor = isDark ? Colors.white.withValues(alpha: 0.6) : AppColors.primaryInk.withValues(alpha: 0.6);
    final isAi = !isGroup && (
      (channel?.displayName?.toLowerCase().contains('ai') ?? false) ||
      (channel?.memberNames.values.any((name) => name.toLowerCase().contains('abuad ai')) ?? false)
    );

    return StreamBuilder<Map<String, bool>>(
      stream: repo.watchTypingStatus(widget.channelId),
      builder: (context, snapshot) {
        final typingMap = snapshot.data ?? {};
        final typingUserIds = typingMap.entries
            .where((e) => e.value && e.key != repo.currentUserId)
            .map((e) => e.key)
            .toList();

        if (typingUserIds.isEmpty) {
          if (isAi) {
            return Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  "AI Assistant • Online",
                  style: TextStyle(
                    color: textColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            );
          }

          if (!isGroup && channel != null && channel.streakCount > 0) {
            return Row(
              children: [
                const Text("🔥", style: TextStyle(fontSize: 10)),
                const SizedBox(width: 4),
                Text(
                  "${channel.streakCount}",
                  style: TextStyle(
                    color: textColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            );
          }
          if (isGroup) {
            return Text(
              'Group',
              style: TextStyle(
                color: textColor,
                fontSize: 11,
              ),
            );
          }
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Color(0xFF22C55E),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'Active now',
                style: TextStyle(
                  color: textColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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
          typingText = isAi ? 'AI is generating reply...' : 'typing...';
        }

        return Text(
          typingText,
          style: const TextStyle(
            color: Color(0xFF6366F1),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        );
      },
    );
  }

  void _startCall({required bool isVideo, required String name, String? avatar}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            UserAvatar(
              userId: '',
              avatarUrl: avatar,
              displayName: name,
              radius: 36,
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isVideo ? 'Starting Video Call...' : 'Connecting Call...',
              style: TextStyle(fontSize: 13, color: Colors.grey[400]),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 26),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendDocument() async {
    try {
      final imageService = ref.read(imageUploadServiceProvider);
      final file = await imageService.pickImage();
      if (file == null) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sharing document...')),
      );

      final result = await imageService.uploadImage(
        file,
        path: 'chat_docs/${widget.channelId}/',
      );

      await ref.read(chatRepositoryProvider).sendMessage(
        widget.channelId,
        '📄 Document: ${file.name}',
        type: 'text',
        mediaUrl: result.url,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing document: $e')),
      );
    }
  }

  Widget _buildLiveTypingBanner(ChatChannel? channel, String otherUserName, bool isDark) {
    final repo = ref.watch(chatRepositoryProvider);
    return StreamBuilder<Map<String, bool>>(
      stream: repo.watchTypingStatus(widget.channelId),
      builder: (context, snapshot) {
        final typingMap = snapshot.data ?? {};
        final isOtherTyping = typingMap.entries
            .any((e) => e.value && e.key != repo.currentUserId);

        if (!isOtherTyping) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(left: 20, bottom: 8),
          child: Row(
            children: [
              Text(
                '$otherUserName is typing...',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              _buildPulsingDots(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPulsingDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          width: 4,
          height: 4,
          decoration: const BoxDecoration(
            color: Color(0xFF6366F1),
            shape: BoxShape.circle,
          ),
        ).animate(onPlay: (controller) => controller.repeat(reverse: true))
         .scale(
            delay: Duration(milliseconds: index * 180),
            duration: const Duration(milliseconds: 400),
            begin: const Offset(0.6, 0.6),
            end: const Offset(1.3, 1.3),
         );
      }),
    );
  }

    void _showCreatePollDialog() {
    final questionCtrl = TextEditingController();
    final opt1Ctrl = TextEditingController();
    final opt2Ctrl = TextEditingController();
    final opt3Ctrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('📊 Create Poll', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: questionCtrl,
                decoration: InputDecoration(
                  labelText: 'Question',
                  hintText: 'When should we have our group study?',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: opt1Ctrl,
                decoration: InputDecoration(
                  labelText: 'Option 1',
                  hintText: 'Today 6 PM',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: opt2Ctrl,
                decoration: InputDecoration(
                  labelText: 'Option 2',
                  hintText: 'Tomorrow 4 PM',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: opt3Ctrl,
                decoration: InputDecoration(
                  labelText: 'Option 3 (Optional)',
                  hintText: 'Friday 9 AM',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final q = questionCtrl.text.trim();
              final o1 = opt1Ctrl.text.trim();
              final o2 = opt2Ctrl.text.trim();
              final o3 = opt3Ctrl.text.trim();
              if (q.isEmpty || o1.isEmpty || o2.isEmpty) return;

              final pollPayload = jsonEncode({
                'question': q,
                'options': [
                  {'text': o1, 'votes': 0, 'voters': []},
                  {'text': o2, 'votes': 0, 'voters': []},
                  if (o3.isNotEmpty) {'text': o3, 'votes': 0, 'voters': []},
                ],
              });

              Navigator.pop(ctx);
              await ref.read(chatRepositoryProvider).sendMessage(
                widget.channelId,
                pollPayload,
                type: 'poll',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Create Poll'),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(ChatMessage message, bool isMe, bool isDark) {
    String fileName = 'MTH205_Lec4_Notes.pdf';
    String fileSize = '6.4 MB';
    if (message.content.contains('Document:')) {
      fileName = message.content.replaceFirst('📄 Document:', '').trim();
    } else if (message.content.isNotEmpty) {
      fileName = message.content;
    }

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withValues(alpha: 0.15)
            : (isDark ? const Color(0xFF0F172A) : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe ? Colors.white24 : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.insert_drive_file_rounded, color: Colors.white, size: 18),
                SizedBox(height: 2),
                Text(
                  'PDF',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fileName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isMe ? Colors.white : (isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  fileSize,
                  style: TextStyle(
                    fontSize: 11,
                    color: isMe ? Colors.white70 : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.download_rounded,
              color: isMe ? Colors.white : const Color(0xFF6366F1),
              size: 22,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Downloading document...')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPollCard(ChatMessage message, bool isMe, bool isDark) {
    Map<String, dynamic> pollData = {};
    try {
      if (message.content.startsWith('{')) {
        pollData = jsonDecode(message.content) as Map<String, dynamic>;
      }
    } catch (_) {}

    final question = pollData['question'] as String? ?? (message.content.isNotEmpty ? message.content : 'When should we have our group study?');
    final options = (pollData['options'] as List?)?.cast<Map<String, dynamic>>() ?? [
      {'text': 'Today 6 PM', 'votes': 14, 'voters': ['u1', 'u2', 'u3']},
      {'text': 'Tomorrow 4 PM', 'votes': 32, 'voters': []},
      {'text': 'Friday 9 AM', 'votes': 8, 'voters': []},
    ];

    return Container(
      width: 280,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withValues(alpha: 0.12)
            : (isDark ? const Color(0xFF0F172A) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe ? Colors.white24 : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  question,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isMe ? Colors.white : (isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                ),
              ),
              const Text('📊', style: TextStyle(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          ...options.map((opt) {
            final optText = opt['text'] as String;
            final votes = opt['votes'] as int? ?? 0;
            final voters = (opt['voters'] as List?)?.cast<String>() ?? [];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$optText ($votes votes)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isMe ? Colors.white.withValues(alpha: 0.9) : (isDark ? Colors.white70 : const Color(0xFF334155)),
                      ),
                    ),
                  ),
                  if (voters.isNotEmpty)
                    SizedBox(
                      width: 44,
                      height: 18,
                      child: Stack(
                        children: [
                          for (int i = 0; i < min(voters.length, 3); i++)
                            Positioned(
                              left: i * 12.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1),
                                ),
                                child: const CircleAvatar(
                                  radius: 8,
                                  backgroundColor: Color(0xFF6366F1),
                                  child: Icon(Icons.person, size: 10, color: Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vote recorded!')),
                );
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                'Vote',
                style: TextStyle(
                  color: Color(0xFF6366F1),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentDrawer(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle & Close button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 24),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _showAttachmentDrawer = false),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: isDark ? Colors.white70 : Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 7 Circular Action Grid
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDrawerItem(
                  gradient: const [Color(0xFFFB7185), Color(0xFFE11D48)],
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  onTap: () async {
                    setState(() => _showAttachmentDrawer = false);
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
                ),
                const SizedBox(width: 14),
                _buildDrawerItem(
                  gradient: const [Color(0xFF38BDF8), Color(0xFF2563EB)],
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  onTap: () {
                    setState(() => _showAttachmentDrawer = false);
                    _sendImage(isSnap: false);
                  },
                ),
                const SizedBox(width: 14),
                _buildDrawerItem(
                  gradient: const [Color(0xFF818CF8), Color(0xFF4F46E5)],
                  icon: Icons.insert_drive_file_rounded,
                  label: 'Document',
                  onTap: () {
                    setState(() => _showAttachmentDrawer = false);
                    _sendDocument();
                  },
                ),
                const SizedBox(width: 14),
                _buildDrawerItem(
                  gradient: const [Color(0xFFC084FC), Color(0xFF9333EA)],
                  icon: Icons.mic_rounded,
                  label: 'Audio',
                  onTap: () {
                    setState(() => _showAttachmentDrawer = false);
                    _startRecording();
                  },
                ),
                const SizedBox(width: 14),
                _buildDrawerItem(
                  gradient: const [Color(0xFF34D399), Color(0xFF059669)],
                  icon: Icons.location_on_rounded,
                  label: 'Location',
                  onTap: () {
                    setState(() => _showAttachmentDrawer = false);
                    _sendLocation();
                  },
                ),
                const SizedBox(width: 14),
                _buildDrawerItem(
                  gradient: const [Color(0xFFFBBF24), Color(0xFFD97706)],
                  icon: Icons.poll_rounded,
                  label: 'Poll',
                  onTap: () {
                    setState(() => _showAttachmentDrawer = false);
                    _showCreatePollDialog();
                  },
                ),
                const SizedBox(width: 14),
                _buildDrawerItem(
                  gradient: const [Color(0xFFFB923C), Color(0xFFEA580C)],
                  icon: Icons.person_rounded,
                  label: 'Contact',
                  onTap: () {
                    setState(() => _showAttachmentDrawer = false);
                    context.push('/chat/user-search');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required List<Color> gradient,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: gradient.last.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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
