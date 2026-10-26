import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/stories/data/story_repository.dart';
import '../../features/stories/domain/story.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../core/utils/url_validator.dart';
import '../../features/stories/presentation/my_story_screen.dart';
import '../../features/stories/presentation/create_story_screen.dart';
import 'autoplay_live_media_widget.dart';

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
    final currentUserId = ref.watch(authRepositoryProvider).currentUser?.uid ??
        ref.watch(currentUserIdProvider);
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
          onTap: onTap ?? () => _showStatusMenu(context, groups, currentUserId),
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
              color: allViewed ? Colors.grey.withValues(alpha: 0.5) : null,
            ),
            child: Container(
              padding: EdgeInsets.all(radius * 0.08),
              decoration: BoxDecoration(
                color: isDark ? Colors.black : Colors.white,
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

  void _showStatusMenu(
    BuildContext context,
    Map<String, List<Story>> groups,
    String? currentUserId,
  ) {
    final isSelf = currentUserId != null && currentUserId == userId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF101010) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (displayName != null && displayName!.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Row(
                      children: [
                        _buildAvatar(context, internalTap: true),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                isSelf ? 'Your status update' : 'Recent status update',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 24),
                ],
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_circle_fill, color: Color(0xFF00E5FF)),
                  ),
                  title: Text(
                    isSelf ? 'View My Status' : 'View Status',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Watch active stories'),
                  onTap: () {
                    Navigator.pop(context);
                    final userStories = groups[userId] ?? [];
                    context.push(
                      '/stories/$userId',
                      extra: {
                        'storiesGrouped': {userId: userStories},
                        'singleUserMode': true,
                      },
                    );
                  },
                ),
                if (isSelf) ...[
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.insights_rounded, color: Color(0xFF8B5CF6)),
                    ),
                    title: const Text(
                      'My Status & Analytics',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('See viewers, likes & delete status'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MyStoryScreen()),
                      );
                    },
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_circle_outline_rounded, color: Colors.green),
                    ),
                    title: const Text(
                      'Add New Status',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Share photo or text status'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CreateStoryScreen()),
                      );
                    },
                  ),
                ],
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person, color: isDark ? Colors.grey[300] : Colors.grey[700]),
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
          ),
        );
      },
    );
  }

  Widget _buildAvatar(BuildContext context, {bool internalTap = false}) {
    final formattedUrl = (avatarUrl != null && avatarUrl!.isNotEmpty)
        ? UrlValidator.formatImageUrl(avatarUrl)
        : null;
    final hasValidUrl = formattedUrl != null &&
        formattedUrl.isNotEmpty &&
        UrlValidator.isValidUrl(formattedUrl);

    final fallbackText = Text(
      (displayName != null && displayName!.isNotEmpty)
          ? displayName![0].toUpperCase()
          : '?',
      style: TextStyle(
        color: Colors.white,
        fontSize: radius * 0.8,
        fontWeight: FontWeight.bold,
      ),
    );

    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? const Color(0xFF8B5CF6),
      child: hasValidUrl
          ? AutoPlayLiveMediaWidget(
              url: formattedUrl,
              width: radius * 2,
              height: radius * 2,
              isCircle: true,
              fit: BoxFit.cover,
              placeholder: fallbackText,
              errorWidget: fallbackText,
            )
          : fallbackText,
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
