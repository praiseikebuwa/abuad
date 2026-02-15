import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/story_repository.dart';
import '../../domain/story.dart';
import '../../../user/data/user_repository.dart';
import '../create_story_screen.dart';
import '../story_viewer_screen.dart';

class StoriesBar extends ConsumerWidget {
  const StoriesBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesAsync = ref.watch(activeStoriesProvider);
    final currentUser = ref.watch(currentUserProvider).value;

    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Add Story Button
          if (currentUser != null)
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const CreateStoryScreen(),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.grey[300]!,
                              width: 2,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: CircleAvatar(
                              backgroundImage: currentUser.avatarUrl != null
                                  ? CachedNetworkImageProvider(
                                      currentUser.avatarUrl!,
                                    )
                                  : null,
                              child: currentUser.avatarUrl == null
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('Your Story', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),

          // Active Stories List
          ...storiesAsync.when(
            data: (stories) {
              // Group stories by author
              final authorStories = <String, List<Story>>{};
              for (var story in stories) {
                if (story.authorId == currentUser?.uid) {
                  continue; // Skip self in list
                }
                authorStories.putIfAbsent(story.authorId, () => []).add(story);
              }

              return authorStories.entries.map<Widget>((entry) {
                final authorId = entry.key;
                // Fetch author details
                final authorAsync = ref.watch(userProvider(authorId));

                return authorAsync.when(
                  data: (author) {
                    if (author == null) return const SizedBox.shrink();
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => StoryViewerScreen(
                              storiesGrouped: authorStories,
                              initialUserId: authorId,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [Colors.purple, Colors.orange],
                                  begin: Alignment.topRight,
                                  end: Alignment.bottomLeft,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: CircleAvatar(
                                      backgroundImage: author.avatarUrl != null
                                          ? CachedNetworkImageProvider(
                                              author.avatarUrl!,
                                            )
                                          : null,
                                      child: author.avatarUrl == null
                                          ? Text(author.displayName[0])
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              author.displayName.split(
                                ' ',
                              )[0], // First name only
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  loading: () => const SizedBox(
                    width: 64,
                    height: 84,
                  ), // Placeholder with approx size
                  error: (_, __) => const SizedBox.shrink(),
                );
              }).toList();
            },
            loading: () => [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            ],
            error: (e, stack) => [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.error),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
