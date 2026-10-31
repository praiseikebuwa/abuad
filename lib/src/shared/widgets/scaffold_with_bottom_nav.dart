import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/user/data/user_repository.dart';
import '../../features/chat/data/chat_repository.dart';
import 'package:flutter/cupertino.dart';
import '../../features/audio_spaces/presentation/widgets/floating_audio_space_bar.dart';


class ScaffoldWithBottomNav extends ConsumerWidget {
  const ScaffoldWithBottomNav({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(currentUserProvider, (previous, next) {
      final user = next.value;
      if (user != null) {
        if (user.department == null || user.department!.trim().isEmpty) {
          final location = GoRouterState.of(context).uri.toString();
          if (location != '/complete-profile') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                context.go('/complete-profile');
              }
            });
          }
        }
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unreadCountAsync = ref.watch(unreadChatCountProvider);
    final unreadCount = unreadCountAsync.asData?.value ?? 0;
    final location = GoRouterState.of(context).uri.toString();
    final isAiActive = location.startsWith('/ai');

    return Scaffold(
      body: Stack(
        children: [
          navigationShell,
          const Positioned(
            left: 0,
            right: 0,
            bottom: 4,
            child: FloatingAudioSpaceBar(),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.9),
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.05),
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // 1. Home Feed
                  _buildNavItem(
                    context,
                    isSelected: navigationShell.currentIndex == 0,
                    outlineIcon: CupertinoIcons.house,
                    filledIcon: CupertinoIcons.house_fill,
                    onTap: () {
                      navigationShell.goBranch(
                        0,
                        initialLocation: navigationShell.currentIndex == 0,
                      );
                    },
                  ),

                  // 2. Chat
                  _buildNavItem(
                    context,
                    isSelected: navigationShell.currentIndex == 4,
                    outlineIcon: CupertinoIcons.chat_bubble,
                    filledIcon: CupertinoIcons.chat_bubble_fill,
                    badgeCount: unreadCount,
                    onTap: () {
                      navigationShell.goBranch(
                        4,
                        initialLocation: navigationShell.currentIndex == 4,
                      );
                    },
                  ),

                  // 3. Marketplace / Store (Center)
                  _buildNavItem(
                    context,
                    isSelected: navigationShell.currentIndex == 3,
                    outlineIcon: CupertinoIcons.cart_badge_minus,
                    filledIcon: CupertinoIcons.cart_fill,
                    onTap: () {
                      navigationShell.goBranch(
                        3,
                        initialLocation: navigationShell.currentIndex == 3,
                      );
                    },
                  ),

                  // 4. AI Assistant
                  _buildNavItem(
                    context,
                    isSelected: isAiActive,
                    outlineIcon: CupertinoIcons.sparkles,
                    filledIcon: CupertinoIcons.sparkles,
                    onTap: () {
                      context.push('/ai');
                    },
                  ),

                  // 5. Profile
                  _buildNavItem(
                    context,
                    isSelected: navigationShell.currentIndex == 5,
                    outlineIcon: CupertinoIcons.person,
                    filledIcon: CupertinoIcons.person_fill,
                    onTap: () {
                      navigationShell.goBranch(
                        5,
                        initialLocation: navigationShell.currentIndex == 5,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }



  Widget _buildNavItem(
    BuildContext context, {
    required bool isSelected,
    required IconData outlineIcon,
    required IconData filledIcon,
    required VoidCallback onTap,
    int badgeCount = 0,
    double iconSize = 24,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Icon(
              isSelected ? filledIcon : outlineIcon,
              size: iconSize,
              color: isSelected
                  ? (isDark ? Colors.white : Colors.black)
                  : (isDark ? Colors.grey[500] : Colors.grey[600]),
            ),
            if (badgeCount > 0)
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 15,
                    minHeight: 15,
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
