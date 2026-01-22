import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../auth/data/auth_repository.dart';
import '../../user/data/user_repository.dart';
import '../../feed/data/post_repository.dart';
import '../../feed/domain/post.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/services/cloudinary_service.dart';

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
    final currentUserId = authRepo.currentUser?.uid;

    // Determine which user to show
    final targetUserId = widget.userId ?? currentUserId;

    if (targetUserId == null) {
      return const Scaffold(body: Center(child: Text("Please sign in")));
    }

    final userAsync = ref.watch(userProvider(targetUserId));

    return Scaffold(
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            // If data is null but it might be loading or valid null, check context
            return const Center(child: Text("User not found"));
          }
          final isCurrentUser = currentUserId == user.uid;

          return DefaultTabController(
            length: 3,
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    expandedHeight: 150,
                    pinned: true,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        color: Colors.blue[700], // Default banner color
                        child: user.bannerUrl != null
                            ? Image.network(user.bannerUrl!, fit: BoxFit.cover)
                            : null,
                      ),
                    ),
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(0),
                      child: Container(), // Spacer for overlapping avatar
                    ),
                    actions: [
                      if (isCurrentUser)
                        IconButton(
                          icon: const Icon(Icons.settings_outlined),
                          onPressed: () {
                            context.push('/profile/settings');
                          },
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
                  ),

                  // Tabs
                  const TabBar(
                    labelColor: Colors.black,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.blue,
                    tabs: [
                      Tab(text: "Posts"),
                      Tab(text: "Replies"),
                      Tab(text: "Likes"),
                    ],
                  ),

                  // Tab Views
                  Expanded(
                    child: TabBarView(
                      children: [
                        _UserPostsList(userId: user.uid),
                        const Center(child: Text("Replies coming soon")),
                        const Center(child: Text("Likes coming soon")),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, stack) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _ProfileHeader extends ConsumerWidget {
  final AppUser user;
  final bool isCurrentUser;
  final String? currentUserId;

  const _ProfileHeader({
    required this.user,
    required this.isCurrentUser,
    required this.currentUserId,
  });

  Future<void> _updateProfileImage(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Uploading image...')));

      try {
        final cloudinary = CloudinaryService();
        final url = await cloudinary.uploadImage(pickedFile);

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
          ).showSnackBar(SnackBar(content: Text('Error updating image: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row with Avatar (overlapping) and Action Button
          Transform.translate(
            offset: const Offset(0, -40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Avatar
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.blue[100],
                    backgroundImage: user.avatarUrl != null
                        ? NetworkImage(user.avatarUrl!)
                        : null,
                    child: user.avatarUrl == null
                        ? Text(
                            user.displayName.isNotEmpty
                                ? user.displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),

                // Action Button
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: isCurrentUser
                      ? OutlinedButton(
                          onPressed: () => _updateProfileImage(context, ref),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text("Edit Profile"),
                        )
                      : _FollowButton(targetUserId: user.uid),
                ).animate().fadeIn(delay: 200.ms),
              ],
            ),
          ),

          // Fix layout shift from translate
          const SizedBox(height: -30),

          // User Info
          Text(
            user.displayName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ).animate().fadeIn(delay: 100.ms).slideX(),
          Row(
            children: [
              Text(
                user.handle,
                style: TextStyle(color: Colors.grey[600], fontSize: 15),
              ),
              if (user.isVerified) ...[
                const SizedBox(width: 4),
                const Icon(Icons.verified, size: 16, color: Colors.blue),
              ],
            ],
          ).animate().fadeIn(delay: 150.ms).slideX(),

          const SizedBox(height: 12),

          // Bio
          if (user.bio != null && user.bio!.isNotEmpty)
            ...[
              Text(user.bio!, style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 12),
            ].animate(interval: 50.ms).fadeIn(),

          // Stats
          Row(
            children: [
              _StatItem(count: user.followingCount, label: "Following"),
              const SizedBox(width: 16),
              _StatItem(count: user.followersCount, label: "Followers"),
              if (user.college != null) ...[
                const SizedBox(width: 16),
                _StatItem(
                  count: 0,
                  label: user.college!,
                ), // Reuse StatItem for simplicity or create new
              ],
            ],
          ).animate().fadeIn(delay: 300.ms),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final int count;
  final String label;

  // Hacky reuse: if count is 0 and label is long, maybe treat differently?
  // But for now, standard.
  const _StatItem({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    if (count == 0 && (label.contains('Colege') || label.length > 10)) {
      // Just show text for college if passed
      return Text(
        label,
        style: TextStyle(color: Colors.grey[600], fontSize: 15),
      );
    }

    return Row(
      children: [
        Text(
          '$count',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 15)),
      ],
    );
  }
}

class _FollowButton extends ConsumerWidget {
  final String targetUserId;

  const _FollowButton({required this.targetUserId});

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
            backgroundColor: isFollowing ? Colors.white : Colors.black,
            foregroundColor: isFollowing ? Colors.black : Colors.white,
            side: isFollowing ? const BorderSide(color: Colors.grey) : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Text(isFollowing ? "Following" : "Follow"),
        );
      },
      loading: () => const CircularProgressIndicator.adaptive(),
      error: (_, __) => const SizedBox(),
    );
  }
}

class _UserPostsList extends ConsumerWidget {
  final String userId;

  const _UserPostsList({required this.userId});

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
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text("No posts yet"),
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: userPosts.length,
          separatorBuilder: (context, index) =>
              Divider(height: 1, color: Colors.grey[200]),
          itemBuilder: (context, index) {
            // Reusing PostCard logic but possibly needing to expose it or duplicate
            final post = userPosts[index];
            return ListTile(
              title: Text(post.content),
              subtitle: Text(timeago.format(post.timestamp)),
            );
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
