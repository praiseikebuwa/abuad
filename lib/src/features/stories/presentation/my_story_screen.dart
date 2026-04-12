import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/utils/url_validator.dart';
import '../data/story_repository.dart';
import '../../user/data/user_repository.dart';
import 'story_viewer_screen.dart';
import 'widgets/story_viewers_sheet.dart';

class MyStoryScreen extends ConsumerWidget {
  const MyStoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final storiesAsync = ref.watch(allStoriesGroupedProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Story'),
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      body: storiesAsync.when(
        data: (storiesGrouped) {
          final myStories = storiesGrouped[currentUserId] ?? [];

          if (myStories.isEmpty) {
            return Center(
              child: Text(
                'You have no active stories',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: myStories.length,
            itemBuilder: (context, index) {
              final story = myStories[index];
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StoryViewerScreen(
                        storiesGrouped: storiesGrouped,
                        initialUserId: currentUserId!,
                        initialStoryIndex: index,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      // Thumbnail
                      Container(
                        width: 60,
                        height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: isDark ? Colors.grey[800] : Colors.grey[200],
                            image: UrlValidator.isValidUrl(story.content)
                                ? DecorationImage(
                                    image: CachedNetworkImageProvider(story.content),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                      ),
                      const SizedBox(width: 16),
                      // Information
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              timeago.format(story.createdAt),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey[100] : Colors.grey[900],
                              ),
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => StoryViewersSheet(
                                    viewers: story.viewers,
                                  ),
                                );
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.remove_red_eye,
                                    size: 16,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${story.viewers.length} views',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 3-dot Menu
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_horiz,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                        onSelected: (value) async {
                          if (value == 'delete') {
                            await ref.read(storyRepositoryProvider).deleteStory(story.id);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              leading: Icon(Icons.delete_outline, color: Colors.red),
                              title: Text('Delete Story', style: TextStyle(color: Colors.red)),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
