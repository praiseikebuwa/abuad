import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../features/stories/data/story_repository.dart';
import '../../features/stories/domain/story.dart';
import '../../features/auth/data/auth_repository.dart';

class UserAvatar extends ConsumerWidget {
  final String userId;
  final String? avatarUrl;
  final String? displayName;
  final double radius;
  final VoidCallback? onTap;
  final bool showStoryRing;
  final bool enableDefaultTap;
  final Color? backgroundColor;
  final Color? highlightColor;

  const UserAvatar({
    super.key,
    required this.userId,
    this.avatarUrl,
    this.displayName,
    this.radius = 20,
    this.onTap,
    this.showStoryRing = true,
    this.enableDefaultTap = true,
    this.backgroundColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesGroupedAsync = ref.watch(allStoriesGroupedProvider);
    final currentUserId = ref.watch(authRepositoryProvider).currentUser?.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!showStoryRing) {
      return _buildAvatar(context);
    }

    return storiesGroupedAsync.when(
      data: (groups) {
        final userStories = groups[userId];
        final hasActiveStories = userStories != null && userStories.isNotEmpty;

        final allViewed =
            hasActiveStories &&
            currentUserId != null &&
            userStories.every((s) => s.hasViewed(currentUserId));

        if (!hasActiveStories) return _buildAvatar(context);

        final canTap = onTap != null || enableDefaultTap;
        if (!canTap) return _buildAvatar(context, internalTap: true);

        return GestureDetector(
          onTap: onTap ?? () => _showStatusMenu(context, groups),
          child: Container(
            padding: EdgeInsets.all(radius * 0.12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: !allViewed
                  ? const LinearGradient(
                    colors: [Color(0xFF00E5FF), Color(0xFF1F5F5B)], // Cyan to Teal
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                  : null,
              color: allViewed ? Colors.grey.withOpacity(0.5) : null,
            ),
            child: Container(
              padding: EdgeInsets.all(radius * 0.08),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F1115) : Colors.white,
                shape: BoxShape.circle,
              ),
              child: _buildAvatar(context, internalTap: true),
            ),
          ),
        );
      },
      loading: () => _buildAvatar(context),
      error: (e, s) => _buildAvatar(context),
    );
  }

  void _showStatusMenu(BuildContext context, Map<String, List<Story>> groups) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_circle_fill, color: Colors.blue),
                ),
                title: const Text(
                  'View Status',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('See recent updates'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/stories/$userId', extra: groups);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, color: Colors.grey),
                ),
                title: const Text(
                  'View Profile',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('See user details'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/user/$userId');
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatar(BuildContext context, {bool internalTap = false}) {
    final avatar = CircleAvatar(
      radius: radius,
      backgroundImage:
          (avatarUrl != null && avatarUrl!.isNotEmpty)
              ? CachedNetworkImageProvider(avatarUrl!)
              : null,
      backgroundColor: backgroundColor ?? const Color(0xFF8B5CF6),
      child:
          (avatarUrl == null || avatarUrl!.isEmpty)
              ? Text(
                (displayName != null && displayName!.isNotEmpty)
                    ? displayName![0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: radius * 0.8,
                  fontWeight: FontWeight.bold,
                ),
              )
              : null,
    );

    if (internalTap) return avatar;

    final canTap = onTap != null || enableDefaultTap;
    if (!canTap) return avatar;

    return GestureDetector(
      onTap: onTap ?? () => context.push('/user/$userId'),
      child: avatar,
    );
  }
}
