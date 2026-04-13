import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

class VideoOptionsSheet extends ConsumerStatefulWidget {
  final String videoUrl;
  final double currentPlaybackSpeed;
  final Function(double) onSpeedChanged;

  const VideoOptionsSheet({
    super.key,
    required this.videoUrl,
    required this.currentPlaybackSpeed,
    required this.onSpeedChanged,
  });

  static Future<void> show({
    required BuildContext context,
    required String videoUrl,
    required double currentPlaybackSpeed,
    required Function(double) onSpeedChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VideoOptionsSheet(
        videoUrl: videoUrl,
        currentPlaybackSpeed: currentPlaybackSpeed,
        onSpeedChanged: onSpeedChanged,
      ),
    );
  }

  @override
  ConsumerState<VideoOptionsSheet> createState() => _VideoOptionsSheetState();
}

class _VideoOptionsSheetState extends ConsumerState<VideoOptionsSheet> {
  bool _isDownloading = false;
  double _downloadProgress = 0;
  bool _autoAdvance = true;

  Future<void> _downloadVideo() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });

    try {
      final tempDir = Directory.systemTemp;
      final fileName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final filePath = path.join(tempDir.path, fileName);

      await Dio().download(
        widget.videoUrl,
        filePath,
        onReceiveProgress: (count, total) {
          if (total != -1) {
            setState(() {
              _downloadProgress = count / total;
            });
          }
        },
      );

      await Gal.putVideo(filePath);

      if (mounted) {
        Navigator.pop(context); // Close options sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video saved to gallery'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16181C) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            _buildTwitterOption(
              icon: Icons.sentiment_very_dissatisfied_outlined,
              title: 'Not interested',
              onTap: () => Navigator.pop(context),
            ),
            _buildTwitterOption(
              icon: Icons.speed_outlined,
              title: 'Playback speed',
              trailingText: '${widget.currentPlaybackSpeed}x',
              onTap: () => _showSpeedSelector(context),
            ),
            _buildTwitterOption(
              icon: Icons.share_outlined,
              title: 'Share video',
              onTap: () => Navigator.pop(context),
            ),
            _buildTwitterOption(
              icon: Icons.play_circle_outline_rounded,
              title: 'Auto-advance',
              trailingText: _autoAdvance ? 'Enabled' : 'Disabled',
              onTap: () {
                setState(() => _autoAdvance = !_autoAdvance);
              },
            ),
            _buildTwitterOption(
              icon: Icons.file_download_outlined,
              title: _isDownloading ? 'Downloading...' : 'Download video',
              trailingText: _isDownloading
                  ? '${(_downloadProgress * 100).toInt()}%'
                  : null,
              onTap: _isDownloading ? null : _downloadVideo,
              isLoading: _isDownloading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTwitterOption({
    required IconData icon,
    required String title,
    String? trailingText,
    required VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white, size: 26),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w400,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else if (trailingText != null)
            Text(
              trailingText,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
        ],
      ),
      onTap: onTap,
    );
  }

  void _showSpeedSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF16181C),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.only(top: 12, bottom: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Playback speed',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    0.25,
                    0.5,
                    0.75,
                    1.0,
                    1.25,
                    1.5,
                    1.75,
                    2.0,
                    2.5,
                    3.0
                  ]
                      .map((speed) => ListTile(
                            title: Text(
                              '${speed}x',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: speed == widget.currentPlaybackSpeed
                                      ? Colors.green
                                      : Colors.white38,
                                  width: 2,
                                ),
                                color: speed == widget.currentPlaybackSpeed
                                    ? Colors.green
                                    : Colors.transparent,
                              ),
                              child: speed == widget.currentPlaybackSpeed
                                  ? const Icon(Icons.check,
                                      size: 16, color: Colors.white)
                                  : null,
                            ),
                            onTap: () {
                              widget.onSpeedChanged(speed);
                              Navigator.pop(context); // Pop speed selector
                              Navigator.pop(context); // Pop options sheet
                            },
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
