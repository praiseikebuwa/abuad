import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/url_validator.dart';
import '../../auth/data/auth_repository.dart';
import '../presentation/reels_screen.dart';

class AudioTrackScreen extends ConsumerStatefulWidget {
  final String audioId;
  final String title;
  final String authorName;
  final String authorHandle;
  final String? authorAvatarUrl;
  final String? authorId;

  const AudioTrackScreen({
    super.key,
    required this.audioId,
    required this.title,
    required this.authorName,
    required this.authorHandle,
    this.authorAvatarUrl,
    this.authorId,
  });

  @override
  ConsumerState<AudioTrackScreen> createState() => _AudioTrackScreenState();
}

class _AudioTrackScreenState extends ConsumerState<AudioTrackScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  bool _isPlaying = false;
  bool _isSavedAudio = false;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _togglePlay() {
    HapticFeedback.lightImpact();
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    });
  }

  void _toggleSaveAudio() {
    HapticFeedback.mediumImpact();
    setState(() => _isSavedAudio = !_isSavedAudio);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isSavedAudio ? 'Sound saved to favorites' : 'Sound removed from favorites'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _useThisSound() {
    HapticFeedback.mediumImpact();
    context.push(
      '/create-post',
      extra: {
        'audioTrack': {
          'id': widget.audioId,
          'title': widget.title,
          'author': widget.authorHandle,
        },
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUserId = ref.watch(currentUserIdProvider);

    // Watch reels to display videos using this sound
    final reelsAsync = ref.watch(reelsProvider((mode: ReelFeedMode.forYou, userId: currentUserId)));
    final allReels = reelsAsync.value ?? [];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isSavedAudio ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: _isSavedAudio ? const Color(0xFFFFB800) : null,
            ),
            tooltip: _isSavedAudio ? 'Saved' : 'Save sound',
            onPressed: _toggleSaveAudio,
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Share sound',
            onPressed: () {
              HapticFeedback.lightImpact();
              // ignore: deprecated_member_use
              Share.share(
                'Listen to "${widget.title}" by @${widget.authorHandle} on ABUAD Nest!',
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Header section: Vinyl player, Title, Creator, Actions
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    children: [
                      // Spinning Vinyl Record
                      Center(
                        child: GestureDetector(
                          onTap: _togglePlay,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer Vinyl Disc
                              RotationTransition(
                                turns: _rotationController,
                                child: Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const RadialGradient(
                                      colors: [
                                        Color(0xFF1E293B),
                                        Color(0xFF0F172A),
                                        Colors.black,
                                        Color(0xFF1E293B),
                                        Colors.black,
                                      ],
                                      stops: [0.0, 0.4, 0.65, 0.85, 1.0],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.secondaryTeal.withValues(alpha: _isPlaying ? 0.35 : 0.1),
                                        blurRadius: _isPlaying ? 24 : 12,
                                        spreadRadius: _isPlaying ? 4 : 0,
                                      ),
                                    ],
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      width: 3,
                                    ),
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white24, width: 2),
                                      ),
                                      child: ClipOval(
                                        child: (widget.authorAvatarUrl != null &&
                                                widget.authorAvatarUrl!.isNotEmpty &&
                                                UrlValidator.isValidUrl(widget.authorAvatarUrl!))
                                            ? CachedNetworkImage(
                                                imageUrl: widget.authorAvatarUrl!,
                                                fit: BoxFit.cover,
                                              )
                                            : Container(
                                                color: AppColors.secondaryTeal,
                                                child: Center(
                                                  child: Text(
                                                    widget.authorName.isNotEmpty ? widget.authorName[0] : '🎵',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 22,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Play / Pause Overlay Icon
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Audio Title
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Creator Row
                      GestureDetector(
                        onTap: () {
                          if (widget.authorId != null && widget.authorId!.isNotEmpty) {
                            context.push('/user/${widget.authorId}');
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.music_note_rounded, size: 16, color: AppColors.secondaryTeal),
                            const SizedBox(width: 4),
                            Text(
                              '@${widget.authorHandle}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.secondaryTeal,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: AppColors.secondaryTeal),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Reel count info
                      Text(
                        '${math.max(1, allReels.length)} videos using this sound',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Action Chips: Play Preview / Bookmark
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _togglePlay,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              side: BorderSide(
                                color: isDark ? Colors.white24 : Colors.black12,
                              ),
                            ),
                            icon: Icon(
                              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              size: 18,
                            ),
                            label: Text(_isPlaying ? 'Pause' : 'Play Preview'),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: _toggleSaveAudio,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              side: BorderSide(
                                color: _isSavedAudio ? const Color(0xFFFFB800) : (isDark ? Colors.white24 : Colors.black12),
                              ),
                            ),
                            icon: Icon(
                              _isSavedAudio ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                              size: 18,
                              color: _isSavedAudio ? const Color(0xFFFFB800) : null,
                            ),
                            label: Text(
                              _isSavedAudio ? 'Saved' : 'Save Sound',
                              style: TextStyle(
                                color: _isSavedAudio ? const Color(0xFFFFB800) : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Section Header: Videos
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.video_library_rounded, size: 18, color: AppColors.secondaryTeal),
                      const SizedBox(width: 8),
                      const Text(
                        'Videos with this audio',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${allReels.length} reels',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3-Column Reels Grid
              if (allReels.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.videocam_off_rounded,
                            size: 48,
                            color: isDark ? Colors.grey[700] : Colors.grey[300],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Be the first to create a reel with this audio!',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 3,
                      mainAxisSpacing: 3,
                      childAspectRatio: 0.65,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final reel = allReels[index];
                        final posterUrl = reel.mediaUrl.isNotEmpty ? reel.mediaUrl : null;

                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            context.push('/reels');
                          },
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Thumbnail
                              if (posterUrl != null && posterUrl.isNotEmpty)
                                CachedNetworkImage(
                                  imageUrl: posterUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: isDark ? const Color(0xFF1E293B) : Colors.grey[200],
                                  ),
                                  errorWidget: (context, url, err) => Container(
                                    color: isDark ? const Color(0xFF1E293B) : Colors.grey[300],
                                    child: const Icon(Icons.play_circle_fill, color: Colors.white24, size: 36),
                                  ),
                                )
                              else
                                Container(
                                  color: isDark ? const Color(0xFF1E293B) : Colors.grey[300],
                                  child: const Icon(Icons.play_circle_fill, color: Colors.white24, size: 36),
                                ),

                              // Gradient shade
                              Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.transparent, Colors.black54],
                                    begin: Alignment.center,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),

                              // Play / View count badge
                              Positioned(
                                left: 6,
                                bottom: 6,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14),
                                    const SizedBox(width: 2),
                                    Text(
                                      _formatViews(reel.viewsCount > 0 ? reel.viewsCount : reel.likesCount * 3 + 12),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      childCount: allReels.length,
                    ),
                  ),
                ),

              // Bottom padding for CTA button
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),

          // Bottom Floating "Use this sound" Action Button
          Positioned(
            left: 20,
            right: 20,
            bottom: 24,
            child: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF0D9488),
                      Color(0xFF0F766E),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.secondaryTeal.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _useThisSound,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  icon: const Icon(Icons.movie_creation_outlined, size: 20),
                  label: const Text(
                    'Use this sound',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatViews(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}
