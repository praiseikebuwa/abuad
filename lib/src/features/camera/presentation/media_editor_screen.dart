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

  // Drawing state
  bool _isDrawingMode = false;
  final List<_DoodleStroke> _strokes = [];
  Color _selectedDrawColor = Colors.white;
  final double _strokeWidth = 4.0;

  // Text overlay state
  bool _isTextEditing = false;
  final TextEditingController _textController = TextEditingController();
  final List<_TextOverlayItem> _textOverlays = [];
  Color _selectedTextColor = Colors.white;

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
    if (widget.initialAudioTrack != null) {
      _selectedAudioTrack = widget.initialAudioTrack;
      _playBackgroundMusic(widget.initialAudioTrack!);
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

    try {
      final boundary = _previewStackKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return widget.mediaFile;

      final ui.Image image = await boundary.toImage(pixelRatio: 2.5);
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
                Text(
                  success
                      ? (widget.isVideo ? 'Video saved to Gallery' : 'Photo saved to Gallery')
                      : 'Could not save to Gallery',
                  style: const TextStyle(fontWeight: FontWeight.w600),
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
            duration: 10,
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

  void _openTextDialog() {
    HapticFeedback.lightImpact();
    setState(() => _isTextEditing = true);
  }

  void _submitText() {
    if (_textController.text.trim().isNotEmpty) {
      setState(() {
        _textOverlays.add(
          _TextOverlayItem(
            text: _textController.text.trim(),
            color: _selectedTextColor,
            position: const Offset(50, 250),
          ),
        );
        _textController.clear();
        _isTextEditing = false;
      });
    } else {
      setState(() => _isTextEditing = false);
    }
  }

  // ── Sticker / Emoji Sheet ────────────────────────────────────────────────

  void _openStickerSheet() {
    HapticFeedback.lightImpact();
    final emojis = [
      '🔥', '❤️', '😂', '🎉', '💯', '👻', '🎓', '⚡', '🌟', '👑',
      '👀', '✨', '👏', '🥳', '😎', '📚', '🍕', '☕', '🚀', '💜',
      '🤩', '🙌', '💪', '🎯', '📍', '💡', '🏆', '📸', '🎵', '☀️',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 14),
              const Text(
                'Add Sticker or Emoji',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
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
                          emoji: emojis[i],
                          position: const Offset(120, 200),
                        ),
                      );
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

                // 3. Draggable Sticker Overlays
                ..._stickers.map((item) {
                  return Positioned(
                    left: item.position.dx,
                    top: item.position.dy,
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        setState(() {
                          item.position += details.delta;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: Text(item.emoji, style: const TextStyle(fontSize: 48)),
                      ),
                    ),
                  );
                }),

                // 4. Draggable Text Overlays
                ..._textOverlays.map((item) {
                  return Positioned(
                    left: item.position.dx,
                    top: item.position.dy,
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        setState(() {
                          item.position += details.delta;
                        });
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white24, width: 0.8),
                            ),
                            child: Text(
                              item.text,
                              style: TextStyle(
                                color: item.color,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
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
    if (widget.isVideo) {
      if (_isVideoInitialized && _videoController != null) {
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _videoController!.value.size.width,
              height: _videoController!.value.size.height,
              child: VideoPlayer(_videoController!),
            ),
          ),
        );
      }
      return const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      );
    }

    if (_mediaBytes != null) {
      return Image.memory(
        _mediaBytes!,
        fit: BoxFit.cover,
        width: screenSize.width,
        height: screenSize.height,
      );
    }

    if (!kIsWeb && File(widget.mediaFile.path).existsSync()) {
      return Image.file(
        File(widget.mediaFile.path),
        fit: BoxFit.cover,
        width: screenSize.width,
        height: screenSize.height,
      );
    }

    return const Center(
      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
    );
  }

  // ── Floating Editor Toolbar (Right Side) ──────────────────────────────────

  Widget _buildFloatingEditorToolbar() {
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
                onTap: _openTextDialog,
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
                  setState(() => _isDrawingMode = !_isDrawingMode);
                },
              ),
              const SizedBox(height: 12),

              // Sticker Tool
              _buildToolButton(
                iconWidget: const Icon(Icons.sticky_note_2_outlined, color: Colors.white, size: 20),
                onTap: _openStickerSheet,
              ),
              const SizedBox(height: 12),

              // Undo Stroke (if drawing exists)
              if (_strokes.isNotEmpty) ...[
                _buildToolButton(
                  iconWidget: const Icon(Icons.undo_rounded, color: Colors.white, size: 20),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _strokes.removeLast());
                  },
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

  Widget _buildTextInputOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _submitText,
                child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            ),
            const Spacer(),
            TextField(
              controller: _textController,
              autofocus: true,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _selectedTextColor,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                hintText: 'Type a caption...',
                hintStyle: TextStyle(color: Colors.white38),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _submitText(),
            ),
            const Spacer(),
            // Text color selector
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _palette.map((color) {
                  return GestureDetector(
                    onTap: () => setState(() => _selectedTextColor = color),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _selectedTextColor == color ? Colors.white : Colors.white24,
                          width: 2,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
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

class _TextOverlayItem {
  String text;
  Color color;
  Offset position;

  _TextOverlayItem({required this.text, required this.color, required this.position});
}

class _StickerOverlayItem {
  final String emoji;
  Offset position;

  _StickerOverlayItem({required this.emoji, required this.position});
}

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
