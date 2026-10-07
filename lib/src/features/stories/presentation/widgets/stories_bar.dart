import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/utils/url_validator.dart';
import '../../data/story_repository.dart';
import '../../domain/story.dart';
import '../../../user/data/user_repository.dart';
import '../create_story_screen.dart';
import '../my_story_screen.dart';
import '../story_viewer_screen.dart';

class StoriesBar extends ConsumerWidget {
  const StoriesBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesAsync = ref.watch(activeStoriesProvider);
    final currentUser = ref.watch(currentUserProvider).value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 104,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: storiesAsync.when(
        data: (stories) {
          final myStories = stories.where((s) => s.authorId == currentUser?.uid).toList();
          final hasMyStories = myStories.isNotEmpty;
          final allMyViewed = hasMyStories && currentUser != null && myStories.every((s) => s.hasViewed(currentUser.uid));

          // Group stories by author
          final authorStories = <String, List<Story>>{};
          for (var story in stories) {
            if (story.authorId == currentUser?.uid) {
              continue; // Handled separately in the first slot
            }
            authorStories.putIfAbsent(story.authorId, () => []).add(story);
          }

          final allGroupedStories = <String, List<Story>>{};
          for (var story in stories) {
            allGroupedStories.putIfAbsent(story.authorId, () => []).add(story);
          }

          return ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // User's own Story Item
              if (currentUser != null)
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: GestureDetector(
                    onTap: () {
                      if (hasMyStories) {
                        _showMyStatusOptions(context, allGroupedStories, currentUser.uid);
                      } else {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const CreateStoryScreen(),
                          ),
                        );
                      }
                    },
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 62,
                              height: 62,
                              padding: EdgeInsets.all(hasMyStories ? 2.5 : 2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: hasMyStories && !allMyViewed
                                    ? const LinearGradient(
                                        colors: [Color(0xFF00E5FF), Color(0xFF1F5F5B)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                border: hasMyStories && allMyViewed
                                    ? Border.all(
                                        color: Colors.grey.withValues(alpha: 0.5),
                                        width: 2,
                                      )
                                    : (!hasMyStories
                                        ? Border.all(
                                            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                                            width: 1.5,
                                          )
                                        : null),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F1115) : Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: CircleAvatar(
                                  backgroundColor: const Color(0xFF8B5CF6),
                                  backgroundImage: (currentUser.avatarUrl != null &&
                                          UrlValidator.isValidUrl(currentUser.avatarUrl!))
                                      ? CachedNetworkImageProvider(currentUser.avatarUrl!)
                                      : null,
                                  child: (currentUser.avatarUrl == null ||
                                          !UrlValidator.isValidUrl(currentUser.avatarUrl!))
                                      ? Text(
                                          currentUser.displayName.isNotEmpty
                                              ? currentUser.displayName[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00E5FF),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF0F1115) : Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  hasMyStories ? Icons.add : Icons.add,
                                  color: Colors.black,
                                  size: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your Story',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: hasMyStories ? FontWeight.w700 : FontWeight.w500,
                            color: isDark ? Colors.grey[300] : Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Active Stories from other users
              ...authorStories.entries.map<Widget>((entry) {
                final authorId = entry.key;
                final userStories = entry.value;
                final allViewed = currentUser != null && userStories.every((s) => s.hasViewed(currentUser.uid));
                final authorAsync = ref.watch(userProvider(authorId));

                return authorAsync.when(
                  data: (author) {
                    if (author == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => StoryViewerScreen(
                                storiesGrouped: allGroupedStories,
                                initialUserId: authorId,
                              ),
                            ),
                          );
                        },
                        child: Column(
                          children: [
                            Container(
                              width: 62,
                              height: 62,
                              padding: const EdgeInsets.all(2.5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: !allViewed
                                    ? const LinearGradient(
                                        colors: [Color(0xFF00E5FF), Color(0xFF1F5F5B)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : null,
                                border: allViewed
                                    ? Border.all(
                                        color: Colors.grey.withValues(alpha: 0.5),
                                        width: 2,
                                      )
                                    : null,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F1115) : Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: CircleAvatar(
                                  backgroundColor: const Color(0xFF8B5CF6),
                                  backgroundImage: (author.avatarUrl != null &&
                                          UrlValidator.isValidUrl(author.avatarUrl!))
                                      ? CachedNetworkImageProvider(author.avatarUrl!)
                                      : null,
                                  child: (author.avatarUrl == null ||
                                          !UrlValidator.isValidUrl(author.avatarUrl!))
                                      ? Text(
                                          author.displayName.isNotEmpty
                                              ? author.displayName[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: 62,
                              child: Text(
                                author.displayName.split(' ')[0],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: !allViewed ? FontWeight.w700 : FontWeight.w500,
                                  color: isDark ? Colors.grey[300] : Colors.grey[800],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  loading: () => const SizedBox(width: 62, height: 84),
                  error: (_, _) => const SizedBox.shrink(),
                );
              }),
            ],
          );
        },
        loading: () => const Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (e, stack) => const SizedBox.shrink(),
      ),
    );
  }

  void _showMyStatusOptions(
    BuildContext context,
    Map<String, List<Story>> allGroupedStories,
    String currentUserId,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
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
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_circle_fill, color: Color(0xFF00E5FF)),
                  ),
                  title: const Text('View My Status', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Watch your active status update'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StoryViewerScreen(
                          storiesGrouped: allGroupedStories,
                          initialUserId: currentUserId,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.insights_rounded, color: Color(0xFF8B5CF6)),
                  ),
                  title: const Text('My Status & Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  title: const Text('Add New Status', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Share another photo or text update'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CreateStoryScreen()),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}
