import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Camera story button widget
class CameraStoryItem extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;

  const CameraStoryItem({super.key, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 4),
            const Text(
              'Your Story',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Story item widget for displaying user stories
class StoryItem extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final bool hasStory;
  final bool hasUnviewedStory;
  final bool isDark;
  final VoidCallback onTap;

  const StoryItem({
    super.key,
    required this.name,
    this.avatarUrl,
    required this.hasStory,
    required this.hasUnviewedStory,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasUnviewedStory
                    ? const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                border: !hasUnviewedStory && hasStory
                    ? Border.all(
                        color: isDark ? Colors.grey[700]! : Colors.grey[400]!,
                        width: 2,
                      )
                    : null,
              ),
              padding: const EdgeInsets.all(2),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? Colors.black : const Color(0xFFFAFAFA),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                      ? CachedNetworkImageProvider(avatarUrl!)
                      : null,
                  backgroundColor: const Color(0xFF8B5CF6),
                  child: avatarUrl == null || avatarUrl!.isEmpty
                      ? Text(
                          name[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 64,
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
