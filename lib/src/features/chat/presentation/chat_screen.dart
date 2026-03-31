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
import 'package:giphy_get/giphy_get.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/widgets/verification_badge.dart';
import '../../../core/theme/app_colors.dart';
import '../data/chat_repository.dart';
import '../domain/chat_channel.dart';
import '../domain/chat_message.dart';
import '../../user/data/user_repository.dart';
import '../../../core/services/image_upload_service.dart';

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

  bool _hasText = false;

  // Recording & Giphy state
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isLocked = false;
  DateTime? _recordingStartTime;
  Timer? _recordingTimer;
  double _dragOffset = 0.0;

  // Audio Player for voice notes
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingUrl;
  bool _isPlaying = false;

  // Placeholder Giphy Key - should be moved to a config file
  static const _giphyKey = '7W9Y2XQzZx9z0z0z0z0z0z0z0z0z0z0z';

  @override
  void initState() {
    super.initState();
    // Mark messages as read when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatRepositoryProvider).markMessagesAsRead(widget.channelId);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _recordingTimer?.cancel();
    // Clear typing status when leaving
    ref.read(chatRepositoryProvider).setTypingStatus(widget.channelId, false);
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

  Future<void> _onGiphyTap() async {
    try {
      GiphyGif? gif = await GiphyGet.getGif(
        context: context,
        apiKey: _giphyKey,
        tabColor: AppColors.secondaryTeal,
        debounceTimeInMilliseconds: 350,
      );

      if (gif != null && gif.images?.fixedHeight?.url != null) {
        final imageUrl = gif.images!.fixedHeight!.url;
        final width =
            double.tryParse(gif.images?.fixedHeight?.width ?? '200') ?? 200.0;
        final height =
            double.tryParse(gif.images?.fixedHeight?.height ?? '200') ?? 200.0;

        ref
            .read(chatRepositoryProvider)
            .sendMessage(
              widget.channelId,
              'GIF',
              type: 'giphy',
              imageUrl: imageUrl,
              imageWidth: width,
              imageHeight: height,
            );
      }
    } catch (e) {
      debugPrint('Error getting Giphy: $e');
    }
  }

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

  Widget _buildStandardInputUI(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    Icons.sentiment_very_satisfied_outlined,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  onPressed: _onGiphyTap,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: _onTextChanged,
                    maxLines: 5,
                    minLines: 1,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Message',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.attach_file,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  onPressed: _showAttachmentMenu,
                ),
                if (!_hasText)
                  IconButton(
                    icon: Icon(
                      Icons.camera_alt,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    onPressed: () => _sendImage(isSnap: true),
                  ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
        const SizedBox(width: 5),
        // Send/Mic Button
        GestureDetector(
          onTap: _hasText
              ? _sendMessage
              : () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Hold to record'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
          onLongPressStart: (_) => _hasText ? null : _startRecording(),
          child: Container(
            height: 50,
            width: 50,
            decoration: const BoxDecoration(
              color: AppColors.secondaryTeal,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _hasText ? Icons.send_rounded : Icons.mic,
              color: Colors.white,
              size: 24,
            ),
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
        if (isReadByMe) {
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
      onLongPress: () {
        // Save image logic?
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Long-press to save coming soon!')),
        );
      },
      child: ClipRRectangle(
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
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDarkElevated : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Reactions Bar
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
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
                      child: Text(emoji, style: const TextStyle(fontSize: 26)),
                    );
                  }).toList(),
                ),
              ),
              // Reply
              ListTile(
                leading: const Icon(
                  Icons.reply,
                  color: AppColors.secondaryTeal,
                ),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _replyingTo = message);
                },
              ),
              // Edit Text
              if (message.type == 'text' && isMe)
                ListTile(
                  leading: const Icon(
                    Icons.edit,
                    color: AppColors.secondaryTeal,
                  ),
                  title: const Text('Edit'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _editingMessage = message;
                      _messageController.text = message.content;
                      _replyingTo = null;
                    });
                  },
                ),
              // Copy Text
              if (message.type == 'text' && !message.isDeleted)
                ListTile(
                  leading: const Icon(Icons.copy, color: Colors.blue),
                  title: const Text('Copy'),
                  onTap: () {
                    Navigator.pop(context);
                    Clipboard.setData(ClipboardData(text: message.content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard')),
                    );
                  },
                ),
              // Delete (if me or admin)
              if (isMe || isAdmin)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Message?'),
                        content: const Text(
                          'Are you sure you want to delete this message?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await ref
                          .read(chatRepositoryProvider)
                          .deleteMessage(widget.channelId, message.id);
                    }
                  },
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
                  Icons.insert_drive_file,
                  Colors.indigo,
                  'Document',
                  () {},
                ),
                _buildAttachmentOption(
                  Icons.camera_alt,
                  Colors.pink,
                  'Snap', // Explicitly named Snap
                  () {
                    Navigator.pop(context);
                    _sendSnap(); // Cameras are for Snaps
                  },
                ),
                _buildAttachmentOption(
                  Icons.image,
                  Colors.purple,
                  'Gallery',
                  () {
                    Navigator.pop(context);
                    _sendImage(isSnap: false); // Explicitly permanent
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(
                  Icons.headset,
                  Colors.orange,
                  'Audio',
                  () {},
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
                _buildAttachmentOption(
                  Icons.person,
                  Colors.blue,
                  'Contact',
                  () {},
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
            backgroundColor: Colors.transparent,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.inkTealGradient,
              ),
            ),
            title: isGroup
                ? Row(
                    children: [
                      if (displayAvatar != null && displayAvatar.isNotEmpty)
                        CircleAvatar(
                          radius: 18,
                          backgroundImage: CachedNetworkImageProvider(
                            displayAvatar,
                          ),
                        )
                      else
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          child: const Icon(
                            Icons.groups,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            StreamBuilder<Map<String, bool>>(
                              stream: repo.watchTypingStatus(widget.channelId),
                              builder: (context, snapshot) {
                                final typingMap = snapshot.data ?? {};
                                final typingUserIds = typingMap.entries
                                    .where(
                                      (e) =>
                                          e.value &&
                                          e.key != repo.currentUserId,
                                    )
                                    .map((e) => e.key)
                                    .toList();

                                if (typingUserIds.isEmpty) {
                                  return const SizedBox();
                                }

                                final names = typingUserIds
                                    .map(
                                      (id) =>
                                          channel?.memberNames[id] ?? 'Someone',
                                    )
                                    .toList();

                                String typingText;
                                if (names.length == 1) {
                                  typingText = '${names[0]} is typing...';
                                } else if (names.length == 2) {
                                  typingText =
                                      '${names[0]} and ${names[1]} are typing...';
                                } else {
                                  typingText =
                                      '${names.length} people are typing...';
                                }

                                return Text(
                                  typingText,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : StreamBuilder<AppUser?>(
                    stream: otherUserId != null && otherUserId != 'Unknown'
                        ? ref
                              .read(userRepositoryProvider)
                              .watchUser(otherUserId)
                        : const Stream.empty(),
                    builder: (context, userSnapshot) {
                      final user = userSnapshot.data;
                      final effectiveName = user?.displayName ?? displayName;
                      final effectiveAvatar = user?.avatarUrl ?? displayAvatar;
                      final effectiveVerification =
                          user?.verificationType ?? 'none';

                      return Row(
                        children: [
                          if (effectiveAvatar != null &&
                              effectiveAvatar.isNotEmpty)
                            CircleAvatar(
                              radius: 18,
                              backgroundImage: CachedNetworkImageProvider(
                                effectiveAvatar,
                              ),
                            )
                          else
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.15,
                              ),
                              child: isGroup
                                  ? const Icon(
                                      Icons.groups,
                                      color: Colors.white,
                                      size: 20,
                                    )
                                  : Text(
                                      effectiveName.isNotEmpty
                                          ? effectiveName[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      effectiveName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    if (!isGroup && otherUserId != null)
                                      VerificationBadge(
                                        type: effectiveVerification,
                                        size: 16,
                                      ),
                                  ],
                                ),
                                StreamBuilder<Map<String, bool>>(
                                  stream: repo.watchTypingStatus(
                                    widget.channelId,
                                  ),
                                  builder: (context, snapshot) {
                                    final typingMap = snapshot.data ?? {};
                                    final typingUserIds = typingMap.entries
                                        .where(
                                          (e) =>
                                              e.value &&
                                              e.key != repo.currentUserId,
                                        )
                                        .map((e) => e.key)
                                        .toList();

                                    if (typingUserIds.isEmpty) {
                                      if (channel != null &&
                                          channel.streakCount > 0) {
                                        return Row(
                                          children: [
                                            const Text(
                                              "🔥",
                                              style: TextStyle(fontSize: 12),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              "${channel.streakCount} Streak",
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(
                                                  0.9,
                                                ),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        );
                                      }
                                      return const SizedBox();
                                    }

                                    String typingText;
                                    if (isGroup) {
                                      final names = typingUserIds
                                          .map(
                                            (id) =>
                                                channel?.memberNames[id] ??
                                                'Someone',
                                          )
                                          .toList();
                                      if (names.length == 1) {
                                        typingText = '${names[0]} is typing...';
                                      } else if (names.length == 2) {
                                        typingText =
                                            '${names[0]} and ${names[1]} are typing...';
                                      } else {
                                        typingText =
                                            'Several people are typing...';
                                      }
                                    } else {
                                      typingText = 'typing...';
                                    }

                                    return Text(
                                      typingText,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
            actions: [
              IconButton(
                icon: const Icon(Icons.info_outline, color: Colors.white),
                onPressed: () => context.push('/chat/${widget.channelId}/info'),
              ),
            ],
          ),
          body: Stack(
            children: [
              // Background Pattern
              Positioned.fill(
                child: CustomPaint(
                  painter: ChatBackgroundPainter(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : Colors.black.withValues(alpha: 0.03),
                  ),
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
                        if (messages.isEmpty) {
                          return const Center(child: Text('Say hello! 👋'));
                        }

                        return ListView.builder(
                          reverse: true,
                          controller: _scrollController,
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            final isMe = message.senderId == repo.currentUserId;
                            final isRead = message.readBy.length > 1;

                            final nextMessage = index + 1 < messages.length
                                ? messages[index + 1]
                                : null;
                            final isNewDay =
                                nextMessage == null ||
                                message.timestamp.day !=
                                    nextMessage.timestamp.day ||
                                message.timestamp.month !=
                                    nextMessage.timestamp.month ||
                                message.timestamp.year !=
                                    nextMessage.timestamp.year;

                            // Swipe to reply
                            final messageItem = Dismissible(
                              key: Key(message.id),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (direction) async {
                                setState(() {
                                  _replyingTo = message;
                                });
                                return false; // Don't actually dismiss
                              },
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20.0),
                                color: Colors.transparent,
                                child: const Icon(
                                  Icons.reply,
                                  color: AppColors.secondaryTeal,
                                ),
                              ),
                              child: Align(
                                alignment: isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
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
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
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
                                                  : Colors.black.withValues(
                                                      alpha: 0.05,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border(
                                                left: BorderSide(
                                                  color:
                                                      AppColors.secondaryTeal,
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
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color:
                                                        AppColors.secondaryTeal,
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
                                                                ? Colors.white24
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
                                                                      : AppColors
                                                                            .secondaryTeal,
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
                                                                    color: isMe
                                                                        ? Colors
                                                                              .white
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
                                                                      bottom: 8,
                                                                      right: 8,
                                                                      child: Container(
                                                                        padding: const EdgeInsets.symmetric(
                                                                          horizontal:
                                                                              8,
                                                                          vertical:
                                                                              4,
                                                                        ),
                                                                        decoration: BoxDecoration(
                                                                          color:
                                                                              AppColors.secondaryTeal,
                                                                          borderRadius: BorderRadius.circular(
                                                                            12,
                                                                          ),
                                                                        ),
                                                                        child: const Text(
                                                                          'View Map',
                                                                          style: TextStyle(
                                                                            color:
                                                                                Colors.white,
                                                                            fontSize:
                                                                                10,
                                                                            fontWeight:
                                                                                FontWeight.bold,
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
                                                              ? AppColors
                                                                    .inkTealGradient
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
                                                                  isMe ? 16 : 4,
                                                                ),
                                                            bottomRight:
                                                                Radius.circular(
                                                                  isMe ? 4 : 16,
                                                                ),
                                                          ),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Colors
                                                                  .black
                                                                  .withValues(
                                                                    alpha: 0.05,
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
                                                              MainAxisSize.min,
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
                                                                          snapshot
                                                                              .data;
                                                                      final name =
                                                                          user?.displayName ??
                                                                          channel
                                                                              ?.memberNames[message
                                                                              .senderId] ??
                                                                          'Unknown';
                                                                      return Padding(
                                                                        padding: const EdgeInsets.only(
                                                                          bottom:
                                                                              4,
                                                                        ),
                                                                        child: Text(
                                                                          name,
                                                                          style: TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                            color:
                                                                                AppColors.secondaryTeal,
                                                                            fontSize:
                                                                                12,
                                                                          ),
                                                                        ),
                                                                      );
                                                                    },
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
                                                                    fontSize: 9,
                                                                    fontStyle:
                                                                        FontStyle
                                                                            .italic,
                                                                    color: isMe
                                                                        ? Colors
                                                                              .white70
                                                                        : Colors
                                                                              .grey,
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
                                                                      width: 4,
                                                                    ),
                                                                    Icon(
                                                                      isRead
                                                                          ? Icons.done_all
                                                                          : Icons.done,
                                                                      size: 14,
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
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 4,
                                            ),
                                            child: Wrap(
                                              spacing: 4,
                                              children: message
                                                  .reactions
                                                  .entries
                                                  .map((e) {
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
                                                  })
                                                  .toList(),
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
                  if (_replyingTo != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2A2A2A)
                            : Colors.grey[100],
                        border: Border(
                          top: BorderSide(
                            color: isDark ? Colors.white12 : Colors.grey[300]!,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.reply,
                            size: 20,
                            color: AppColors.secondaryTeal,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Replying to ${_replyingTo!.senderId == repo.currentUserId ? 'yourself' : 'message'}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppColors.secondaryTeal,
                                  ),
                                ),
                                Text(
                                  _replyingTo!.content,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() => _replyingTo = null),
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ],
                      ),
                    ),

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
                  if (channel != null &&
                      channel.restrictMessaging &&
                      !channel.adminIds.contains(repo.currentUserId))
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surfaceDarkElevated
                            : Colors.grey[100],
                        border: Border(
                          top: BorderSide(
                            color: isDark ? Colors.white12 : Colors.grey[300]!,
                          ),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'Only admins can send messages',
                          style: TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                      ),
                      child: SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_editingMessage != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                color: isDark
                                    ? Colors.white10
                                    : Colors.grey[100],
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.edit,
                                      size: 16,
                                      color: AppColors.secondaryTeal,
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Editing Message',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: AppColors.secondaryTeal,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 18),
                                      onPressed: () {
                                        setState(() {
                                          _editingMessage = null;
                                          _messageController.clear();
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            _isLocked
                                ? _buildLockedUI()
                                : _isRecording
                                ? _buildRecordingUI(isDark)
                                : _buildStandardInputUI(isDark),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
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
}

// Helper widget for rounded rectangle image
class ClipRRectangle extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;

  const ClipRRectangle({
    super.key,
    required this.child,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(borderRadius: borderRadius, child: child);
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

    final random = Random(42); // Fixed seed for consistent pattern

    for (var i = 0; i < 40; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final shapeType = random.nextInt(3);

      if (shapeType == 0) {
        // Circle
        canvas.drawCircle(Offset(x, y), 8 + random.nextDouble() * 10, paint);
      } else if (shapeType == 1) {
        // Triangle
        final path = Path();
        path.moveTo(x, y);
        path.lineTo(x + 15, y + 25);
        path.lineTo(x - 15, y + 25);
        path.close();
        canvas.drawPath(path, paint);
      } else {
        // Squiggle
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
