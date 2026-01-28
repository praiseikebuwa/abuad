import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:badges/badges.dart' as badges;
import '../../features/user/data/user_repository.dart';
import '../../features/feed/presentation/feed_screen.dart';

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
          // Check if we are already on the complete profile screen to avoid loop
          final location = GoRouterState.of(context).uri.toString();
          if (location != '/complete-profile') {
            context.go('/complete-profile');
          }
        }
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true, // Critical for edge-to-edge content behind nav bar
      body: navigationShell,
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withOpacity(0.7)
                  : Colors.white.withOpacity(0.8),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.05),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: SalomonBottomBar(
                  currentIndex: navigationShell.currentIndex,
                  onTap: (index) {
                    navigationShell.goBranch(
                      index,
                      initialLocation: index == navigationShell.currentIndex,
                    );
                  },
                  items: [
                    SalomonBottomBarItem(
                      icon: const Icon(Icons.home),
                      title: const Text("Feed"),
                      selectedColor: Colors.blue,
                    ),
                    SalomonBottomBarItem(
                      icon: badges.Badge(
                        showBadge: true,
                        badgeContent: const Text(
                          '3',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                        child: const Icon(Icons.chat_bubble),
                      ),
                      title: const Text("Chat"),
                      selectedColor: Colors.deepPurple,
                    ),
                    SalomonBottomBarItem(
                      icon: const Icon(Icons.map),
                      title: const Text("Map"),
                      selectedColor: Colors.green,
                    ),
                    SalomonBottomBarItem(
                      icon: const Icon(Icons.smart_toy),
                      title: const Text("AI"),
                      selectedColor: Colors.teal,
                    ),
                    SalomonBottomBarItem(
                      icon: const Icon(Icons.person),
                      title: const Text("Profile"),
                      selectedColor: Colors.orange,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: navigationShell.currentIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                final selectedChannel = ref.read(feedChannelProvider);
                context.push(
                  '/create-post',
                  extra: selectedChannel == 'all' ? 'general' : selectedChannel,
                );
              },
              backgroundColor: Theme.of(context).colorScheme.primary,
              shape: const CircleBorder(),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}
