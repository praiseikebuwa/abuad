import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/feed/presentation/feed_screen.dart';
import '../../features/feed/presentation/create_post_screen.dart';
import '../../features/feed/presentation/post_detail_screen.dart';
import '../../features/chat/presentation/chat_list_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/chat/presentation/user_search_screen.dart';
import '../../features/map/presentation/map_screen.dart';
import '../../features/ai/presentation/ai_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../shared/widgets/scaffold_with_bottom_nav.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/events/presentation/events_screen.dart';
import '../../features/groups/presentation/groups_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _feedNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'feed');
final _chatNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'chat');
final _mapNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'map');
final _aiNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'ai');
final _profileNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'profile');

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isLoggingIn = state.uri.toString() == '/login';
      final isSigningUp = state.uri.toString() == '/signup';

      if (!isLoggedIn && !isLoggingIn && !isSigningUp) return '/login';
      if (isLoggedIn && (isLoggingIn || isSigningUp)) return '/';

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/user/:userId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final userId = state.pathParameters['userId'];
          return ProfileScreen(userId: userId);
        },
      ),
      GoRoute(
        path: '/events',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const EventsScreen(),
      ),
      GoRoute(
        path: '/groups',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const GroupsScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithBottomNav(navigationShell: navigationShell);
        },
        branches: [
          // Feed Branch
          StatefulShellBranch(
            navigatorKey: _feedNavigatorKey,
            routes: [
              GoRoute(
                path: '/',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: FeedScreen()),
                routes: [
                  GoRoute(
                    path: 'create-post',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) {
                      final extra = state.extra as String?;
                      return CreatePostScreen(
                        initialChannelId: extra ?? 'general',
                      );
                    },
                  ),
                  GoRoute(
                    path: 'post-detail',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) {
                      final post =
                          state.extra as dynamic; // casting to Post in real app
                      return PostDetailScreen(post: post);
                    },
                  ),
                ],
              ),
            ],
          ),
          // Chat Branch
          StatefulShellBranch(
            navigatorKey: _chatNavigatorKey,
            routes: [
              GoRoute(
                path: '/chat',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ChatListScreen()),
                routes: [
                  GoRoute(
                    path: 'user-search',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const UserSearchScreen(),
                  ),
                  GoRoute(
                    path: ':channelId',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) {
                      final channelId = state.pathParameters['channelId']!;
                      return ChatScreen(channelId: channelId);
                    },
                  ),
                ],
              ),
            ],
          ),
          // Map Branch
          StatefulShellBranch(
            navigatorKey: _mapNavigatorKey,
            routes: [
              GoRoute(
                path: '/map',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: MapScreen()),
              ),
            ],
          ),
          // AI Branch
          StatefulShellBranch(
            navigatorKey: _aiNavigatorKey,
            routes: [
              GoRoute(
                path: '/ai',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: AiScreen()),
              ),
            ],
          ),
          // Profile Branch
          StatefulShellBranch(
            navigatorKey: _profileNavigatorKey,
            routes: [
              GoRoute(
                path: '/profile',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ProfileScreen()),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
