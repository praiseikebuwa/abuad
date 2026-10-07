import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/user_repository.dart';
import '../../../core/utils/url_validator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/verification_badge.dart';

class UserListScreen extends ConsumerWidget {
  final String userId;
  final int initialIndex; // 0 = Followers, 1 = Following

  const UserListScreen({
    super.key,
    required this.userId,
    this.initialIndex = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
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
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _UserList(userId: userId, type: 'followers'),
            _UserList(userId: userId, type: 'following'),
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
