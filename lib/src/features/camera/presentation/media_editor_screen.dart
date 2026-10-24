import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../../core/services/media_saver.dart';
import '../../../core/services/image_upload_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../stories/data/story_repository.dart';
import '../../user/data/user_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../chat/data/chat_repository.dart';
import '../../music/domain/audio_track.dart';
import '../../music/presentation/music_picker_sheet.dart';
import '../presentation/camera_screen.dart';

/// Snapchat-style Media Editor Screen
/// Displayed immediately after capturing a photo or recording a video.
/// Allows adding text, drawings, emojis, stickers, saving to camera roll,
/// posting to My Story, or sending directly to friends.
class MediaEditorScreen extends ConsumerStatefulWidget {
  final XFile mediaFile;
  final bool isVideo;
  final bool isForStory;
  final CameraContext cameraContext;
  final String? directRecipientId;
  final String? directRecipientName;
  final Function(XFile file, CameraMode mode)? onMediaExported;
  final AudioTrack? initialAudioTrack;
  final double? aspectRatio;
  final String? aspectRatioLabel;
  final String? initialTool;
  final String? attachedLink;
  final int? snapDurationSeconds;
  final List<double>? colorMatrix;

  const MediaEditorScreen({
    super.key,
    required this.mediaFile,
    required this.isVideo,
    this.isForStory = true,
    this.cameraContext = CameraContext.snap,
    this.directRecipientId,
    this.directRecipientName,
    this.onMediaExported,
    this.initialAudioTrack,
    this.aspectRatio,
    this.aspectRatioLabel,
    this.initialTool,
    this.attachedLink,
    this.snapDurationSeconds,
    this.colorMatrix,
  });

  @override
  ConsumerState<MediaEditorScreen> createState() => _MediaEditorScreenState();
}

class _MediaEditorScreenState extends ConsumerState<MediaEditorScreen> {
  // GlobalKey to composite drawings, text overlays, and stickers into the saved image
  final GlobalKey _previewStackKey = GlobalKey();

  // Video playback
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isMuted = false;

  // Audio / Music Track state
  AudioTrack? _selectedAudioTrack;
  AudioPlayer? _bgMusicPlayer;

  // Image bytes (web & mobile safe)
  Uint8List? _mediaBytes;

  // History state for unified Undo
  final List<_EditorAction> _history = [];

  // Filter state
  bool _showFilterPanel = false;
  int _selectedFilterIndex = 0;
  List<double>? _currentMatrix;

  // Snap viewing duration (seconds, 0 = infinite / loop)
  int _snapDurationSeconds = 10;

  // Drawing state
  bool _isDrawingMode = false;
  final List<_DoodleStroke> _strokes = [];
  Color _selectedDrawColor = Colors.white;
  final double _strokeWidth = 4.0;

  // Text overlay studio state
  bool _isTextEditing = false;
  final TextEditingController _textController = TextEditingController();
  final List<_TextOverlayItem> _textOverlays = [];
  Color _selectedTextColor = Colors.white;
  int? _editingTextIndex;
  TextStyleType _selectedTextStyle = TextStyleType.modern;
  TextBackgroundType _selectedTextBg = TextBackgroundType.frosted;
  TextAlign _selectedTextAlign = TextAlign.center;

  // Sticker/Emoji overlay state
  final List<_StickerOverlayItem> _stickers = [];

  // Bottom action states
  bool _isSaving = false;
  bool _isPostingStory = false;
  bool _isSaved = false;

  final List<Color> _palette = const [
    Colors.white,
    Colors.yellowAccent,
    Color(0xFFFF3B30), // Red
    Color(0xFF34C759), // Green
    Color(0xFF007AFF), // Blue
    Color(0xFFAF52DE), // Purple
    Color(0xFFFF9500), // Orange
    Colors.black,
  ];

  @override
  void initState() {
    super.initState();
    _loadMedia();
    if (widget.colorMatrix != null) {
      _currentMatrix = widget.colorMatrix;
    }
    if (widget.snapDurationSeconds != null && widget.snapDurationSeconds! > 0) {
      _snapDurationSeconds = widget.snapDurationSeconds!;
    }
    if (widget.initialAudioTrack != null) {
      _selectedAudioTrack = widget.initialAudioTrack;
      _playBackgroundMusic(widget.initialAudioTrack!);
    }
    if (widget.initialTool == 'text') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openTextDialog();
      });
    } else if (widget.initialTool == 'draw') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _isDrawingMode = true);
      });
    } else if (widget.initialTool == 'sticker') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openStickerSheet();
      });
    }
  }

  Future<void> _playBackgroundMusic(AudioTrack track) async {
    try {
      _bgMusicPlayer ??= AudioPlayer();
      await _bgMusicPlayer!.stop();
      await _bgMusicPlayer!.setReleaseMode(ReleaseMode.loop);
      await _bgMusicPlayer!.play(UrlSource(track.audioUrl));
    } catch (e) {
      debugPrint('Error playing background audio: $e');
    }
  }

  Future<void> _removeBackgroundMusic() async {
    try {
      await _bgMusicPlayer?.stop();
    } catch (_) {}
    if (mounted) {
      setState(() => _selectedAudioTrack = null);
    }
  }

  Future<void> _loadMedia() async {
    try {
      final bytes = await widget.mediaFile.readAsBytes();
      if (mounted) setState(() => _mediaBytes = bytes);

      if (widget.isVideo) {
        if (kIsWeb) {
          _videoController = VideoPlayerController.networkUrl(
            Uri.parse(widget.mediaFile.path),
          );
        } else {
          _videoController = VideoPlayerController.file(
            File(widget.mediaFile.path),
          );
        }
        await _videoController!.initialize();
        await _videoController!.setLooping(true);
        await _videoController!.play();
        if (mounted) setState(() => _isVideoInitialized = true);
      }
    } catch (e) {
      debugPrint('Error loading media preview: $e');
    }
  }

  @override
  void dispose() {
    _bgMusicPlayer?.stop();
    _bgMusicPlayer?.dispose();
    _videoController?.dispose();
    _textController.dispose();
    super.dispose();
  }

  // ── Gallery Save ─────────────────────────────────────────────────────────

  /// Composite overlays (drawings, stickers, text) into a single exportable image
  Future<XFile> _exportCompositedMedia() async {
    if (widget.isVideo) {
      return widget.mediaFile;
    }

    // Fast-path: if no overlays exist, the captured mediaFile is already complete
    if (_strokes.isEmpty && _stickers.isEmpty && _textOverlays.isEmpty) {
      return widget.mediaFile;
    }

    try {
      final boundary = _previewStackKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return widget.mediaFile;

      // If render boundary is dirty from setState, wait until the frame has finished painting
      if (boundary.debugNeedsPaint) {
        final completer = Completer<void>();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          completer.complete();
        });
        await completer.future;
      }
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return widget.mediaFile;

      final pngBytes = byteData.buffer.asUint8List();

      if (kIsWeb) {
        return XFile.fromData(
          pngBytes,
          mimeType: 'image/png',
          name: 'snap_${DateTime.now().millisecondsSinceEpoch}.png',
        );
      } else {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/snap_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(pngBytes);
        return XFile(file.path);
      }
    } catch (e) {
      debugPrint('Error compositing media: $e');
      return widget.mediaFile;
    }
  }

  // ── Save to Gallery ────────────────────────────────────────────────────────

  Future<void> _handleSave() async {
    if (_isSaving) return;
    HapticFeedback.mediumImpact();

    // If text editing is active, commit it before capturing
    if (_isTextEditing) {
      _submitText();
    }

    setState(() => _isSaving = true);

    try {
      final exportedFile = await _exportCompositedMedia();
      final success = await MediaSaver.saveLocalFile(
        exportedFile,
        isVideo: widget.isVideo,
      );

      if (mounted) {
        setState(() {
          _isSaving = false;
          _isSaved = success;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    success
                        ? (widget.isVideo ? 'Video saved to Gallery' : 'Photo saved to Gallery')
                        : 'Could not save to Gallery. Please grant storage permission in Settings.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: success ? const Color(0xFF10B981) : Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      debugPrint('MediaEditorScreen _handleSave error: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving media: $e')),
        );
      }
    }
  }

  // ── My Story Publish ───────────────────────────────────────────────────────

  Future<void> _handleMyStory() async {
    if (_isPostingStory) return;
    HapticFeedback.mediumImpact();
    setState(() => _isPostingStory = true);

    try {
      final exportedFile = await _exportCompositedMedia();
      final storyRepo = ref.read(storyRepositoryProvider);
      await storyRepo.createStory(
        mediaFile: exportedFile,
        content: '',
        type: widget.isVideo ? 'video' : 'image',
        caption: _textOverlays.isNotEmpty ? _textOverlays.first.text : null,
        audioUrl: _selectedAudioTrack?.audioUrl,
        musicTitle: _selectedAudioTrack?.title,
        musicArtist: _selectedAudioTrack?.artist,
      ).timeout(const Duration(seconds: 60));

      if (mounted) {
        setState(() => _isPostingStory = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: Colors.white),
                SizedBox(width: 10),
                Text('Added to Your Story!', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            backgroundColor: const Color(0xFF8B5CF6),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.of(context).pop(); // Return to previous flow
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPostingStory = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to publish story: $e')),
        );
      }
    } finally {
      if (mounted && _isPostingStory) {
        setState(() => _isPostingStory = false);
      }
    }
  }

  // ── Add To Post Flow ───────────────────────────────────────────────────────

  Future<void> _handleAddToPost() async {
    HapticFeedback.mediumImpact();
    final exportedFile = await _exportCompositedMedia();
    final mode = widget.isVideo ? CameraMode.video : CameraMode.photo;
    if (widget.onMediaExported != null) {
      widget.onMediaExported!(exportedFile, mode);
    }
    if (mounted) {
      Navigator.of(context).pop({
        'file': exportedFile,
        'mode': mode,
      });
    }
  }

  // ── Send to Multi-Recipient Sheet & Direct Snaps ──────────────────────────

  Future<void> _sendSnapToRecipient(AppUser recipient) => _sendSnapToRecipients([recipient]);

  Future<void> _sendSnapToRecipients(List<AppUser> recipients) async {
    if (recipients.isEmpty) return;
    try {
      final label = recipients.length == 1
          ? '@${recipients.first.handle}'
          : '${recipients.length} friends';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text('Sending Snap to $label...'),
            ],
          ),
          backgroundColor: const Color(0xFF6366F1),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 30),
        ),
      );

      final exportedFile = await _exportCompositedMedia();
      final chatRepo = ref.read(chatRepositoryProvider);
      final imageService = ref.read(imageUploadServiceProvider);

      // Upload media once to optimize speed and network bandwidth
      final result = await (widget.isVideo
          ? imageService.uploadVideo(exportedFile, path: 'chat_snaps/multi/')
          : imageService.uploadImage(exportedFile, path: 'chat_snaps/multi/'));

      // Dispatch snaps concurrently to each recipient channel
      await Future.wait(recipients.map((recipient) async {
        try {
          final channelId = await chatRepo.createOrGetChannel(
            recipient.uid,
            otherUserName: recipient.displayName,
            otherUserAvatar: recipient.avatarUrl,
          );

          await chatRepo.sendMessage(
            channelId,
            widget.isVideo ? '🎥 Video Snap' : '📸 Snap',
            type: widget.isVideo ? 'video' : 'image',
            imageUrl: result.url,
            imageWidth: result.width,
            imageHeight: result.height,
            isSnap: true,
            duration: _snapDurationSeconds > 0 ? _snapDurationSeconds : 10,
            receiverId: recipient.uid,
          );
        } catch (err) {
          debugPrint('Error delivering snap to ${recipient.uid}: $err');
        }
      }));

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.local_fire_department_rounded, color: Colors.amberAccent),
                const SizedBox(width: 8),
                Text(
                  'Snap delivered to $label! 🔥',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error delivering direct snap: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send snap: $e')),
        );
      }
    }
  }

  void _openSendToSheet() {
    HapticFeedback.mediumImpact();
    final authUser = ref.read(authRepositoryProvider).currentUser;
    if (authUser == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SendToSheet(
        onSend: (recipients, postToStory) {
          Navigator.pop(ctx);
          if (postToStory) {
            _handleMyStory();
          }
          if (recipients.isNotEmpty) {
            _sendSnapToRecipients(recipients);
          }
        },
      ),
    );
  }

  // ── Text Overlay Logic ───────────────────────────────────────────────────

  // ── Text Overlay Logic ───────────────────────────────────────────────────

  void _openTextDialog([int? editIndex]) {
    HapticFeedback.lightImpact();
    setState(() {
      _isTextEditing = true;
      if (editIndex != null && editIndex < _textOverlays.length) {
        _editingTextIndex = editIndex;
        final item = _textOverlays[editIndex];
        _textController.text = item.text;
        _selectedTextColor = item.color;
        _selectedTextStyle = item.styleType;
        _selectedTextBg = item.bgType;
        _selectedTextAlign = item.align;
      } else {
        _editingTextIndex = null;
        _textController.clear();
      }
    });
  }

  void _submitText() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        if (_editingTextIndex != null && _editingTextIndex! < _textOverlays.length) {
          final item = _textOverlays[_editingTextIndex!];
          item.text = text;
          item.color = _selectedTextColor;
          item.styleType = _selectedTextStyle;
          item.bgType = _selectedTextBg;
          item.align = _selectedTextAlign;
        } else {
          _textOverlays.add(
            _TextOverlayItem(
              text: text,
              color: _selectedTextColor,
              position: const Offset(60, 240),
              styleType: _selectedTextStyle,
              bgType: _selectedTextBg,
              align: _selectedTextAlign,
            ),
          );
          _history.add(_EditorAction(_EditorActionType.text));
        }
        _textController.clear();
        _editingTextIndex = null;
        _isTextEditing = false;
      });
    } else {
      setState(() {
        if (_editingTextIndex != null && _editingTextIndex! < _textOverlays.length) {
          _textOverlays.removeAt(_editingTextIndex!);
        }
        _editingTextIndex = null;
        _isTextEditing = false;
      });
    }
  }

  void _deleteEditingText() {
    HapticFeedback.mediumImpact();
    setState(() {
      if (_editingTextIndex != null && _editingTextIndex! < _textOverlays.length) {
        _textOverlays.removeAt(_editingTextIndex!);
      }
      _textController.clear();
      _editingTextIndex = null;
      _isTextEditing = false;
    });
  }

  void _handleUndo() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_history.isNotEmpty) {
        final last = _history.removeLast();
        switch (last.type) {
          case _EditorActionType.stroke:
            if (_strokes.isNotEmpty) _strokes.removeLast();
            break;
          case _EditorActionType.sticker:
            if (_stickers.isNotEmpty) _stickers.removeLast();
            break;
          case _EditorActionType.text:
            if (_textOverlays.isNotEmpty) _textOverlays.removeLast();
            break;
        }
      } else {
        if (_strokes.isNotEmpty) {
          _strokes.removeLast();
        } else if (_stickers.isNotEmpty) {
          _stickers.removeLast();
        } else if (_textOverlays.isNotEmpty) {
          _textOverlays.removeLast();
        }
      }
    });
  }

  // ── Snap Viewing Duration Picker ─────────────────────────────────────────

  void _openDurationPicker() {
    HapticFeedback.lightImpact();
    final durations = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 0]; // 0 represents loop / no timer

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 14),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.timer_outlined, color: Color(0xFF8B5CF6), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Snap Viewing Duration',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose how long friends can view your Snap before expiration',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: durations.map((sec) {
                  final isSelected = sec == _snapDurationSeconds || (sec == 0 && _snapDurationSeconds == 0);
                  final label = sec == 0 ? '∞ Loop' : '${sec}s';
                  return ChoiceChip(
                    label: Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFF8B5CF6),
                    backgroundColor: const Color(0xFF2C2C34),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() => _snapDurationSeconds = sec);
                      Navigator.pop(ctx);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sticker & Campus Studio (Tabs: Campus, Time/Date, Emojis) ────────────

  String _getCurrentTimeFormatted() {
    final now = DateTime.now();
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _getCurrentDateFormatted() {
    final now = DateTime.now();
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    final weekday = weekdays[now.weekday - 1];
    final month = months[now.month - 1];
    return '$weekday, $month ${now.day}';
  }

  void _openStickerSheet() {
    HapticFeedback.lightImpact();

    final campusLocations = [
      {'title': '📍 ABUAD — Ado-Ekiti', 'sub': 'Main Campus', 'icon': Icons.location_on_rounded},
      {'title': '📍 College of Law', 'sub': 'ABUAD Law', 'icon': Icons.gavel_rounded},
      {'title': '📍 Engineering Complex', 'sub': 'Engineering', 'icon': Icons.engineering_rounded},
      {'title': '📍 Afe Babalola Hospital', 'sub': 'ABUTH Multi-System', 'icon': Icons.local_hospital_rounded},
      {'title': '📍 Talent Discovery Centre', 'sub': 'TDC Hall', 'icon': Icons.star_rounded},
      {'title': '📍 College of SMS', 'sub': 'Social & Mgt Sciences', 'icon': Icons.school_rounded},
      {'title': '📍 Alfa Belgore Hall', 'sub': 'Event Centre', 'icon': Icons.theater_comedy_rounded},
      {'title': '📍 Sports Complex', 'sub': 'Stadium & Arena', 'icon': Icons.sports_soccer_rounded},
    ];

    final campusStatuses = [
      {'title': '📚 Study Mode', 'sub': 'Deep Focus', 'icon': Icons.menu_book_rounded},
      {'title': '✍️ Exam Prep', 'sub': 'Good Luck!', 'icon': Icons.edit_note_rounded},
      {'title': '🌙 Night Class', 'sub': 'Midnight Study', 'icon': Icons.nightlight_round},
      {'title': '🎓 ABUAD Life', 'sub': 'Student Spirit', 'icon': Icons.school_rounded},
      {'title': '👨‍🏫 Lecture Vibes', 'sub': 'In Class', 'icon': Icons.co_present_rounded},
      {'title': '🍔 Cafeteria Run', 'sub': 'Food Break', 'icon': Icons.fastfood_rounded},
      {'title': '🛋️ Hostel Chills', 'sub': 'Relaxing', 'icon': Icons.weekend_rounded},
      {'title': '🚀 Tech & Build', 'sub': 'Innovators', 'icon': Icons.rocket_launch_rounded},
    ];

    final emojis = [
      '🔥', '❤️', '😂', '🎉', '💯', '👻', '🎓', '⚡', '🌟', '👑',
      '👀', '✨', '👏', '🥳', '😎', '📚', '🍕', '☕', '🚀', '💜',
      '🤩', '🙌', '💪', '🎯', '📍', '💡', '🏆', '📸', '🎵', '☀️',
      '🤝', '💬', '🤩', '🤙', '🤯', '💃',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E24),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DefaultTabController(
        length: 3,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.65,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 12),
              const Text(
                'Sticker Studio',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const TabBar(
                indicatorColor: Color(0xFF8B5CF6),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                indicatorWeight: 3,
                tabs: [
                  Tab(icon: Icon(Icons.school_rounded, size: 20), text: 'Campus'),
                  Tab(icon: Icon(Icons.schedule_rounded, size: 20), text: 'Time/Date'),
                  Tab(icon: Icon(Icons.emoji_emotions_rounded, size: 20), text: 'Emojis'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    // Tab 1: Campus Geotags & Badges
                    ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      children: [
                        const Text(
                          'ABUAD Locations',
                          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        ...campusLocations.map((loc) => ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(loc['icon'] as IconData, color: const Color(0xFF8B5CF6), size: 18),
                              ),
                              title: Text(
                                loc['title'] as String,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              subtitle: Text(
                                loc['sub'] as String,
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _stickers.add(
                                    _StickerOverlayItem(
                                      content: loc['title'] as String,
                                      subtitle: loc['sub'] as String,
                                      type: StickerType.campusPill,
                                      icon: loc['icon'] as IconData,
                                      position: const Offset(60, 260),
                                    ),
                                  );
                                  _history.add(_EditorAction(_EditorActionType.sticker));
                                });
                                Navigator.pop(ctx);
                              },
                            )),
                        const SizedBox(height: 14),
                        const Text(
                          'Campus Status & Vibe',
                          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        ...campusStatuses.map((stat) => ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.secondaryTeal.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(stat['icon'] as IconData, color: AppColors.secondaryTeal, size: 18),
                              ),
                              title: Text(
                                stat['title'] as String,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              subtitle: Text(
                                stat['sub'] as String,
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _stickers.add(
                                    _StickerOverlayItem(
                                      content: stat['title'] as String,
                                      subtitle: stat['sub'] as String,
                                      type: StickerType.campusPill,
                                      icon: stat['icon'] as IconData,
                                      position: const Offset(60, 260),
                                    ),
                                  );
                                  _history.add(_EditorAction(_EditorActionType.sticker));
                                });
                                Navigator.pop(ctx);
                              },
                            )),
                      ],
                    ),

                    // Tab 2: Live Time & Date Stickers
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Live Clock & Calendar Badges',
                            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _stickers.add(
                                  _StickerOverlayItem(
                                    content: _getCurrentTimeFormatted(),
                                    type: StickerType.timePill,
                                    icon: Icons.schedule_rounded,
                                    position: const Offset(100, 240),
                                  ),
                                );
                                _history.add(_EditorAction(_EditorActionType.sticker));
                              });
                              Navigator.pop(ctx);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: const Color(0xFF27272A),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.schedule_rounded, color: AppColors.secondaryTeal, size: 28),
                                  const SizedBox(width: 12),
                                  Text(
                                    _getCurrentTimeFormatted(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _stickers.add(
                                  _StickerOverlayItem(
                                    content: _getCurrentDateFormatted(),
                                    type: StickerType.datePill,
                                    icon: Icons.calendar_today_rounded,
                                    position: const Offset(80, 240),
                                  ),
                                );
                                _history.add(_EditorAction(_EditorActionType.sticker));
                              });
                              Navigator.pop(ctx);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: const Color(0xFF27272A),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.calendar_today_rounded, color: Color(0xFF8B5CF6), size: 24),
                                  const SizedBox(width: 12),
                                  Text(
                                    _getCurrentDateFormatted(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Tab 3: Emojis Grid
                    GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                      ),
                      itemCount: emojis.length,
                      itemBuilder: (context, i) => GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _stickers.add(
                              _StickerOverlayItem(
                                content: emojis[i],
                                type: StickerType.emoji,
                                position: const Offset(120, 200),
                              ),
                            );
                            _history.add(_EditorAction(_EditorActionType.sticker));
                          });
                          Navigator.pop(ctx);
                        },
                        child: Center(
                          child: Text(emojis[i], style: const TextStyle(fontSize: 32)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Close / Discard Confirmation ─────────────────────────────────────────

  Future<void> _confirmDiscard() async {
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Discard Snap?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'If you go back now, your captured media and edits will be discarded.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B30),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldDiscard == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    double targetWidth = screenSize.width;
    double targetHeight = screenSize.height;

    if (widget.aspectRatio != null) {
      final calculatedHeight = screenSize.width / widget.aspectRatio!;
      if (calculatedHeight <= screenSize.height) {
        targetWidth = screenSize.width;
        targetHeight = calculatedHeight;
      } else {
        targetHeight = screenSize.height;
        targetWidth = screenSize.height * widget.aspectRatio!;
      }
    }

    final canvasSize = Size(targetWidth, targetHeight);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1-4. Composite Render Tree for Exporting (Framed in chosen aspect ratio)
          Center(
            child: SizedBox(
              width: targetWidth,
              height: targetHeight,
              child: ClipRect(
                child: RepaintBoundary(
                  key: _previewStackKey,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 1. Fullscreen Media Canvas (Image or Video)
                      GestureDetector(
                        onTap: () {
                          if (_isTextEditing) _submitText();
                        },
                        child: _buildMediaView(canvasSize),
                      ),

                // 2. Custom Drawing Canvas
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: !_isDrawingMode,
                    child: GestureDetector(
                      onPanStart: (details) {
                        setState(() {
                          _strokes.add(
                            _DoodleStroke(
                              points: [details.localPosition],
                              color: _selectedDrawColor,
                              strokeWidth: _strokeWidth,
                            ),
                          );
                          _history.add(_EditorAction(_EditorActionType.stroke));
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
                        painter: _DoodlePainter(strokes: _strokes),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                ),

                // 3. Draggable & Removable Sticker Overlays
                ..._stickers.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return Positioned(
                    left: item.position.dx,
                    top: item.position.dy,
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        setState(() {
                          item.position += details.delta;
                        });
                      },
                      onDoubleTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _stickers.removeAt(index);
                        });
                      },
                      child: _buildStickerWidget(item),
                    ),
                  );
                }),

                // 4. Draggable & Tap-to-Edit Text Overlays
                ..._textOverlays.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return Positioned(
                    left: item.position.dx,
                    top: item.position.dy,
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        setState(() {
                          item.position += details.delta;
                        });
                      },
                      onTap: () {
                        _openTextDialog(index);
                      },
                      child: _buildTextOverlayWidget(item),
                    ),
                  );
                }),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 5. Top Left Action: Discard / Close
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: _buildFrostedCircleButton(
              icon: Icons.close_rounded,
              onTap: _confirmDiscard,
            ),
          ),

          // 6. Top Center Audio Mute Toggle (for video)
          if (widget.isVideo)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: screenSize.width / 2 - 22,
              child: _buildFrostedCircleButton(
                icon: _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _isMuted = !_isMuted;
                    _videoController?.setVolume(_isMuted ? 0.0 : 1.0);
                  });
                },
              ),
            ),

          // 6.5 Floating Music Tag Pill (if sound selected)
          if (_selectedAudioTrack != null && !_isTextEditing && !_isDrawingMode)
            Positioned(
              top: MediaQuery.of(context).padding.top + 14,
              left: 70,
              right: 70,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.music_note_rounded, color: AppColors.secondaryTeal, size: 16),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${_selectedAudioTrack!.title} · ${_selectedAudioTrack!.artist}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _removeBackgroundMusic,
                            child: const Icon(Icons.close_rounded, color: Colors.white70, size: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 7. Right Floating Editing Toolbar (Snapchat Style)
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: _buildFloatingEditorToolbar(),
          ),

          // 8. Color Palette for Drawing Mode
          if (_isDrawingMode)
            Positioned(
              left: 16,
              right: 16,
              bottom: 120,
              child: _buildColorPaletteRow(),
            ),

          // 9. Fullscreen Text Input Overlay
          if (_isTextEditing)
            Positioned.fill(
              child: _buildTextInputOverlay(),
            ),

          // 9.5 Filter Selection Carousel
          if (_showFilterPanel && !_isTextEditing && !_isDrawingMode)
            Positioned(
              left: 0,
              right: 0,
              bottom: 84 + MediaQuery.of(context).padding.bottom,
              child: _buildFilterCarousel(),
            ),

          // 10. Bottom Action Bar: [Save] [My Story] [Send to... ➔]
          if (!_isTextEditing && !_isDrawingMode)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomActionBar(),
            ),
        ],
      ),
    );
  }

  // ── Media View Widget ─────────────────────────────────────────────────────

  Widget _buildMediaView(Size screenSize) {
    Widget content;
    if (widget.isVideo) {
      if (_isVideoInitialized && _videoController != null) {
        content = SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _videoController!.value.size.width,
              height: _videoController!.value.size.height,
              child: VideoPlayer(_videoController!),
            ),
          ),
        );
      } else {
        return const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        );
      }
    } else if (_mediaBytes != null) {
      content = Image.memory(
        _mediaBytes!,
        fit: BoxFit.cover,
        width: screenSize.width,
        height: screenSize.height,
      );
    } else if (!kIsWeb && File(widget.mediaFile.path).existsSync()) {
      content = Image.file(
        File(widget.mediaFile.path),
        fit: BoxFit.cover,
        width: screenSize.width,
        height: screenSize.height,
      );
    } else {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      );
    }

    final activeMatrix = _currentMatrix ?? widget.colorMatrix;
    if (activeMatrix != null) {
      return ColorFiltered(
        colorFilter: ColorFilter.matrix(activeMatrix),
        child: content,
      );
    }
    return content;
  }

  // ── Floating Editor Toolbar (Right Side) ──────────────────────────────────

  Widget _buildFloatingEditorToolbar() {
    final canUndo = _history.isNotEmpty || _strokes.isNotEmpty || _stickers.isNotEmpty || _textOverlays.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.38),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white12, width: 0.8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Aa Text Tool
              _buildToolButton(
                iconWidget: const Text(
                  'Aa',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                onTap: () => _openTextDialog(),
              ),
              const SizedBox(height: 12),

              // Pen / Draw Tool
              _buildToolButton(
                iconWidget: Icon(
                  Icons.edit_outlined,
                  color: _isDrawingMode ? AppColors.secondaryTeal : Colors.white,
                  size: 20,
                ),
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _isDrawingMode = !_isDrawingMode;
                    if (_isDrawingMode) _showFilterPanel = false;
                  });
                },
              ),
              const SizedBox(height: 12),

              // Sticker Tool (3-Tab Studio)
              _buildToolButton(
                iconWidget: const Icon(Icons.sticky_note_2_outlined, color: Colors.white, size: 20),
                onTap: _openStickerSheet,
              ),
              const SizedBox(height: 12),

              // Filter Tool (Magic Wand / Carousel)
              _buildToolButton(
                iconWidget: Icon(
                  Icons.auto_awesome_rounded,
                  color: _showFilterPanel || _selectedFilterIndex > 0 ? const Color(0xFF8B5CF6) : Colors.white,
                  size: 20,
                ),
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _showFilterPanel = !_showFilterPanel;
                    if (_showFilterPanel) _isDrawingMode = false;
                  });
                },
              ),
              const SizedBox(height: 12),

              // Snap Viewing Duration Timer
              _buildToolButton(
                iconWidget: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.timer_outlined, color: Colors.white, size: 20),
                    if (_snapDurationSeconds > 0)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${_snapDurationSeconds}s',
                            style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
                onTap: _openDurationPicker,
              ),
              const SizedBox(height: 12),

              // Unified Undo Action
              if (canUndo) ...[
                _buildToolButton(
                  iconWidget: const Icon(Icons.undo_rounded, color: Colors.white, size: 20),
                  onTap: _handleUndo,
                ),
                const SizedBox(height: 12),
              ],

              // Sound / Music
              _buildToolButton(
                iconWidget: Icon(
                  Icons.music_note_rounded,
                  color: _selectedAudioTrack != null ? AppColors.secondaryTeal : Colors.white,
                  size: 20,
                ),
                onTap: () async {
                  HapticFeedback.lightImpact();
                  final selected = await MusicPickerSheet.show(context);
                  if (selected != null && mounted) {
                    setState(() => _selectedAudioTrack = selected);
                    _playBackgroundMusic(selected);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolButton({required Widget iconWidget, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: Center(child: iconWidget),
      ),
    );
  }

  // ── Color Palette for Drawing ─────────────────────────────────────────────

  Widget _buildColorPaletteRow() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ..._palette.map((color) => GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedDrawColor = color);
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _selectedDrawColor == color ? Colors.white : Colors.white24,
                          width: _selectedDrawColor == color ? 2.5 : 1,
                        ),
                      ),
                    ),
                  )),
              IconButton(
                icon: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                onPressed: () => setState(() => _isDrawingMode = false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Fullscreen Text Input Overlay ─────────────────────────────────────────

  // ── Fullscreen Professional Typography Studio ────────────────────────────

  Widget _buildTextInputOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.88),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SafeArea(
        child: Column(
          children: [
            // Top Controls Bar: Delete / Cancel, Background Cycle, Align Cycle, Done
            Row(
              children: [
                if (_editingTextIndex != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF3B30), size: 24),
                    onPressed: _deleteEditingText,
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 24),
                    onPressed: () {
                      _textController.clear();
                      setState(() {
                        _editingTextIndex = null;
                        _isTextEditing = false;
                      });
                    },
                  ),
                const Spacer(),

                // Background Style Cycle Toggle
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      switch (_selectedTextBg) {
                        case TextBackgroundType.transparent:
                          _selectedTextBg = TextBackgroundType.frosted;
                          break;
                        case TextBackgroundType.frosted:
                          _selectedTextBg = TextBackgroundType.pill;
                          break;
                        case TextBackgroundType.pill:
                          _selectedTextBg = TextBackgroundType.outline;
                          break;
                        case TextBackgroundType.outline:
                          _selectedTextBg = TextBackgroundType.transparent;
                          break;
                      }
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _selectedTextBg == TextBackgroundType.transparent
                              ? Icons.format_color_reset_rounded
                              : (_selectedTextBg == TextBackgroundType.frosted
                                  ? Icons.blur_on_rounded
                                  : (_selectedTextBg == TextBackgroundType.pill
                                      ? Icons.rectangle_rounded
                                      : Icons.border_color_rounded)),
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _selectedTextBg.name.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),

                // Text Alignment Cycle Toggle
                IconButton(
                  icon: Icon(
                    _selectedTextAlign == TextAlign.center
                        ? Icons.format_align_center_rounded
                        : (_selectedTextAlign == TextAlign.left
                            ? Icons.format_align_left_rounded
                            : Icons.format_align_right_rounded),
                    color: Colors.white,
                    size: 22,
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      if (_selectedTextAlign == TextAlign.center) {
                        _selectedTextAlign = TextAlign.left;
                      } else if (_selectedTextAlign == TextAlign.left) {
                        _selectedTextAlign = TextAlign.right;
                      } else {
                        _selectedTextAlign = TextAlign.center;
                      }
                    });
                  },
                ),

                const SizedBox(width: 4),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onPressed: _submitText,
                  child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ],
            ),

            const Spacer(),

            // Interactive Text Canvas with selected styling & live background preview
            Center(
              child: _buildStyledTextPreview(
                text: _textController.text.isEmpty ? 'Type something...' : _textController.text,
                color: _selectedTextColor,
                child: TextField(
                  controller: _textController,
                  autofocus: true,
                  textAlign: _selectedTextAlign,
                  style: _selectedTextStyle.getTextStyle().copyWith(color: _selectedTextColor),
                  maxLines: 4,
                  minLines: 1,
                  decoration: const InputDecoration(
                    hintText: 'Type a caption...',
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _submitText(),
                ),
              ),
            ),

            const Spacer(),

            // Font Style Selection Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: TextStyleType.values.map((type) {
                  final isSelected = _selectedTextStyle == type;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedTextStyle = type);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFF27272A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.white12,
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        type.name.toUpperCase(),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 14),

            // Color Palette Selector Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _palette.map((color) {
                  final isSelected = _selectedTextColor == color;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedTextColor = color);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.white24,
                          width: isSelected ? 2.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? [const BoxShadow(color: Colors.white38, blurRadius: 6)]
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStyledTextPreview({
    required String text,
    required Color color,
    required Widget child,
  }) {
    switch (_selectedTextBg) {
      case TextBackgroundType.transparent:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: child,
        );
      case TextBackgroundType.pill:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
          ),
          child: child,
        );
      case TextBackgroundType.outline:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.8), width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: child,
        );
      case TextBackgroundType.frosted:
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white24, width: 0.8),
              ),
              child: child,
            ),
          ),
        );
    }
  }

  // ── Filter Carousel Widget ────────────────────────────────────────────────

  Widget _buildFilterCarousel() {
    return Container(
      height: 94,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white12),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: kEditorFilters.length,
              itemBuilder: (context, i) {
                final filter = kEditorFilters[i];
                final isSelected = _selectedFilterIndex == i;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedFilterIndex = i;
                      _currentMatrix = filter.matrix;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF8B5CF6).withValues(alpha: 0.4)
                          : const Color(0xFF27272A).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF8B5CF6) : Colors.white12,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          filter.icon,
                          color: isSelected ? Colors.white : Colors.white70,
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          filter.name,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ── Sticker Widget Builder ────────────────────────────────────────────────

  Widget _buildStickerWidget(_StickerOverlayItem item) {
    if (item.type == StickerType.emoji) {
      return Container(
        padding: const EdgeInsets.all(4),
        child: Text(item.content, style: const TextStyle(fontSize: 48)),
      );
    }

    if (item.type == StickerType.timePill || item.type == StickerType.datePill) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.icon ?? (item.type == StickerType.timePill ? Icons.schedule_rounded : Icons.calendar_today_rounded),
                  color: item.type == StickerType.timePill ? AppColors.secondaryTeal : const Color(0xFF8B5CF6),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  item.content,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Campus Pill
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E24).withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.icon != null) ...[
                Icon(item.icon, color: const Color(0xFF8B5CF6), size: 18),
                const SizedBox(width: 8),
              ],
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.content,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (item.subtitle != null)
                    Text(
                      item.subtitle!,
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Text Overlay Widget Builder ───────────────────────────────────────────

  Widget _buildTextOverlayWidget(_TextOverlayItem item) {
    final baseStyle = item.getTextStyle();

    switch (item.bgType) {
      case TextBackgroundType.transparent:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            item.text,
            textAlign: item.align,
            style: baseStyle.copyWith(
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.8),
                  blurRadius: 8,
                  offset: const Offset(1, 1),
                ),
              ],
            ),
          ),
        );
      case TextBackgroundType.pill:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            item.text,
            textAlign: item.align,
            style: baseStyle,
          ),
        );
      case TextBackgroundType.outline:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Stack(
            children: [
              Text(
                item.text,
                textAlign: item.align,
                style: baseStyle.copyWith(
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 3
                    ..color = Colors.black,
                ),
              ),
              Text(
                item.text,
                textAlign: item.align,
                style: baseStyle,
              ),
            ],
          ),
        );
      case TextBackgroundType.frosted:
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white24, width: 0.8),
              ),
              child: Text(
                item.text,
                textAlign: item.align,
                style: baseStyle,
              ),
            ),
          ),
        );
    }
  }

  // ── Bottom Action Bar (Save, My Story, Send to... ➔) ───────────────────────

  Widget _buildBottomActionBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.85),
            Colors.black.withValues(alpha: 0.0),
          ],
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 14,
        top: 24,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Save Button (Real Gallery Save)
          _buildPillAction(
            icon: _isSaved ? Icons.check_rounded : Icons.file_download_outlined,
            label: _isSaved ? 'Saved' : 'Save',
            isLoading: _isSaving,
            onTap: _handleSave,
          ),

          if (widget.cameraContext == CameraContext.post) ...[
            // Post Flow: [Add to Post ➔]
            GestureDetector(
              onTap: _handleAddToPost,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0x666366F1), blurRadius: 12, offset: Offset(0, 4)),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Add to Post',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.check_rounded, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
          ] else if (widget.cameraContext == CameraContext.story) ...[
            // Story Flow: [Add to Story]
            GestureDetector(
              onTap: _handleMyStory,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0x668B5CF6), blurRadius: 12, offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isPostingStory)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    else
                      const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Add to Story',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Snap Flow: [My Story] and [Send to... ➔]
            _buildPillAction(
              icon: Icons.add_circle_outline_rounded,
              label: 'My Story',
              isLoading: _isPostingStory,
              onTap: _handleMyStory,
            ),

            GestureDetector(
              onTap: () {
                if (widget.directRecipientId != null) {
                  _sendSnapToRecipient(
                    AppUser(
                      uid: widget.directRecipientId!,
                      email: '',
                      displayName: widget.directRecipientName ?? 'Friend',
                      handle: widget.directRecipientName?.toLowerCase().replaceAll(' ', '') ?? 'friend',
                    ),
                  );
                } else {
                  _openSendToSheet();
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.directRecipientName != null
                        ? 'Send to ${widget.directRecipientName}'
                        : 'Send to...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x668B5CF6),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 24),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPillAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: GestureDetector(
          onTap: isLoading ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white24, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                else
                  Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFrostedCircleButton({required IconData icon, required VoidCallback onTap}) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

// ── Models & Custom Painters ────────────────────────────────────────────────

enum _EditorActionType { stroke, sticker, text }

class _EditorAction {
  final _EditorActionType type;
  _EditorAction(this.type);
}

class _DoodleStroke {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  _DoodleStroke({required this.points, required this.color, required this.strokeWidth});
}

class _DoodlePainter extends CustomPainter {
  final List<_DoodleStroke> strokes;

  _DoodlePainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.points.length == 1) {
        canvas.drawCircle(stroke.points.first, stroke.strokeWidth / 2, paint);
      } else {
        final path = Path()..moveTo(stroke.points[0].dx, stroke.points[0].dy);
        for (int i = 1; i < stroke.points.length; i++) {
          path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DoodlePainter oldDelegate) => true;
}

enum TextStyleType { modern, bold, classic, serif, cursive, mono }
enum TextBackgroundType { transparent, pill, frosted, outline }

extension TextStyleTypeExtension on TextStyleType {
  TextStyle getTextStyle({Color? color}) {
    switch (this) {
      case TextStyleType.classic:
        return TextStyle(
          color: color,
          fontSize: 22,
          fontWeight: FontWeight.normal,
          fontFamily: 'Roboto',
        );
      case TextStyleType.bold:
        return TextStyle(
          color: color,
          fontSize: 26,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        );
      case TextStyleType.serif:
        return TextStyle(
          color: color,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          fontFamily: 'Georgia',
        );
      case TextStyleType.cursive:
        return TextStyle(
          color: color,
          fontSize: 24,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic,
        );
      case TextStyleType.mono:
        return TextStyle(
          color: color,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: 'Courier',
        );
      case TextStyleType.modern:
        return TextStyle(
          color: color,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        );
    }
  }
}

class _TextOverlayItem {
  String text;
  Color color;
  Offset position;
  TextStyleType styleType;
  TextBackgroundType bgType;
  TextAlign align;

  _TextOverlayItem({
    required this.text,
    required this.color,
    required this.position,
    this.styleType = TextStyleType.modern,
    this.bgType = TextBackgroundType.frosted,
    this.align = TextAlign.center,
  });

  TextStyle getTextStyle() => styleType.getTextStyle(color: color);
}

enum StickerType { emoji, campusPill, timePill, datePill }

class _StickerOverlayItem {
  final String content;
  final String? subtitle;
  final StickerType type;
  final IconData? icon;
  Offset position;

  _StickerOverlayItem({
    required this.content,
    this.subtitle,
    this.type = StickerType.emoji,
    this.icon,
    required this.position,
  });
}

class EditorFilter {
  final String name;
  final List<double>? matrix;
  final IconData icon;

  const EditorFilter({required this.name, this.matrix, required this.icon});
}

const List<EditorFilter> kEditorFilters = [
  EditorFilter(name: 'Normal', matrix: null, icon: Icons.auto_fix_normal_rounded),
  EditorFilter(
    name: 'Campus',
    icon: Icons.school_rounded,
    matrix: [
      1.15, 0.0, 0.0, 0.0, 5.0,
      0.0, 1.15, 0.0, 0.0, 5.0,
      0.0, 0.0, 1.10, 0.0, 0.0,
      0.0, 0.0, 0.0, 1.0, 0.0,
    ],
  ),
  EditorFilter(
    name: 'Warm',
    icon: Icons.wb_sunny_rounded,
    matrix: [
      1.2, 0.0, 0.0, 0.0, 15.0,
      0.0, 1.05, 0.0, 0.0, 5.0,
      0.0, 0.0, 0.9, 0.0, -10.0,
      0.0, 0.0, 0.0, 1.0, 0.0,
    ],
  ),
  EditorFilter(
    name: 'Cool',
    icon: Icons.ac_unit_rounded,
    matrix: [
      0.9, 0.0, 0.0, 0.0, -10.0,
      0.0, 1.0, 0.0, 0.0, 5.0,
      0.0, 0.0, 1.25, 0.0, 20.0,
      0.0, 0.0, 0.0, 1.0, 0.0,
    ],
  ),
  EditorFilter(
    name: 'Vintage',
    icon: Icons.camera_roll_rounded,
    matrix: [
      0.9, 0.2, 0.1, 0.0, 20.0,
      0.1, 0.8, 0.1, 0.0, 15.0,
      0.1, 0.1, 0.6, 0.0, -10.0,
      0.0, 0.0, 0.0, 1.0, 0.0,
    ],
  ),
  EditorFilter(
    name: 'B&W',
    icon: Icons.filter_b_and_w_rounded,
    matrix: [
      0.33, 0.33, 0.33, 0.0, 0.0,
      0.33, 0.33, 0.33, 0.0, 0.0,
      0.33, 0.33, 0.33, 0.0, 0.0,
      0.0, 0.0, 0.0, 1.0, 0.0,
    ],
  ),
  EditorFilter(
    name: 'Cinematic',
    icon: Icons.movie_filter_rounded,
    matrix: [
      1.1, 0.0, 0.0, 0.0, 10.0,
      0.0, 1.1, 0.0, 0.0, -5.0,
      0.0, 0.0, 1.3, 0.0, 15.0,
      0.0, 0.0, 0.0, 1.0, 0.0,
    ],
  ),
  EditorFilter(
    name: 'Glow',
    icon: Icons.flare_rounded,
    matrix: [
      1.25, 0.0, 0.0, 0.0, 20.0,
      0.0, 1.25, 0.0, 0.0, 20.0,
      0.0, 0.0, 1.25, 0.0, 20.0,
      0.0, 0.0, 0.0, 1.0, 0.0,
    ],
  ),
];

// ── Send to Friends Bottom Sheet ─────────────────────────────────────────────

class _SendToSheet extends ConsumerStatefulWidget {
  final Function(List<AppUser> recipients, bool postToStory) onSend;

  const _SendToSheet({required this.onSend});

  @override
  ConsumerState<_SendToSheet> createState() => _SendToSheetState();
}

class _SendToSheetState extends ConsumerState<_SendToSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  final Map<String, AppUser> _selectedUsers = {};
  bool _postToMyStory = false;
  String _query = '';
  List<AppUser> _directoryResults = [];
  bool _isSearchingDirectory = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUser = ref.read(currentUserProvider).value ?? ref.read(authRepositoryProvider).currentUser;
      final currentUserId = (currentUser?.uid != null && currentUser!.uid.isNotEmpty) ? currentUser.uid : 'me';
      ref.invalidate(followingProvider(currentUserId));
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    final trimmed = val.trim();
    setState(() => _query = trimmed.toLowerCase());

    _debounce?.cancel();
    if (trimmed.length >= 2) {
      _debounce = Timer(const Duration(milliseconds: 300), () async {
        setState(() => _isSearchingDirectory = true);
        try {
          final results = await ref.read(userRepositoryProvider).searchUsers(trimmed);
          if (mounted) {
            setState(() {
              _directoryResults = results;
              _isSearchingDirectory = false;
            });
          }
        } catch (_) {
          if (mounted) setState(() => _isSearchingDirectory = false);
        }
      });
    } else {
      setState(() => _directoryResults = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).value ?? ref.watch(authRepositoryProvider).currentUser;
    final currentUserId = (currentUser?.uid != null && currentUser!.uid.isNotEmpty) ? currentUser.uid : 'me';
    final followingAsync = ref.watch(followingProvider(currentUserId));
    final suggestionsAsync = ref.watch(peopleYouMayKnowProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.45,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF18181B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.send_rounded, color: Color(0xFF8B5CF6), size: 22),
                const SizedBox(width: 10),
                const Text(
                  'Send Snap To...',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_selectedUsers.isNotEmpty || _postToMyStory)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _postToMyStory && _selectedUsers.isNotEmpty
                          ? 'Story + ${_selectedUsers.length} Friends'
                          : _postToMyStory
                              ? 'My Story'
                              : '${_selectedUsers.length} selected',
                      style: const TextStyle(
                        color: Color(0xFF8B5CF6),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            // My Story 24h Destination Tile
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _postToMyStory = !_postToMyStory);
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _postToMyStory
                      ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                      : const Color(0xFF27272A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _postToMyStory ? const Color(0xFF8B5CF6) : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                        ),
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Story (24h)',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Separate 24-hour expiration for all friends',
                            style: TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _postToMyStory ? const Color(0xFF8B5CF6) : Colors.transparent,
                        border: Border.all(
                          color: _postToMyStory ? const Color(0xFF8B5CF6) : Colors.white38,
                          width: 2,
                        ),
                      ),
                      child: _postToMyStory
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Search field
            TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search friends or classmates...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white38),
                suffixIcon: _isSearchingDirectory
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF8B5CF6)),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF27272A),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Friends List / Directory Search
            Expanded(
              child: followingAsync.when(
                data: (friends) {
                  // If searching: combine local following matches and directory search results
                  if (_query.isNotEmpty) {
                    final matchingFollowing = friends.where((f) =>
                        f.displayName.toLowerCase().contains(_query) ||
                        f.handle.toLowerCase().contains(_query)).toList();

                    final combinedMap = <String, AppUser>{};
                    for (final u in matchingFollowing) {
                      combinedMap[u.uid] = u;
                    }
                    for (final u in _directoryResults) {
                      if (u.uid != currentUser?.uid) {
                        combinedMap[u.uid] = u;
                      }
                    }
                    final combined = combinedMap.values.toList();

                    if (combined.isEmpty && !_isSearchingDirectory) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off_rounded, color: Colors.white38, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'No classmates found matching "$_query"',
                              style: const TextStyle(color: Colors.white54, fontSize: 14),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: scrollController,
                      itemCount: combined.length,
                      separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (context, i) {
                        final user = combined[i];
                        return _buildUserTile(user);
                      },
                    );
                  }

                  // If not searching and user has following
                  if (friends.isNotEmpty) {
                    return ListView.separated(
                      controller: scrollController,
                      itemCount: friends.length,
                      separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (context, i) {
                        final friend = friends[i];
                        return _buildUserTile(friend);
                      },
                    );
                  }

                  // If following is empty: show suggested classmates so user can immediately snap
                  return suggestionsAsync.when(
                    data: (suggestions) {
                      final suggestedUsers = suggestions
                          .map((s) => s.user)
                          .where((u) => u.uid != currentUser?.uid)
                          .toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF27272A),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.tips_and_updates_rounded, color: Colors.amberAccent, size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Select classmates below to send direct snaps!',
                                    style: TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Suggested Classmates',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView.separated(
                              controller: scrollController,
                              itemCount: suggestedUsers.length,
                              separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                              itemBuilder: (context, i) {
                                final student = suggestedUsers[i];
                                return _buildUserTile(student);
                              },
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                    ),
                    error: (_, _) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.people_outline_rounded, color: Colors.white38, size: 48),
                          const SizedBox(height: 12),
                          const Text(
                            'Search any student or friend above',
                            style: TextStyle(color: Colors.white54, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                ),
                error: (e, _) => Center(
                  child: Text('Error: $e', style: const TextStyle(color: Colors.white54)),
                ),
              ),
            ),
            if (_selectedUsers.isNotEmpty || _postToMyStory)
              Container(
                padding: const EdgeInsets.only(top: 12, bottom: 6),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                      elevation: 4,
                    ),
                    icon: const Icon(Icons.send_rounded, size: 20),
                    label: Text(
                      _postToMyStory && _selectedUsers.isNotEmpty
                          ? 'Send Snap & Add to Story 🔥'
                          : _postToMyStory
                              ? 'Add to My Story (24h) 🔥'
                              : 'Send Snap to ${_selectedUsers.length} ${_selectedUsers.length == 1 ? "Friend" : "Friends"} 🔥',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    onPressed: () {
                      widget.onSend(_selectedUsers.values.toList(), _postToMyStory);
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserTile(AppUser user) {
    final isSelected = _selectedUsers.containsKey(user.uid);
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          if (isSelected) {
            _selectedUsers.remove(user.uid);
          } else {
            _selectedUsers[user.uid] = user;
          }
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white10,
              backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                  ? CachedNetworkImageProvider(user.avatarUrl!)
                  : null,
              child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                  ? Text(
                      user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'U',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${user.handle}',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? const Color(0xFF8B5CF6) : Colors.transparent,
                border: Border.all(
                  color: isSelected ? const Color(0xFF8B5CF6) : Colors.white38,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
