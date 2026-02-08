import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../auth/data/auth_repository.dart';
import '../../user/data/user_repository.dart';
import '../../feed/data/post_repository.dart';
import '../../feed/domain/post.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../feed/presentation/widgets/post_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/supabase_storage_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String? userId; // If null, shows current user

  const ProfileScreen({super.key, this.userId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final authRepo = ref.watch(authRepositoryProvider);
    final currentUserId = authRepo.currentUser?.id;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Determine which user to show
    final targetUserId = widget.userId ?? currentUserId;

    if (targetUserId == null) {
      return const Scaffold(body: Center(child: Text("Please sign in")));
    }

    final userAsync = ref.watch(userProvider(targetUserId));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text("User not found"));
          }
          final isCurrentUser = currentUserId == user.uid;

          return DefaultTabController(
            length: 3,
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    expandedHeight: 180,
                    pinned: true,
                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    iconTheme: IconThemeData(color: Colors.white),
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        children: [
                          // Banner Image
                          Container(
                            height: 180,
                            decoration: BoxDecoration(
                              gradient: user.bannerUrl == null
                                  ? AppColors.inkTealGradient
                                  : null,
                            ),
                            child: user.bannerUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: user.bannerUrl!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: 180,
                                  )
                                : null,
                          ),

                          // Edit Banner Button (Current User Only)
                          if (isCurrentUser)
                            Positioned(
                              top: 50,
                              right: 16,
                              child: IconButton(
                                onPressed: () =>
                                    _updateBannerImage(context, ref, user),
                                icon: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    actions: [
                      if (isCurrentUser)
                        IconButton(
                          icon: const Icon(
                            Icons.settings_outlined,
                            color: Colors.white,
                          ),
                          onPressed: () => context.push('/settings'),
                        ),
                    ],
                  ),
                ];
              },
              body: Column(
                children: [
                  // Profile Header Content
                  _ProfileHeader(
                    user: user,
                    isCurrentUser: isCurrentUser,
                    currentUserId: currentUserId,
                    isDark: isDark,
                  ),

                  // Tabs
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isDark ? Colors.white12 : Colors.grey[200]!,
                          width: 1,
                        ),
                      ),
                    ),
                    child: TabBar(
                      labelColor: isDark ? Colors.white : Colors.black87,
                      unselectedLabelColor: isDark
                          ? Colors.grey[600]
                          : Colors.grey[500],
                      indicatorColor: theme.colorScheme.secondary,
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      tabs: const [
                        Tab(text: "Posts"),
                        Tab(text: "Replies"),
                        Tab(text: "Likes"),
                      ],
                    ),
                  ),

                  // Tab Views
                  Expanded(
                    child: TabBarView(
                      children: [
                        _UserPostsList(userId: user.uid, isDark: isDark),
                        Center(
                          child: Text(
                            "Replies coming soon",
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[500]
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                        Center(
                          child: Text(
                            "Likes coming soon",
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[500]
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, stack) => Center(
          child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }

  Future<void> _updateBannerImage(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
  ) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Uploading banner...')));

      try {
        final storage = SupabaseStorageService();
        final url = await storage.uploadImage(pickedFile);

        if (url.isNotEmpty && context.mounted) {
          await ref.read(userRepositoryProvider).updateUser(user.uid, {
            'bannerUrl': url,
          });
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Banner updated!')));
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error updating banner: $e')));
        }
      }
    }
  }
}

class _ProfileHeader extends ConsumerWidget {
  final AppUser user;
  final bool isCurrentUser;
  final String? currentUserId;
  final bool isDark;

  const _ProfileHeader({
    required this.user,
    required this.isCurrentUser,
    required this.currentUserId,
    required this.isDark,
  });

  Future<void> _updateProfileImage(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final result = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final pickedFile = await picker.pickImage(source: result);

      if (pickedFile != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Uploading image...')));

        try {
          final storage = SupabaseStorageService();
          final url = await storage.uploadImage(pickedFile);

          if (url.isNotEmpty && context.mounted) {
            await ref.read(userRepositoryProvider).updateUser(user.uid, {
              'avatarUrl': url,
            });
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile picture updated!')),
              );
            }
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Error: $e')));
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar and Action Button Row
          Transform.translate(
            offset: const Offset(0, -50),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Avatar with Edit Button Overlay
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? AppColors.surfaceDark : Colors.white,
                          width: 4,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 42,
                        backgroundColor: theme.colorScheme.secondary
                            .withOpacity(0.15),
                        backgroundImage: user.avatarUrl != null
                            ? CachedNetworkImageProvider(user.avatarUrl!)
                            : null,
                        child: user.avatarUrl == null
                            ? Text(
                                user.displayName.isNotEmpty
                                    ? user.displayName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              )
                            : null,
                      ),
                    ),

                    // Edit Avatar Button (Current User Only)
                    if (isCurrentUser)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _updateProfileImage(context, ref),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark
                                    ? AppColors.surfaceDark
                                    : Colors.white,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: AppColors.primaryInk,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                  ],
                ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),

                // Action Button
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: isCurrentUser
                      ? OutlinedButton(
                          onPressed: () => context.push('/profile/edit'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark
                                ? Colors.white
                                : AppColors.primaryInk,
                            side: BorderSide(
                              color: isDark
                                  ? Colors.white24
                                  : const Color(0xFFE8E1D7),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 8,
                            ),
                          ),
                          child: const Text(
                            "Edit Profile",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        )
                      : _FollowButton(targetUserId: user.uid, isDark: isDark),
                ).animate().fadeIn(delay: 200.ms),
              ],
            ),
          ),

          // Adjust spacing
          const SizedBox(height: -30),

          // User Info
          Text(
            user.displayName,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: 2),

          Row(
            children: [
              Text(
                user.handle,
                style: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                  fontSize: 15,
                ),
              ),
              if (user.isVerified) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.verified,
                  size: 18,
                  color: theme.colorScheme.secondary,
                ),
              ],
            ],
          ).animate().fadeIn(delay: 150.ms),

          const SizedBox(height: 12),

          // Bio
          if (user.bio != null && user.bio!.isNotEmpty) ...[
            Text(
              user.bio!,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: isDark ? Colors.grey[300] : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // College/Location
          if (user.college != null) ...[
            Row(
              children: [
                Icon(
                  Icons.school_outlined,
                  size: 16,
                  color: isDark ? Colors.grey[600] : Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Text(
                  user.college!,
                  style: TextStyle(
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Follower Stats
          Row(
            children: [
              _StatItem(
                count: user.followingCount,
                label: "Following",
                isDark: isDark,
              ),
              const SizedBox(width: 20),
              _StatItem(
                count: user.followersCount,
                label: "Followers",
                isDark: isDark,
              ),
            ],
          ).animate().fadeIn(delay: 300.ms),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final int count;
  final String label;
  final bool isDark;

  const _StatItem({
    required this.count,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.grey[500] : Colors.grey[600],
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

class _FollowButton extends ConsumerWidget {
  final String targetUserId;
  final bool isDark;

  const _FollowButton({required this.targetUserId, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(userRepositoryProvider);
    final isFollowingAsync = ref.watch(isFollowingProvider(targetUserId));

    return isFollowingAsync.when(
      data: (isFollowing) {
        return ElevatedButton(
          onPressed: () async {
            if (isFollowing) {
              await repo.unfollowUser(targetUserId);
            } else {
              await repo.followUser(targetUserId);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isFollowing
                ? (isDark ? Colors.transparent : Colors.white)
                : (isDark ? Colors.white : AppColors.primaryInk),
            foregroundColor: isFollowing
                ? (isDark ? Colors.white : AppColors.primaryInk)
                : (isDark ? AppColors.primaryInk : Colors.white),
            side: BorderSide(
              color: isFollowing
                  ? (isDark ? Colors.white24 : const Color(0xFFE8E1D7))
                  : Colors.transparent,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          ),
          child: Text(
            isFollowing ? "Following" : "Follow",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        );
      },
      loading: () => const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => const SizedBox(),
    );
  }
}

class _UserPostsList extends ConsumerWidget {
  final String userId;
  final bool isDark;

  const _UserPostsList({required this.userId, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(postRepositoryProvider);

    return StreamBuilder<List<Post>>(
      stream: repo.watchPosts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allPosts = snapshot.data ?? [];
        final userPosts = allPosts.where((p) => p.authorId == userId).toList();

        if (userPosts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.post_add,
                    size: 64,
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No posts yet",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: userPosts.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            color: isDark ? Colors.grey[900] : Colors.grey[200],
          ),
          itemBuilder: (context, index) {
            final post = userPosts[index];
            return PostCard(post: post);
          },
        );
      },
    );
  }
}

// Providers
final userProvider = FutureProvider.family<AppUser?, String>((ref, uid) {
  return ref.watch(userRepositoryProvider).getUserById(uid);
});

final isFollowingProvider = StreamProvider.family<bool, String>((
  ref,
  targetUid,
) {
  return ref.watch(userRepositoryProvider).isFollowing(targetUid);
});
