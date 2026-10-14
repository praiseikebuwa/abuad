import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../auth/data/auth_repository.dart';
import '../../feed/data/post_repository.dart';
import '../../feed/domain/post.dart' as domain;
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/widgets/verification_badge.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/utils/url_validator.dart';
import '../../feed/presentation/widgets/post_card.dart';
import '../../chat/data/chat_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/firebase_storage_service.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../feed/data/bookmark_folders_service.dart';

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
    final cachedCurrentUser = authRepo.currentUser;
    final currentUserId = cachedCurrentUser?.uid ?? authRepo.currentUserId;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Determine which user to show
    final targetUserId = widget.userId ?? currentUserId;

    if (targetUserId == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_circle_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text("Please sign in to view your profile", style: TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                child: const Text("Sign In"),
              ),
            ],
          ),
        ),
      );
    }

    final userAsync = ref.watch(userProvider(targetUserId));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go('/');
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: userAsync.when(
          data: (fetchedUser) {
            final user = fetchedUser ?? (targetUserId == currentUserId ? cachedCurrentUser : null);
            if (user == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.person_off_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text("User not found", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => ref.refresh(userProvider(targetUserId)),
                      icon: const Icon(Icons.refresh),
                      label: const Text("Retry"),
                    ),
                  ],
                ),
              );
            }
          final isCurrentUser = currentUserId == user.uid;

          return DefaultTabController(
            length: isCurrentUser ? 5 : 4,
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    expandedHeight: 0,
                    pinned: true,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    surfaceTintColor: Colors.transparent,
                    backgroundColor: innerBoxIsScrolled
                        ? (isDark ? AppColors.surfaceDark : AppColors.surfaceLight)
                        : Colors.transparent,
                    iconTheme: IconThemeData(
                      color: innerBoxIsScrolled
                          ? (isDark ? Colors.white : Colors.black)
                          : Colors.white,
                    ),
                    title: innerBoxIsScrolled
                        ? Text(
                            user.displayName,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          )
                        : null,
                    leading: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CircleAvatar(
                        backgroundColor: innerBoxIsScrolled
                            ? Colors.transparent
                            : Colors.black.withValues(alpha: 0.35),
                        child: IconButton(
                          icon: Icon(
                            Icons.arrow_back,
                            color: innerBoxIsScrolled
                                ? (isDark ? Colors.white : Colors.black)
                                : Colors.white,
                            size: 20,
                          ),
                          onPressed: () {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            } else {
                              context.go('/');
                            }
                          },
                        ),
                      ),
                    ),
                    actions: [
                      if (isCurrentUser)
                        IconButton(
                          icon: Icon(
                            Icons.settings_outlined,
                            color: innerBoxIsScrolled
                                ? (isDark ? Colors.white : Colors.black)
                                : Colors.white,
                          ),
                          onPressed: () => context.push('/settings'),
                        ),
                    ],
                  ),

                  // Profile Info & Banner
                  SliverToBoxAdapter(
                    child: _ProfileHeader(
                      user: user,
                      isCurrentUser: isCurrentUser,
                      currentUserId: currentUserId,
                      isDark: isDark,
                      onAvatarTap: () => _showFullImage(
                        context,
                        user.avatarUrl,
                        user.displayName,
                      ),
                      onEditAvatar: () => _updateProfileImage(
                        context,
                        ref,
                        user,
                      ),
                      onEditBanner: () => _updateBannerImage(
                        context,
                        ref,
                        user,
                      ),
                    ),
                  ),

                  // Sticky Tabs
                  SliverPersistentHeader(
                    delegate: _SliverAppBarDelegate(
                      TabBar(
                        isScrollable: isCurrentUser,
                        tabAlignment: isCurrentUser ? TabAlignment.start : TabAlignment.fill,
                        labelColor: isDark ? Colors.white : Colors.black87,
                        unselectedLabelColor: isDark
                            ? Colors.grey[500]
                            : Colors.grey[600],
                        indicatorColor: theme.colorScheme.secondary,
                        indicatorWeight: 3,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                        tabs: [
                          const Tab(text: "Posts"),
                          const Tab(text: "Replies"),
                          const Tab(text: "Media"),
                          const Tab(text: "Likes"),
                          if (isCurrentUser) const Tab(text: "Saved"),
                        ],
                      ),
                      isDark: isDark,
                      backgroundColor: theme.scaffoldBackgroundColor,
                    ),
                    pinned: true,
                  ),
                ];
              },
              body: TabBarView(
                children: [
                  _UserPostsList(userId: user.uid, isDark: isDark),
                  _UserRepliesList(userId: user.uid, isDark: isDark),
                  _UserMediaList(userId: user.uid, isDark: isDark),
                  _UserLikesList(userId: user.uid, isDark: isDark),
                  if (isCurrentUser)
                    _UserSavedPostsList(userId: user.uid, isDark: isDark),
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
      ),
    );
  }

  void _showFullImage(
    BuildContext context,
    String? imageUrl,
    String displayName,
  ) {
    if (imageUrl == null ||
        imageUrl.isEmpty ||
        !UrlValidator.isValidUrl(imageUrl)) {
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                placeholder: (context, url) =>
                    const CircularProgressIndicator(),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.error, color: Colors.white),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateProfileImage(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
  ) async {
    final picker = ImagePicker();
    final result = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        top: false,
        child: Wrap(
          children: [
            Material(
              color: Colors.transparent,
              child: ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final pickedFile = await picker.pickImage(
        source: result,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (pickedFile != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Uploading image...')));

        try {
          final storage = CloudStorageService();
          final url = await storage.uploadImage(
            pickedFile,
            path: 'profile_images/${user.uid}/',
          );

          if (url.isNotEmpty && context.mounted) {
            await ref.read(userRepositoryProvider).updateUser(user.uid, {
              'avatar_url': url,
              'avatarUrl': url,
            });
            ref.invalidate(userProvider(user.uid));
            await ref.read(authRepositoryProvider).init();
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
        final storage = CloudStorageService();
        final url = await storage.uploadImage(
          pickedFile,
          path: 'profile_images/${user.uid}/',
        );

        if (url.isNotEmpty && context.mounted) {
          await ref.read(userRepositoryProvider).updateUser(user.uid, {
            'banner_url': url,
            'bannerUrl': url,
          });
          ref.invalidate(userProvider(user.uid));
          await ref.read(authRepositoryProvider).init();
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
  final VoidCallback onAvatarTap;
  final VoidCallback onEditAvatar;
  final VoidCallback onEditBanner;

  const _ProfileHeader({
    required this.user,
    required this.isCurrentUser,
    required this.currentUserId,
    required this.isDark,
    required this.onAvatarTap,
    required this.onEditAvatar,
    required this.onEditBanner,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const double bannerHeight = 150.0;
    const double avatarRadius = 44.0;
    const double avatarDiameter = avatarRadius * 2;

    return Container(
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner + Overlapping Avatar Stack
          Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. Banner Image
              Container(
                height: bannerHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.grey[200],
                ),
                child: (user.bannerUrl != null &&
                        user.bannerUrl!.isNotEmpty &&
                        UrlValidator.isValidUrl(user.bannerUrl!))
                    ? CachedNetworkImage(
                        imageUrl: user.bannerUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: bannerHeight,
                        placeholder: (context, url) => Container(
                          color: isDark ? Colors.grey[800] : Colors.grey[300],
                        ),
                        errorWidget: (context, url, error) => Container(
                          decoration: const BoxDecoration(
                            gradient: AppColors.inkTealGradient,
                          ),
                        ),
                      )
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: AppColors.inkTealGradient,
                        ),
                      ),
              ),

              // Edit Banner Button (Current User Only)
              if (isCurrentUser)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: IconButton(
                    onPressed: onEditBanner,
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),

              // 2. Avatar positioned over banner bottom boundary
              Positioned(
                top: bannerHeight - avatarRadius,
                left: 16,
                child: GestureDetector(
                  onTap: onAvatarTap,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark
                                ? AppColors.surfaceDark
                                : AppColors.surfaceLight,
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: avatarRadius,
                          backgroundColor: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFE2E8F0),
                          child: (user.avatarUrl != null &&
                                  user.avatarUrl!.isNotEmpty &&
                                  UrlValidator.isValidUrl(user.avatarUrl!))
                              ? ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: user.avatarUrl!,
                                    width: avatarDiameter,
                                    height: avatarDiameter,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      width: avatarDiameter,
                                      height: avatarDiameter,
                                      color: isDark
                                          ? const Color(0xFF1E293B)
                                          : const Color(0xFFE2E8F0),
                                      child: Center(
                                        child: Text(
                                          user.displayName.isNotEmpty
                                              ? user.displayName[0]
                                                  .toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            fontSize: 34,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.white
                                                : AppColors.primaryInk,
                                          ),
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                      width: avatarDiameter,
                                      height: avatarDiameter,
                                      color: isDark
                                          ? const Color(0xFF1E293B)
                                          : const Color(0xFFE2E8F0),
                                      child: Center(
                                        child: Text(
                                          user.displayName.isNotEmpty
                                              ? user.displayName[0]
                                                  .toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            fontSize: 34,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.white
                                                : AppColors.primaryInk,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : Container(
                                  width: avatarDiameter,
                                  height: avatarDiameter,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDark
                                        ? const Color(0xFF1E293B)
                                        : const Color(0xFFE2E8F0),
                                  ),
                                  child: Center(
                                    child: Text(
                                      user.displayName.isNotEmpty
                                          ? user.displayName[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        fontSize: 34,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : AppColors.primaryInk,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      // Streak Badge
                      if (user.streakCount > 0)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.surfaceDark
                                    : AppColors.surfaceLight,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  "🔥",
                                  style: TextStyle(fontSize: 11),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  "${user.streakCount}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Edit Avatar Camera Icon
                      if (isCurrentUser)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: onEditAvatar,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).colorScheme.secondary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.surfaceDark
                                      : AppColors.surfaceLight,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: AppColors.primaryInk,
                                size: 15,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Profile Body Below Banner
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Action Buttons Row (Right aligned with space on left for avatar)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(width: avatarDiameter + 4),
                    if (isCurrentUser)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () =>
                                context.push('/user/${user.uid}/share'),
                            icon: Icon(
                              Icons.share_outlined,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.primaryInk,
                            ),
                          ),
                          const SizedBox(width: 6),
                          OutlinedButton(
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
                                horizontal: 20,
                                vertical: 8,
                              ),
                            ),
                            child: const Text(
                              "Edit Profile",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      )
                    else
                      _ProfileActionButtons(targetUser: user, isDark: isDark),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  user.displayName,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ).animate().fadeIn(delay: 100.ms),

                const SizedBox(height: 2),

                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: user.handle));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.white),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Handle @${user.handle} copied to clipboard',
                              ),
                            ),
                          ],
                        ),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        backgroundColor: Colors.black87,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Text(
                        '@${user.handle}',
                        style: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                          fontSize: 15,
                        ),
                      ),
                      if (user.isVerified) ...[
                        const SizedBox(width: 4),
                        VerificationBadge(
                          type: user.verificationType,
                          size: 18,
                        ),
                      ],
                    ],
                  ),
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

                // College/Department
                if ((user.college != null && user.college!.isNotEmpty) ||
                    (user.department != null && user.department!.isNotEmpty)) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.school_outlined,
                        size: 16,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          (user.college != null && user.college!.isNotEmpty)
                              ? (user.department != null && user.department!.isNotEmpty
                                  ? '${user.college!} • ${user.department!}'
                                  : user.college!)
                              : user.department!,
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 13.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Phone Number
                if (user.phoneNumber != null &&
                    user.phoneNumber!.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.phone_outlined,
                        size: 16,
                        color: isDark ? Colors.grey[600] : Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        user.phoneNumber!,
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
                    GestureDetector(
                      onTap: () {
                        if (!isCurrentUser && !user.isFollowingVisible) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Following list is private"),
                            ),
                          );
                          return;
                        }
                        context.push(
                          '/user/${user.uid}/connections',
                          extra: {'initialIndex': 1},
                        );
                      },
                      child: _StatItem(
                        count: user.followingCount,
                        label: "Following",
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 24),
                    GestureDetector(
                      onTap: () {
                        context.push(
                          '/user/${user.uid}/connections',
                          extra: {'initialIndex': 0},
                        );
                      },
                      child: _StatItem(
                        count: user.followersCount,
                        label: "Followers",
                        isDark: isDark,
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 300.ms),

                const SizedBox(height: 16),

                // Social Links Swipable Carousel
                _SocialLinkPreviewCarousel(user: user, isDark: isDark)
                    .animate()
                    .fadeIn(delay: 350.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialLinkData {
  final String platformName;
  final String handleOrTitle;
  final String actionSubtitle;
  final String url;
  final dynamic icon;
  final Color brandColor;
  final Color iconColor;
  final String? avatarUrl;

  _SocialLinkData({
    required this.platformName,
    required this.handleOrTitle,
    required this.actionSubtitle,
    required this.url,
    required this.icon,
    required this.brandColor,
    this.iconColor = Colors.white,
    this.avatarUrl,
  });
}

class _SocialLinkPreviewCarousel extends StatelessWidget {
  final AppUser user;
  final bool isDark;

  const _SocialLinkPreviewCarousel({
    required this.user,
    required this.isDark,
  });

  String _extractRawUsername(String url) {
    try {
      final uri = Uri.parse(url.trim());
      final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segs.isNotEmpty) {
        final last = segs.last.replaceAll('@', '');
        if (last != 'add' && last != 'in' && last != 'user' && last != 'u') {
          return last;
        } else if (segs.length > 1) {
          return segs[segs.length - 2].replaceAll('@', '');
        }
      }
    } catch (_) {}
    return '';
  }

  String _cleanDisplayUrl(String rawUrl) {
    return rawUrl.trim().replaceAll(RegExp(r'^https?://(www\.)?'), '');
  }

  List<_SocialLinkData> _collectSocialLinks() {
    final links = <_SocialLinkData>[];

    if (user.snapchatUrl != null && user.snapchatUrl!.trim().isNotEmpty) {
      final url = user.snapchatUrl!.trim();
      final uName = _extractRawUsername(url);
      links.add(_SocialLinkData(
        platformName: 'Snapchat',
        handleOrTitle: uName.isNotEmpty ? '@$uName' : 'Snapchat',
        actionSubtitle: _cleanDisplayUrl(url),
        url: url,
        icon: FontAwesomeIcons.snapchat,
        brandColor: const Color(0xFFFFFC00),
        iconColor: Colors.black,
        avatarUrl: uName.isNotEmpty ? 'https://unavatar.io/snapchat/$uName' : null,
      ));
    }

    if (user.githubUrl != null && user.githubUrl!.trim().isNotEmpty) {
      final url = user.githubUrl!.trim();
      final uName = _extractRawUsername(url);
      links.add(_SocialLinkData(
        platformName: 'GitHub',
        handleOrTitle: uName.isNotEmpty ? '@$uName' : 'GitHub',
        actionSubtitle: _cleanDisplayUrl(url),
        url: url,
        icon: FontAwesomeIcons.github,
        brandColor: const Color(0xFF24292E),
        iconColor: Colors.white,
        avatarUrl: uName.isNotEmpty ? 'https://github.com/$uName.png' : null,
      ));
    }

    if (user.twitterUrl != null && user.twitterUrl!.trim().isNotEmpty) {
      final url = user.twitterUrl!.trim();
      final uName = _extractRawUsername(url);
      links.add(_SocialLinkData(
        platformName: 'Twitter / X',
        handleOrTitle: uName.isNotEmpty ? '@$uName' : 'Twitter',
        actionSubtitle: _cleanDisplayUrl(url),
        url: url,
        icon: FontAwesomeIcons.xTwitter,
        brandColor: const Color(0xFF14171A),
        iconColor: Colors.white,
        avatarUrl: uName.isNotEmpty ? 'https://unavatar.io/x/$uName' : null,
      ));
    }

    if (user.instagramUrl != null && user.instagramUrl!.trim().isNotEmpty) {
      final url = user.instagramUrl!.trim();
      final uName = _extractRawUsername(url);
      links.add(_SocialLinkData(
        platformName: 'Instagram',
        handleOrTitle: uName.isNotEmpty ? '@$uName' : 'Instagram',
        actionSubtitle: _cleanDisplayUrl(url),
        url: url,
        icon: FontAwesomeIcons.instagram,
        brandColor: const Color(0xFFE4405F),
        iconColor: Colors.white,
        avatarUrl: uName.isNotEmpty ? 'https://unavatar.io/instagram/$uName' : null,
      ));
    }

    if (user.linkedinUrl != null && user.linkedinUrl!.trim().isNotEmpty) {
      final url = user.linkedinUrl!.trim();
      final uName = _extractRawUsername(url);
      links.add(_SocialLinkData(
        platformName: 'LinkedIn',
        handleOrTitle: uName.isNotEmpty ? '@$uName' : 'LinkedIn',
        actionSubtitle: _cleanDisplayUrl(url),
        url: url,
        icon: FontAwesomeIcons.linkedin,
        brandColor: const Color(0xFF0A66C2),
        iconColor: Colors.white,
        avatarUrl: uName.isNotEmpty ? 'https://unavatar.io/linkedin/$uName' : null,
      ));
    }

    if (user.youtubeUrl != null && user.youtubeUrl!.trim().isNotEmpty) {
      final url = user.youtubeUrl!.trim();
      final uName = _extractRawUsername(url);
      links.add(_SocialLinkData(
        platformName: 'YouTube',
        handleOrTitle: uName.isNotEmpty ? '@$uName' : 'YouTube',
        actionSubtitle: _cleanDisplayUrl(url),
        url: url,
        icon: FontAwesomeIcons.youtube,
        brandColor: const Color(0xFFFF0000),
        iconColor: Colors.white,
        avatarUrl: uName.isNotEmpty ? 'https://unavatar.io/youtube/$uName' : null,
      ));
    }

    if (user.tiktokUrl != null && user.tiktokUrl!.trim().isNotEmpty) {
      final url = user.tiktokUrl!.trim();
      final uName = _extractRawUsername(url);
      links.add(_SocialLinkData(
        platformName: 'TikTok',
        handleOrTitle: uName.isNotEmpty ? '@$uName' : 'TikTok',
        actionSubtitle: _cleanDisplayUrl(url),
        url: url,
        icon: FontAwesomeIcons.tiktok,
        brandColor: const Color(0xFF010101),
        iconColor: Colors.white,
        avatarUrl: uName.isNotEmpty ? 'https://unavatar.io/tiktok/$uName' : null,
      ));
    }

    if (user.facebookUrl != null && user.facebookUrl!.trim().isNotEmpty) {
      final url = user.facebookUrl!.trim();
      final uName = _extractRawUsername(url);
      links.add(_SocialLinkData(
        platformName: 'Facebook',
        handleOrTitle: uName.isNotEmpty ? '@$uName' : 'Facebook',
        actionSubtitle: _cleanDisplayUrl(url),
        url: url,
        icon: FontAwesomeIcons.facebook,
        brandColor: const Color(0xFF1877F2),
        iconColor: Colors.white,
        avatarUrl: uName.isNotEmpty ? 'https://unavatar.io/facebook/$uName' : null,
      ));
    }

    if (user.twitchUrl != null && user.twitchUrl!.trim().isNotEmpty) {
      final url = user.twitchUrl!.trim();
      final uName = _extractRawUsername(url);
      links.add(_SocialLinkData(
        platformName: 'Twitch',
        handleOrTitle: uName.isNotEmpty ? '@$uName' : 'Twitch',
        actionSubtitle: _cleanDisplayUrl(url),
        url: url,
        icon: FontAwesomeIcons.twitch,
        brandColor: const Color(0xFF9146FF),
        iconColor: Colors.white,
        avatarUrl: uName.isNotEmpty ? 'https://unavatar.io/twitch/$uName' : null,
      ));
    }

    if (user.websiteUrl != null && user.websiteUrl!.trim().isNotEmpty) {
      final url = user.websiteUrl!.trim();
      final clean = _cleanDisplayUrl(url);
      final domain = clean.split('/').first;
      links.add(_SocialLinkData(
        platformName: 'Website',
        handleOrTitle: domain,
        actionSubtitle: clean,
        url: url,
        icon: FontAwesomeIcons.globe,
        brandColor: const Color(0xFF0284C7),
        iconColor: Colors.white,
        avatarUrl: 'https://unavatar.io/$domain',
      ));
    }

    return links;
  }

  @override
  Widget build(BuildContext context) {
    final links = _collectSocialLinks();
    if (links.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              "Social Media Profiles",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            if (links.length > 1) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.swipe_left_rounded,
                size: 16,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
              const SizedBox(width: 2),
              Text(
                "Swipe",
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 72,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: links.length,
            itemBuilder: (context, index) {
              final link = links[index];
              return _SocialPreviewCard(link: link, isDark: isDark);
            },
          ),
        ),
      ],
    );
  }
}

class _SocialPreviewCard extends StatelessWidget {
  final _SocialLinkData link;
  final bool isDark;

  const _SocialPreviewCard({
    required this.link,
    required this.isDark,
  });

  Future<void> _launchUrl() async {
    final uri = Uri.parse(link.url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Error launching URL: $e");
    }
  }

  Widget _buildFallbackIcon() {
    return Center(
      child: (link.icon is IconData && link.icon is! FaIconData)
          ? Icon(
              link.icon as IconData,
              size: 22,
              color: link.iconColor,
            )
          : FaIcon(
              link.icon as dynamic,
              size: 22,
              color: link.iconColor,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgCardColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

    return Container(
      width: 250,
      margin: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _launchUrl,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: bgCardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: link.brandColor.withValues(alpha: isDark ? 0.4 : 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: link.brandColor.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Circle Profile Picture / Platform Logo
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: link.brandColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: (link.avatarUrl != null && link.avatarUrl!.isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: link.avatarUrl!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => _buildFallbackIcon(),
                            errorWidget: (context, url, error) => _buildFallbackIcon(),
                          )
                        : _buildFallbackIcon(),
                  ),
                ),
                const SizedBox(width: 12),
                // Text details: White Title (Name) & Green Subtitle (Clean URL path)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // White Name / Handle
                      Text(
                        link.handleOrTitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                          overflow: TextOverflow.ellipsis,
                        ),
                        maxLines: 1,
                      ),
                      const SizedBox(height: 2),
                      // Green Text showing extracted link path
                      Text(
                        link.actionSubtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF22C55E), // Vibrant Green
                          overflow: TextOverflow.ellipsis,
                        ),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
              ],
            ),
          ),
        ),
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

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
    } else if (count >= 10000) {
      return '${(count / 1000).toStringAsFixed(1).replaceAll('.0', '')}k';
    } else if (count >= 1000) {
      return NumberFormat('#,###').format(count);
    }
    return '$count';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          _formatCount(count),
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

class _ProfileActionButtons extends ConsumerStatefulWidget {
  final AppUser targetUser;
  final bool isDark;

  const _ProfileActionButtons({required this.targetUser, required this.isDark});

  @override
  ConsumerState<_ProfileActionButtons> createState() =>
      _ProfileActionButtonsState();
}

class _ProfileActionButtonsState extends ConsumerState<_ProfileActionButtons> {
  bool _isCreatingChannel = false;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(userRepositoryProvider);
    final chatRepo = ref.watch(chatRepositoryProvider);
    final targetUserId = widget.targetUser.uid;

    final isFollowingAsync = ref.watch(isFollowingProvider(targetUserId));
    final currentUserAsync = ref.watch(currentUserProvider);
    final isBlockedAsync = ref.watch(isBlockedProvider(targetUserId));

    return isBlockedAsync.when(
      data: (isBlocked) {
        if (isBlocked) {
          return ElevatedButton(
            onPressed: () => repo.unblockUser(targetUserId),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            ),
            child: const Text(
              "Unblock",
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          );
        }

        return Row(
          children: [
            // Message Button
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: _isCreatingChannel
                  ? const SizedBox(
                      width: 42,
                      height: 42,
                      child: Padding(
                        padding: EdgeInsets.all(11.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(21),
                        onTap: () async {
                          HapticFeedback.mediumImpact();
                          final currentUser = currentUserAsync.value ?? ref.read(authRepositoryProvider).currentUser;

                          setState(() => _isCreatingChannel = true);

                          try {
                            final channelId = await chatRepo.createOrGetChannel(
                              targetUserId,
                              otherUserName: widget.targetUser.displayName,
                              otherUserAvatar: widget.targetUser.avatarUrl,
                              currentUserName: currentUser?.displayName,
                              currentUserAvatar: currentUser?.avatarUrl,
                            ).timeout(const Duration(seconds: 15));
                            
                            if (context.mounted) {
                              context.push('/chat/$channelId');
                            }
                          } catch (e) {
                            if (context.mounted) {
                              String errorMessage = "Failed to open chat. Please check your connection.";
                              if (e.toString().contains('unavailable')) {
                                errorMessage = "Chat service is currently unavailable. Retrying soon...";
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(errorMessage),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: Colors.redAccent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _isCreatingChannel = false);
                            }
                          }
                        },
                        child: Ink(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: widget.isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.grey[200],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: widget.isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.chat_bubble_outline,
                              size: 20,
                              color: widget.isDark
                                  ? Colors.white
                                  : AppColors.primaryInk,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),

            // Follow/Unfollow Button
            isFollowingAsync.when(
              data: (isFollowing) {
                return ElevatedButton(
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    if (isFollowing) {
                      await repo.unfollowUser(targetUserId);
                    } else {
                      await repo.followUser(targetUserId);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFollowing
                        ? (widget.isDark ? Colors.transparent : Colors.white)
                        : (widget.isDark ? Colors.white : AppColors.primaryInk),
                    foregroundColor: isFollowing
                        ? (widget.isDark ? Colors.white : AppColors.primaryInk)
                        : (widget.isDark ? AppColors.primaryInk : Colors.white),
                    elevation: isFollowing ? 0 : 2,
                    side: BorderSide(
                      color: isFollowing
                          ? (widget.isDark
                                ? Colors.white.withValues(alpha: 0.2)
                                : const Color(0xFFE8E1D7))
                          : Colors.transparent,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                  ),
                  child: Text(
                    isFollowing ? "Unfollow" : "Follow",
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                );
              },
              loading: () => const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (error, stack) => const SizedBox(),
            ),

            // More Options (Block)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'share') {
                  context.push('/user/${widget.targetUser.uid}/share');
                } else if (value == 'block') {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Block User?'),
                      content: Text(
                        'Are you sure you want to block ${widget.targetUser.displayName}? They will no longer be able to see your profile or message you.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.orange,
                          ),
                          child: const Text('Block'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    await repo.blockUser(targetUserId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${widget.targetUser.displayName} blocked',
                          ),
                        ),
                      );
                    }
                  }
                }
              },
              icon: Icon(
                Icons.more_vert,
                color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share_outlined, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Share Profile',
                        style: TextStyle(color: Colors.blue),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'block',
                  child: Row(
                    children: [
                      Icon(Icons.block, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Block User',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
      loading: () => const SizedBox(),
      error: (_, _) => const SizedBox(),
    );
  }
}

class _UserPostsList extends ConsumerStatefulWidget {
  final String userId;
  final bool isDark;

  const _UserPostsList({required this.userId, required this.isDark});

  @override
  ConsumerState<_UserPostsList> createState() => _UserPostsListState();
}

class _UserPostsListState extends ConsumerState<_UserPostsList>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final userPostsAsync = ref.watch(userPostsProvider(widget.userId));

    return userPostsAsync.when(
      data: (userPosts) {
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
                    color: widget.isDark ? Colors.grey[700] : Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No posts yet",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: widget.isDark ? Colors.grey[500] : Colors.grey[600],
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
            color: widget.isDark ? Colors.grey[900] : Colors.grey[200],
          ),
          itemBuilder: (context, index) {
            final post = userPosts[index];
            return PostCard(post: post);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 48,
                color: widget.isDark ? Colors.orange[300] : Colors.orange[700],
              ),
              const SizedBox(height: 16),
              Text(
                "Something went wrong",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "We couldn't load the posts.\n($error)",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserRepliesList extends ConsumerStatefulWidget {
  final String userId;
  final bool isDark;

  const _UserRepliesList({required this.userId, required this.isDark});

  @override
  ConsumerState<_UserRepliesList> createState() => _UserRepliesListState();
}

class _UserRepliesListState extends ConsumerState<_UserRepliesList>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final userRepliesAsync = ref.watch(userRepliesProvider(widget.userId));

    return userRepliesAsync.when(
      data: (replies) {
        if (replies.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: widget.isDark ? Colors.grey[700] : Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No replies yet",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: widget.isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: replies.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            color: widget.isDark ? Colors.grey[900] : Colors.grey[200],
          ),
          itemBuilder: (context, index) {
            final reply = replies[index];
            final timestamp = reply['timestamp'] as int?;
            final postContent = reply['postContent'] as String?;
            final postAuthorName = reply['postAuthorName'] as String?;

            return InkWell(
              onTap: () {
                if (reply['postId'] != null && reply['postId'].toString().isNotEmpty) {
                  context.push('/post/${reply['postId']}');
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.reply_rounded,
                          size: 16,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          postAuthorName != null && postAuthorName.isNotEmpty
                              ? "Replied to $postAuthorName"
                              : "Replied to post",
                          style: TextStyle(
                            color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (timestamp != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            "• ${timeago.format(DateTime.fromMillisecondsSinceEpoch(timestamp), locale: 'en_short')}",
                            style: TextStyle(
                              color: widget.isDark
                                  ? Colors.grey[600]
                                  : Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (postContent != null && postContent.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: widget.isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border(
                            left: BorderSide(
                              color: Theme.of(context).colorScheme.secondary,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Text(
                          postContent,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      reply['content'] ?? '',
                      style: TextStyle(
                        fontSize: 15,
                        color: widget.isDark
                            ? Colors.white
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, stack) => const SizedBox(),
    );
  }
}

class _UserLikesList extends ConsumerStatefulWidget {
  final String userId;
  final bool isDark;

  const _UserLikesList({required this.userId, required this.isDark});

  @override
  ConsumerState<_UserLikesList> createState() => _UserLikesListState();
}

class _UserLikesListState extends ConsumerState<_UserLikesList>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final userLikesAsync = ref.watch(userLikesProvider(widget.userId));

    return userLikesAsync.when(
      data: (likedPosts) {
        if (likedPosts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 64,
                    color: widget.isDark ? Colors.grey[700] : Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No likes yet",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: widget.isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: likedPosts.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            color: widget.isDark ? Colors.grey[900] : Colors.grey[200],
          ),
          itemBuilder: (context, index) {
            final post = likedPosts[index];
            return PostCard(post: post);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, stack) => const SizedBox(),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(
    this._tabBar, {
    required this.isDark,
    required this.backgroundColor,
  });

  final TabBar _tabBar;
  final bool isDark;
  final Color backgroundColor;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

class _UserMediaList extends ConsumerStatefulWidget {
  final String userId;
  final bool isDark;

  const _UserMediaList({required this.userId, required this.isDark});

  @override
  ConsumerState<_UserMediaList> createState() => _UserMediaListState();
}

class _UserMediaListState extends ConsumerState<_UserMediaList>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final userMediaAsync = ref.watch(userMediaProvider(widget.userId));

    return userMediaAsync.when(
      data: (mediaPosts) {
        if (mediaPosts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_outlined,
                    size: 64,
                    color: widget.isDark ? Colors.grey[700] : Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No media yet",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: widget.isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(1),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 1,
            mainAxisSpacing: 1,
          ),
          itemCount: mediaPosts.length,
          itemBuilder: (context, index) {
            final post = mediaPosts[index];
            return GestureDetector(
              onTap: () {
                if (post.mediaType == domain.MediaType.video) {
                  context.push(
                    '/reels',
                    extra: {
                      'videos': [post],
                      'index': 0,
                    },
                  );
                } else {
                  context.push('/post-detail', extra: post);
                }
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: post.mediaUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: widget.isDark ? Colors.grey[800] : Colors.grey[200],
                    ),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.error),
                  ),
                  if (post.mediaType == domain.MediaType.video)
                    const Center(
                      child: Icon(
                        Icons.play_circle_fill,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, stack) => const SizedBox(),
    );
  }
}

class _UserSavedPostsList extends ConsumerStatefulWidget {
  final String userId;
  final bool isDark;

  const _UserSavedPostsList({required this.userId, required this.isDark});

  @override
  ConsumerState<_UserSavedPostsList> createState() => _UserSavedPostsListState();
}

class _UserSavedPostsListState extends ConsumerState<_UserSavedPostsList>
    with AutomaticKeepAliveClientMixin {
  String _selectedFolderId = 'all';

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final savedPostsAsync = ref.watch(savedPostsProvider(widget.userId));
    final folders = ref.watch(bookmarkFoldersProvider);

    return savedPostsAsync.when(
      data: (savedPosts) {
        if (savedPosts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bookmark_border_rounded,
                    size: 64,
                    color: widget.isDark ? Colors.grey[700] : Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No saved posts yet",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Tap the bookmark icon on any post to save it for later and organize into folders.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: widget.isDark ? Colors.grey[600] : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Filter posts according to selected folder
        final List<domain.Post> displayedPosts;
        if (_selectedFolderId == 'all') {
          displayedPosts = savedPosts;
        } else {
          final targetFolder = folders.firstWhere(
            (f) => f.id == _selectedFolderId,
            orElse: () => BookmarkFolder(id: '', name: '', emoji: '', postIds: {}),
          );
          displayedPosts = savedPosts.where((p) => targetFolder.postIds.contains(p.id)).toList();
        }

        return Column(
          children: [
            // Top Collections / Folders Bar
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: widget.isDark ? Colors.white10 : Colors.black12,
                    width: 0.5,
                  ),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // 'All' Filter Chip
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: _selectedFolderId == 'all',
                        avatar: const Text('📁', style: TextStyle(fontSize: 14)),
                        label: Text('All (${savedPosts.length})'),
                        selectedColor: AppColors.secondaryTeal.withValues(alpha: 0.2),
                        checkmarkColor: AppColors.secondaryTeal,
                        labelStyle: TextStyle(
                          color: _selectedFolderId == 'all'
                              ? AppColors.secondaryTeal
                              : (widget.isDark ? Colors.white70 : Colors.black87),
                          fontWeight: _selectedFolderId == 'all' ? FontWeight.bold : FontWeight.w500,
                          fontSize: 13,
                        ),
                        side: BorderSide(
                          color: _selectedFolderId == 'all'
                              ? AppColors.secondaryTeal
                              : (widget.isDark ? Colors.white12 : Colors.black12),
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        onSelected: (_) {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedFolderId = 'all');
                        },
                      ),
                    ),

                    // Folders Chips
                    ...folders.map((folder) {
                      final isSelected = _selectedFolderId == folder.id;
                      final count = savedPosts.where((p) => folder.postIds.contains(p.id)).length;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: isSelected,
                          avatar: Text(folder.emoji, style: const TextStyle(fontSize: 14)),
                          label: Text('${folder.name} ($count)'),
                          selectedColor: AppColors.secondaryTeal.withValues(alpha: 0.2),
                          checkmarkColor: AppColors.secondaryTeal,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppColors.secondaryTeal
                                : (widget.isDark ? Colors.white70 : Colors.black87),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 13,
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.secondaryTeal
                                : (widget.isDark ? Colors.white12 : Colors.black12),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          onSelected: (_) {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedFolderId = folder.id);
                          },
                        ),
                      );
                    }),

                    // + New Folder Button
                    ActionChip(
                      avatar: const Icon(Icons.add_rounded, size: 16, color: AppColors.secondaryTeal),
                      label: const Text('New Folder', style: TextStyle(color: AppColors.secondaryTeal, fontSize: 13)),
                      side: BorderSide(color: AppColors.secondaryTeal.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      backgroundColor: Colors.transparent,
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _showCreateFolderDialog();
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Posts List or Folder Empty State
            Expanded(
              child: displayedPosts.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_open_rounded,
                              size: 48,
                              color: widget.isDark ? Colors.grey[700] : Colors.grey[300],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "No posts in this collection yet",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Tap and hold the bookmark icon on any post to add it here.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: widget.isDark ? Colors.grey[600] : Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: displayedPosts.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: widget.isDark ? Colors.grey[900] : Colors.grey[200],
                      ),
                      itemBuilder: (context, index) {
                        final post = displayedPosts[index];
                        return PostCard(post: post);
                      },
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, stack) => Center(
        child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
      ),
    );
  }

  void _showCreateFolderDialog() {
    final controller = TextEditingController();
    String emoji = '📁';
    final emojis = ['📁', '📚', '🎟️', '🛍️', '😂', '⭐', '💡', '🔥', '🎵', '💻', '🎨'];

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Create New Collection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: emojis.map((e) {
                    final isSel = emoji == e;
                    return GestureDetector(
                      onTap: () => setDialogState(() => emoji = e),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSel ? AppColors.secondaryTeal.withValues(alpha: 0.2) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: isSel ? Border.all(color: AppColors.secondaryTeal) : null,
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 22)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Collection name (e.g. Internships)',
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  ref.read(bookmarkFoldersProvider.notifier).createFolder(name, emoji: emoji);
                  Navigator.of(dialogCtx).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondaryTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}

