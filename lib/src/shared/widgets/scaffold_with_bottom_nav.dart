import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:badges/badges.dart' as badges;
import '../../features/user/data/user_repository.dart';

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

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: SafeArea(
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
    );
  }
}
