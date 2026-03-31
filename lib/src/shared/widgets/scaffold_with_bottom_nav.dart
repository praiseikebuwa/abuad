import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/user/data/user_repository.dart';
import '../../features/chat/data/chat_repository.dart';

class ScaffoldWithBottomNav extends ConsumerWidget {
  const ScaffoldWithBottomNav({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch current user to enforce profile completion
    ref.listen(currentUserProvider, (previous, next) {
      if (next.value != null) {
        final user = next.value!;
        if (user.college == null ||
            user.department == null ||
            user.phoneNumber == null) {
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

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.fromLTRB(
              16,
              12, // Reduced top padding
              16,
              12 +
                  MediaQuery.of(
                    context,
                  ).padding.bottom, // Adjusted bottom padding
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.7),
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
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavItem(context, 0, Icons.home_outlined, Icons.home),
                _buildNavItem(
                  context,
                  1,
                  Icons.search,
                  Icons.search,
                  iconSize: 26,
                ),
                _buildNavItem(context, 2, Icons.map_outlined, Icons.map),
                _buildNavItem(
                  context,
                  3,
                  Icons.storefront_outlined,
                  Icons.storefront,
                ),
                _buildNavItem(
                  context,
                  4,
                  Icons.chat_bubble_outline,
                  Icons.chat_bubble,
                  badgeCount: unreadCount,
                ),
                _buildNavItem(context, 5, Icons.person_outline, Icons.person),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    int index,
    IconData outlineIcon,
    IconData filledIcon, {
    int badgeCount = 0,
    double iconSize = 28,
  }) {
    final isSelected = navigationShell.currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
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
                  : (isDark ? Colors.grey[600] : Colors.grey[500]),
            ),
            if (badgeCount > 0)
              Positioned(
                top: -5,
                right: -5,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
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

extension RowExtension on Row {
  // Helper to allow simpler list syntax in build method
  Row copyWith({List<Widget>? items}) {
    return Row(
      key: key,
      mainAxisAlignment: mainAxisAlignment,
      mainAxisSize: mainAxisSize,
      crossAxisAlignment: crossAxisAlignment,
      textDirection: textDirection,
      verticalDirection: verticalDirection,
      textBaseline: textBaseline,
      children: items ?? children,
    );
  }
}
