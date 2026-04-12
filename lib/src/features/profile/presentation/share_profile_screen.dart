import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../user/data/user_repository.dart';
import '../../../core/widgets/verification_badge.dart';
import '../../../shared/widgets/user_avatar.dart';

class ShareProfileScreen extends ConsumerWidget {
  final String userId;

  const ShareProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProvider(userId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Use a deep link format or web URL
    final profileUrl = 'https://abuadapp.web.app/user/$userId';

    return Scaffold(
      backgroundColor: isDark ? AppColors.primaryInk : AppColors.surfaceLight,
      body: Stack(
        children: [
          // Background Gradient/Aesthetic
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          AppColors.primaryInk,
                          AppColors.secondaryTeal.withOpacity(0.5),
                        ]
                      : [
                          AppColors.surfaceLight,
                          AppColors.secondaryTeal.withOpacity(0.1),
                        ],
                ),
              ),
            ),
          ),

          // Floating Decorative Spheres (Subtle)
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondaryTeal.withOpacity(0.1),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: Icon(
                          Icons.close,
                          color: isDark ? Colors.white : AppColors.primaryInk,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Share Profile',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.primaryInk,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48), // Balance for back button
                    ],
                  ),
                ),

                Expanded(
                  child: userAsync.when(
                    data: (user) {
                      if (user == null) {
                        return const Center(child: Text('User not found'));
                      }
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const SizedBox(height: 20),
                            // Profile Card with Glassmorphism
                            ClipRRect(
                              borderRadius: BorderRadius.circular(32),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  padding: const EdgeInsets.all(32),
                                  decoration: BoxDecoration(
                                    color: (isDark ? Colors.white : AppColors.primaryInk)
                                        .withOpacity(isDark ? 0.05 : 0.03),
                                    borderRadius: BorderRadius.circular(32),
                                    border: Border.all(
                                      color: (isDark ? Colors.white : AppColors.primaryInk)
                                          .withOpacity(0.1),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      // User Avatar
                                      UserAvatar(
                                        userId: user.uid,
                                        avatarUrl: user.avatarUrl,
                                        displayName: user.displayName,
                                        radius: 42,
                                        showStoryRing: false,
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            user.displayName,
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : AppColors.primaryInk,
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
                                      Text(
                                        '@${user.handle}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: (isDark ? Colors.white : AppColors.primaryInk)
                                              .withOpacity(0.6),
                                        ),
                                      ),
                                      const SizedBox(height: 32),
                                      // QR Code
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(24),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.1),
                                              blurRadius: 20,
                                              offset: const Offset(0, 10),
                                            ),
                                          ],
                                        ),
                                        child: QrImageView(
                                          data: profileUrl,
                                          version: QrVersions.auto,
                                          size: 200.0,
                                          eyeStyle: const QrEyeStyle(
                                            eyeShape: QrEyeShape.square,
                                            color: AppColors.primaryInk,
                                          ),
                                          dataModuleStyle: const QrDataModuleStyle(
                                            dataModuleShape: QrDataModuleShape.square,
                                            color: AppColors.primaryInk,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Text(
                                        'Scan to view profile',
                                        style: TextStyle(
                                          color: (isDark ? Colors.white : AppColors.primaryInk)
                                              .withOpacity(0.5),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 48),
                            // Action Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: _ActionButton(
                                    icon: Icons.link,
                                    label: 'Copy Link',
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: profileUrl));
                                      HapticFeedback.mediumImpact();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: const Text('Link copied to clipboard'),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          backgroundColor: AppColors.secondaryTeal,
                                        ),
                                      );
                                    },
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _ActionButton(
                                    icon: Icons.share_outlined,
                                    label: 'Share via...',
                                    onTap: () {
                                      Share.share(
                                        'Check out ${user.displayName}\'s profile on ABUAD App: $profileUrl',
                                      );
                                    },
                                    isDark: isDark,
                                    isPrimary: true,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Center(child: Text('Error: $e')),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;
  final bool isPrimary;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isPrimary
        ? AppColors.secondaryTeal
        : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05));
    final textColor = isPrimary
        ? Colors.white
        : (isDark ? Colors.white : AppColors.primaryInk);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: isPrimary ? null : Border.all(
            color: (isDark ? Colors.white : AppColors.primaryInk).withOpacity(0.1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
