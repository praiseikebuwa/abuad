import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/audio_track.dart';
import '../data/music_repository.dart';

class MusicPickerSheet extends ConsumerStatefulWidget {
  const MusicPickerSheet({super.key});

  static Future<AudioTrack?> show(BuildContext context) {
    return showModalBottomSheet<AudioTrack>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const MusicPickerSheet(),
    );
  }

  @override
  ConsumerState<MusicPickerSheet> createState() => _MusicPickerSheetState();
}

class _MusicPickerSheetState extends ConsumerState<MusicPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  String _selectedCategory = 'Trending';
  String _searchQuery = '';
  String? _playingTrackId;
  bool _isPlaying = false;

  final List<String> _categories = const [
    'Trending',
    'Afrobeats',
    'Campus Vibes',
    'Viral Reels',
    'Chill & Lo-Fi',
    'Party & Drill',
  ];

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _playingTrackId = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePreview(AudioTrack track) async {
    HapticFeedback.selectionClick();
    if (_playingTrackId == track.id && _isPlaying) {
      await _audioPlayer.pause();
      if (mounted) setState(() => _isPlaying = false);
    } else {
      await _audioPlayer.stop();
      try {
        await _audioPlayer.play(UrlSource(track.audioUrl));
        if (mounted) {
          setState(() {
            _playingTrackId = track.id;
            _isPlaying = true;
          });
        }
      } catch (e) {
        debugPrint('Error playing preview audio: $e');
      }
    }
  }

  void _selectTrack(AudioTrack track) {
    HapticFeedback.mediumImpact();
    _audioPlayer.stop();
    Navigator.of(context).pop(track);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final repo = ref.watch(musicRepositoryProvider);

    final sheetBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final inputBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Drag Handle & Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 10, 8),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 36),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.music_note_rounded, color: AppColors.secondaryTeal, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'Add Sound',
                            style: TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 22),
                        color: textSecondary,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: borderColor, width: 0.8),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  style: TextStyle(color: textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search songs, artists, viral sounds...',
                    hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                    prefixIcon: Icon(Icons.search_rounded, color: textSecondary, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: Icon(Icons.cancel_rounded, color: textSecondary, size: 18),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            // Category Filter Pills
            if (_searchQuery.isEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: _categories.map((category) {
                    final isSelected = _selectedCategory == category;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedCategory = category);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.transparent
                                  : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                            ),
                          ),
                          child: Text(
                            category,
                            style: TextStyle(
                              color: isSelected
                                  ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                                  : textSecondary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

            const SizedBox(height: 4),
            Divider(height: 1, color: borderColor),

            // Track List
            Expanded(
              child: FutureBuilder<List<AudioTrack>>(
                future: _searchQuery.isNotEmpty
                    ? repo.searchTracks(_searchQuery)
                    : repo.getTracksByCategory(_selectedCategory),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                  }

                  final tracks = snapshot.data ?? [];
                  if (tracks.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.music_off_rounded, size: 48, color: textSecondary.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text(
                            'No sounds found',
                            style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text('Try searching for another artist or song', style: TextStyle(color: textSecondary, fontSize: 13)),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: tracks.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      thickness: 0.5,
                      indent: 68,
                      color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                    ),
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      final isCurrentTrack = _playingTrackId == track.id;
                      final isPlayingCurrent = isCurrentTrack && _isPlaying;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            // Cover art with play/pause button
                            GestureDetector(
                              onTap: () => _togglePreview(track),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: track.coverUrl != null
                                        ? CachedNetworkImage(
                                            imageUrl: track.coverUrl!,
                                            width: 54,
                                            height: 54,
                                            fit: BoxFit.cover,
                                            placeholder: (context, _) => Container(color: Colors.grey[800]),
                                          )
                                        : Container(
                                            width: 54,
                                            height: 54,
                                            color: const Color(0xFF334155),
                                            child: const Icon(Icons.music_note, color: Colors.white60),
                                          ),
                                  ),
                                  Container(
                                    width: 54,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: isPlayingCurrent ? 0.45 : 0.25),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        isPlayingCurrent ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Song & Artist Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          track.title,
                                          style: TextStyle(
                                            color: isPlayingCurrent ? AppColors.secondaryTeal : textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14.5,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (track.isVerified) ...[
                                        const SizedBox(width: 4),
                                        const Icon(Icons.verified, size: 14, color: Color(0xFF38BDF8)),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    track.artist,
                                    style: TextStyle(color: textSecondary, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        track.formattedDuration,
                                        style: TextStyle(color: textSecondary.withValues(alpha: 0.8), fontSize: 11),
                                      ),
                                      Text(' · ', style: TextStyle(color: textSecondary, fontSize: 11)),
                                      Text(
                                        track.formattedUses,
                                        style: TextStyle(color: textSecondary.withValues(alpha: 0.8), fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Use Button
                            ElevatedButton.icon(
                              onPressed: () => _selectTrack(track),
                              icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                              label: const Text('Use', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
