import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/user_repository.dart';
import '../../../core/utils/url_validator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/verification_badge.dart';
import '../../../core/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserListScreen extends ConsumerWidget {
  final String userId;
  final int initialIndex; // 0 = Followers, 1 = Following, 2 = Hashtags

  const UserListScreen({
    super.key,
    required this.userId,
    this.initialIndex = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      initialIndex: initialIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Connections'),
          bottom: TabBar(
            indicatorColor: AppColors.secondaryTeal,
            labelColor: AppColors.secondaryTeal,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'Followers'),
              Tab(text: 'Following'),
              Tab(text: 'Hashtags'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _UserList(userId: userId, type: 'followers'),
            _UserList(userId: userId, type: 'following'),
            const _FollowedHashtagsList(),
          ],
        ),
      ),
    );
  }
}

class _UserList extends ConsumerWidget {
  final String userId;
  final String type; // 'followers' or 'following'

  const _UserList({required this.userId, required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final provider = type == 'followers'
        ? followersProvider(userId)
        : followingProvider(userId);

    final usersAsync = ref.watch(provider);

    return usersAsync.when(
      data: (users) {
        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  type == 'followers'
                      ? Icons.group_outlined
                      : Icons.person_add_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  type == 'followers'
                      ? 'No followers yet'
                      : 'Not following anyone yet',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return ListTile(
              onTap: () => context.push('/user/${user.uid}'),
              leading: CircleAvatar(
                radius: 20,
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                backgroundImage: (user.avatarUrl != null &&
                        UrlValidator.isValidUrl(user.avatarUrl!))
                    ? CachedNetworkImageProvider(user.avatarUrl!)
                    : null,
                child: (user.avatarUrl == null ||
                        !UrlValidator.isValidUrl(user.avatarUrl!))
                    ? Text(
                        user.displayName.isNotEmpty
                            ? user.displayName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      user.displayName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (user.isVerified) ...[
                    const SizedBox(width: 4),
                    VerificationBadge(type: user.verificationType, size: 14),
                  ],
                ],
              ),
              subtitle: Text('@${user.handle}'),
              trailing: Consumer(
                builder: (context, ref, child) {
                  final currentUser = ref.watch(currentUserProvider).value;
                  if (currentUser?.uid == user.uid) {
                    return const SizedBox.shrink();
                  }

                  final isFollowingAsync = ref.watch(
                    isFollowingProvider(user.uid),
                  );
                  return isFollowingAsync.when(
                    data: (isFollowing) {
                      return SizedBox(
                        height: 32,
                        child: isFollowing
                            ? OutlinedButton(
                                onPressed: () {
                                  ref
                                      .read(userRepositoryProvider)
                                      .unfollowUser(user.uid);
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: const Text('Following'),
                              )
                            : FilledButton(
                                onPressed: () {
                                  ref
                                      .read(userRepositoryProvider)
                                      .followUser(user.uid);
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.secondaryTeal,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: const Text('Follow'),
                              ),
                      );
                    },
                    loading: () => const SizedBox(width: 32),
                    error: (_, _) => const SizedBox(width: 32),
                  );
                },
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }
}

class _FollowedHashtagsList extends StatefulWidget {
  const _FollowedHashtagsList();

  @override
  State<_FollowedHashtagsList> createState() => _FollowedHashtagsListState();
}

class _FollowedHashtagsListState extends State<_FollowedHashtagsList> {
  List<String> _tags = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('followed_hashtags') ?? [];
      if (mounted) {
        setState(() {
          _tags = list;
          _isLoading = false;
        });
      }

      // Sync with backend if authenticated
      if (ApiClient.isAuthenticated) {
        try {
          final res = await ApiClient.get('/posts/hashtag/following');
          if (res.statusCode == 200) {
            final decoded = jsonDecode(res.body);
            final dataList = decoded['data'];
            if (dataList is List) {
              final serverTags = dataList.map((e) => e.toString().toLowerCase()).toList();
              await prefs.setStringList('followed_hashtags', serverTags);
              if (mounted) {
                setState(() {
                  _tags = serverTags;
                });
              }
            }
          }
        } catch (_) {}
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _unfollowTag(String tag) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('followed_hashtags') ?? [];
      final key = tag.toLowerCase();
      list.remove(key);
      await prefs.setStringList('followed_hashtags', list);

      if (ApiClient.isAuthenticated) {
        ApiClient.post('/posts/hashtag/unfollow', {'tag': key}).then((_) {}).catchError((_) => null);
      }

      if (mounted) {
        setState(() {
          _tags = list;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unfollowed #$tag'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tags.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                ),
                child: const Icon(
                  Icons.tag_rounded,
                  size: 36,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No Followed Hashtags',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Follow hashtags to stay connected with campus trends and discussions that matter to you.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => context.push('/search'),
                icon: const Icon(Icons.explore_rounded, size: 18),
                label: const Text('Explore Topics'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.secondaryTeal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTags,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _tags.length,
        separatorBuilder: (_, _) => Divider(
          height: 1,
          indent: 72,
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
        itemBuilder: (context, index) {
          final tag = _tags[index];
          final displayTag = '#$tag';

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(Icons.tag_rounded, color: Colors.white, size: 22),
              ),
            ),
            title: Text(
              displayTag,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Text(
              'Topic • Followed',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
            trailing: SizedBox(
              height: 32,
              child: OutlinedButton(
                onPressed: () => _unfollowTag(tag),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('Following', style: TextStyle(fontSize: 12)),
              ),
            ),
            onTap: () {
              context.push('/hashtag/$tag');
            },
          );
        },
      ),
    );
  }
}

