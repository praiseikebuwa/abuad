import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../auth/data/auth_repository.dart';
import '../../user/data/user_repository.dart';
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Determine which user to show
    final targetUserId = widget.userId ?? currentUserId;

    if (targetUserId == null) {
      return const Scaffold(body: Center(child: Text("Please sign in")));
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
        data: (user) {
          if (user == null) {
            return const Center(child: Text("User not found"));
          }
          final isCurrentUser = currentUserId == user.uid;

          return DefaultTabController(
            length: isCurrentUser ? 5 : 4,
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    expandedHeight: 180,
                    pinned: true,
                    clipBehavior: Clip.none, // Allow avatar overflow
                    backgroundColor: theme.scaffoldBackgroundColor,
                    iconTheme: IconThemeData(
                      color: innerBoxIsScrolled
                          ? (isDark ? Colors.white : Colors.black)
                          : Colors.white,
                    ),
                    leading: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CircleAvatar(
                        backgroundColor: Colors.black.withValues(alpha: 0.3),
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
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
                    flexibleSpace: Stack(
                      clipBehavior: Clip.none,
                      fit: StackFit.expand,
                      children: [
                        FlexibleSpaceBar(
                          background: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Banner Image
                              Container(
                                height: 150,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.grey[900]
                                      : Colors.grey[200],
                                ),
                                child:
                                    (user.bannerUrl != null &&
                                        user.bannerUrl!.isNotEmpty &&
                                        UrlValidator.isValidUrl(
                                          user.bannerUrl!,
                                        ))
                                    ? CachedNetworkImage(
                                        imageUrl: user.bannerUrl!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: 150,
                                        placeholder: (context, url) =>
                                            Container(
                                              color: isDark
                                                  ? Colors.grey[800]
                                                  : Colors.grey[300],
                                            ),
                                        errorWidget: (context, url, error) =>
                                            Container(
                                              decoration: const BoxDecoration(
                                                gradient:
                                                    AppColors.inkTealGradient,
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
                                    onPressed: () =>
                                        _updateBannerImage(context, ref, user),
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
                            ],
                          ),
                        ),
                        // Profile Avatar (Moved OUTSIDE FlexibleSpaceBar)
                        Positioned(
                          bottom: -50, // Half height overlap
                          left: 16,
                          child: GestureDetector(
                            onTap: () => _showFullImage(
                              context,
                              user.avatarUrl,
                              user.displayName,
                            ),
                            child: Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: theme.scaffoldBackgroundColor,
                                      width: 4,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 50, // Larger size
                                    backgroundColor: theme.colorScheme.secondary
                                        .withValues(alpha: 0.15),
                                    backgroundImage:
                                        (user.avatarUrl != null &&
                                            user.avatarUrl!.isNotEmpty &&
                                            UrlValidator.isValidUrl(
                                              user.avatarUrl!,
                                            ))
                                        ? CachedNetworkImageProvider(
                                            user.avatarUrl!,
                                          )
                                        : null,
                                    child: (user.avatarUrl == null ||
                                            user.avatarUrl!.isEmpty ||
                                            !UrlValidator.isValidUrl(
                                              user.avatarUrl!,
                                            ))
                                        ? Text(
                                            user.displayName.isNotEmpty
                                                ? user.displayName[0]
                                                      .toUpperCase()
                                                : '?',
                                            style: TextStyle(
                                              fontSize: 40,
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.primary,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                                // Streak Badge
                                if (user.streakCount > 0)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: theme.scaffoldBackgroundColor,
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.2,
                                            ),
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
                                            style: TextStyle(fontSize: 12),
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            "${user.streakCount}",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                // Edit Avatar Button (Current User Only)
                                if (isCurrentUser)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: () => _updateProfileImage(
                                        context,
                                        ref,
                                        user,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.secondary,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color:
                                                theme.scaffoldBackgroundColor,
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
                            ),
                          ),
                        ),
                      ],
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

                  // Profile Info (Scrolls away)
                  SliverToBoxAdapter(
                    child: _ProfileHeader(
                      user: user,
                      isCurrentUser: isCurrentUser,
                      currentUserId: currentUserId,
                      isDark: isDark,
                    ),
                  ),

                  // Sticky Tabs
                  SliverPersistentHeader(
                    delegate: _SliverAppBarDelegate(
                      TabBar(
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
      final pickedFile = await picker.pickImage(
        source: result,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (pickedFile != null && context.mounted) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Uploading image...')));

        try {
          final storage = FirebaseStorageService();
          final url = await storage.uploadImage(
            pickedFile,
            path: 'profile_images/${user.uid}/',
          );

          if (url.isNotEmpty && context.mounted) {
            await ref.read(userRepositoryProvider).updateUser(user.uid, {
              'avatar_url': url,
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
        final storage = FirebaseStorageService();
        final url = await storage.uploadImage(
          pickedFile,
          path: 'profile_images/${user.uid}/',
        );

        if (url.isNotEmpty && context.mounted) {
          await ref.read(userRepositoryProvider).updateUser(user.uid, {
            'banner_url': url,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action Button Only (since avatar moved to banner)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                isCurrentUser
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => context.push('/user/${user.uid}/share'),
                            icon: Icon(
                              Icons.share_outlined,
                              color: isDark ? Colors.white : AppColors.primaryInk,
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () => context.push('/profile/edit'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  isDark ? Colors.white : AppColors.primaryInk,
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
                          ),
                        ],
                      )
                    : _ProfileActionButtons(targetUser: user, isDark: isDark),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms),

          // User Info (shifted up)
          Transform.translate(
            offset: const Offset(0, -10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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

                // College/Location
                if (user.college != null && user.college!.isNotEmpty) ...[
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
                      if (user.department != null &&
                          user.department!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        const Text("•", style: TextStyle(color: Colors.grey)),
                        const SizedBox(width: 8),
                        Text(
                          user.department!,
                          style: TextStyle(
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
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

                // Social Links
                Row(
                  children: [
                    if (user.websiteUrl != null && user.websiteUrl!.isNotEmpty)
                      _SocialIcon(
                        icon: FontAwesomeIcons.globe,
                        url: user.websiteUrl!,
                        isDark: isDark,
                      ),
                    if (user.twitterUrl != null && user.twitterUrl!.isNotEmpty)
                      _SocialIcon(
                        icon: FontAwesomeIcons.xTwitter,
                        url: user.twitterUrl!,
                        isDark: isDark,
                        color: Colors.black,
                      ),
                    if (user.instagramUrl != null &&
                        user.instagramUrl!.isNotEmpty)
                      _SocialIcon(
                        icon: FontAwesomeIcons.instagram,
                        url: user.instagramUrl!,
                        isDark: isDark,
                        color: const Color(0xFFE4405F),
                      ),
                    if (user.facebookUrl != null &&
                        user.facebookUrl!.isNotEmpty)
                      _SocialIcon(
                        icon: FontAwesomeIcons.facebook,
                        url: user.facebookUrl!,
                        isDark: isDark,
                        color: const Color(0xFF1877F2),
                      ),
                    if (user.linkedinUrl != null &&
                        user.linkedinUrl!.isNotEmpty)
                      _SocialIcon(
                        icon: FontAwesomeIcons.linkedin,
                        url: user.linkedinUrl!,
                        isDark: isDark,
                        color: const Color(0xFF0077B5),
                      ),
                    if (user.tiktokUrl != null && user.tiktokUrl!.isNotEmpty)
                      _SocialIcon(
                        icon: FontAwesomeIcons.tiktok,
                        url: user.tiktokUrl!,
                        isDark: isDark,
                        color: Colors.black,
                      ),
                    if (user.youtubeUrl != null && user.youtubeUrl!.isNotEmpty)
                      _SocialIcon(
                        icon: FontAwesomeIcons.youtube,
                        url: user.youtubeUrl!,
                        isDark: isDark,
                        color: const Color(0xFFFF0000),
                      ),
                    if (user.snapchatUrl != null &&
                        user.snapchatUrl!.isNotEmpty)
                      _SocialIcon(
                        icon: FontAwesomeIcons.snapchat,
                        url: user.snapchatUrl!,
                        isDark: isDark,
                        color: const Color(0xFFFFFC00),
                        iconColor: Colors.black,
                      ),
                    if (user.githubUrl != null && user.githubUrl!.isNotEmpty)
                      _SocialIcon(
                        icon: FontAwesomeIcons.github,
                        url: user.githubUrl!,
                        isDark: isDark,
                        color: const Color(0xFF181717),
                      ),
                    if (user.twitchUrl != null && user.twitchUrl!.isNotEmpty)
                      _SocialIcon(
                        icon: Icons.gamepad,
                        url: user.twitchUrl!,
                        isDark: isDark,
                      ),
                  ],
                ).animate().fadeIn(delay: 350.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialIcon extends StatelessWidget {
  final dynamic icon;
  final String url;
  final bool isDark;
  final Color? color;
  final Color? iconColor;

  const _SocialIcon({
    required this.icon,
    required this.url,
    required this.isDark,
    this.color,
    this.iconColor,
  });

  Future<void> _launchUrl() async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Error launching URL: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: GestureDetector(
        onTap: _launchUrl,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color != null
                ? color!.withValues(alpha: isDark ? 0.15 : 0.1)
                : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100]),
            shape: BoxShape.circle,
            border: Border.all(
              color: color != null
                  ? color!.withValues(alpha: 0.3)
                  : (isDark ? Colors.white10 : Colors.grey[300]!),
              width: 1,
            ),
          ),
          child: (icon is IconData && icon is! FaIconData)
              ? Icon(
                  icon,
                  size: 16,
                  color:
                      iconColor ??
                      (color ??
                          (isDark ? Colors.grey[400] : AppColors.primaryInk)),
                )
              : FaIcon(
                  icon as dynamic,
                  size: 16,
                  color:
                      iconColor ??
                      (color ??
                          (isDark ? Colors.grey[400] : AppColors.primaryInk)),
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
                      width: 40,
                      height: 40,
                      child: Padding(
                        padding: EdgeInsets.all(10.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                    : GestureDetector(
                        onTap: () async {
                          HapticFeedback.mediumImpact();
                          final currentUser = currentUserAsync.value;
                          if (currentUser == null) return;

                          setState(() => _isCreatingChannel = true);

                          try {
                            final channelId = await chatRepo.createOrGetChannel(
                              targetUserId,
                              otherUserName: widget.targetUser.displayName,
                              otherUserAvatar: widget.targetUser.avatarUrl,
                              currentUserName: currentUser.displayName,
                              currentUserAvatar: currentUser.avatarUrl,
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
                        child: Container(
                          padding: const EdgeInsets.all(10),
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
                    isFollowing ? "Following" : "Follow",
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

    return StreamBuilder<List<domain.Post>>(
      stream: repo.watchUserPosts(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          final error = snapshot.error.toString();
          final isIndexError = error.contains('failed-precondition');

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 48,
                    color: isDark ? Colors.orange[300] : Colors.orange[700],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isIndexError
                        ? "Database Setup Required"
                        : "Something went wrong",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isIndexError
                        ? "This query requires an index. Check your console logs for the creation link."
                        : "We couldn't load the posts. Please try again later.\n($error)",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final userPosts = snapshot.data ?? [];

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

class _UserRepliesList extends ConsumerWidget {
  final String userId;
  final bool isDark;

  const _UserRepliesList({required this.userId, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(postRepositoryProvider);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: repo.watchUserReplies(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final replies = snapshot.data ?? [];

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
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No replies yet",
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
          itemCount: replies.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            color: isDark ? Colors.grey[900] : Colors.grey[200],
          ),
          itemBuilder: (context, index) {
            final reply = replies[index];
            final timestamp = reply['timestamp'] as int?;

            return InkWell(
              onTap: () {
                if (reply['postId'] != null) {
                  context.push('/post/${reply['postId']}');
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "Replied",
                          style: TextStyle(
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (timestamp != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            "• ${timeago.format(DateTime.fromMillisecondsSinceEpoch(timestamp), locale: 'en_short')}",
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey[600]
                                  : Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reply['content'] ?? '',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark
                            ? Colors.grey[300]
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _UserLikesList extends ConsumerWidget {
  final String userId;
  final bool isDark;

  const _UserLikesList({required this.userId, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(postRepositoryProvider);

    return StreamBuilder<List<domain.Post>>(
      stream: repo.watchUserLikes(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final likedPosts = snapshot.data ?? [];

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
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No likes yet",
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
          itemCount: likedPosts.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            color: isDark ? Colors.grey[900] : Colors.grey[200],
          ),
          itemBuilder: (context, index) {
            final post = likedPosts[index];
            return PostCard(post: post);
          },
        );
      },
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

class _UserMediaList extends ConsumerWidget {
  final String userId;
  final bool isDark;

  const _UserMediaList({required this.userId, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(postRepositoryProvider);

    return StreamBuilder<List<domain.Post>>(
      stream: repo.watchUserMedia(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final mediaPosts = snapshot.data ?? [];

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
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No media yet",
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
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
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
    );
  }
}

class _UserSavedPostsList extends ConsumerWidget {
  final String userId;
  final bool isDark;

  const _UserSavedPostsList({required this.userId, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Note: savedPostsProvider expects a String argument (userId)
    final savedPostsAsync = ref.watch(savedPostsProvider(userId));

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
                    Icons.bookmark_border,
                    size: 64,
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No saved posts",
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
          itemCount: savedPosts.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            color: isDark ? Colors.grey[900] : Colors.grey[200],
          ),
          itemBuilder: (context, index) {
            final post = savedPosts[index];
            return PostCard(post: post);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, stack) => Center(
        child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
      ),
    );
  }
}
