import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/feed/presentation/feed_screen.dart';
import '../../features/feed/presentation/create_post_screen.dart';
import '../../features/feed/presentation/post_detail_screen.dart';
import '../../features/feed/presentation/hashtag_feed_screen.dart';
import '../../features/chat/presentation/chat_list_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/chat/presentation/user_search_screen.dart';
import '../../features/chat/presentation/create_group_screen.dart';
import '../../features/chat/presentation/group_info_screen.dart';
import '../../features/map/presentation/map_screen.dart';
import '../../features/ai/presentation/ai_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../shared/widgets/scaffold_with_bottom_nav.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/presentation/complete_profile_screen.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/events/presentation/events_screen.dart';
import '../../features/groups/presentation/groups_screen.dart';
import '../../features/resources/presentation/resources_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/marketplace/presentation/marketplace_screen.dart';
import '../../features/marketplace/presentation/marketplace_detail_screen.dart';
import '../../features/marketplace/data/marketplace_repository.dart';
import '../../features/feed/presentation/reels_screen.dart';
import '../../features/feed/domain/post.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final _feedNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'feed');
final _chatNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'chat');
final _mapNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'map');
final _aiNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'ai');
final _profileNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'profile');

final goRouterProvider = Provider<GoRouter>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(authRepo.authStateChanges),
    redirect: (context, state) {
      final isLoggedIn = authRepo.currentUser != null;
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
        path: '/complete-profile',
        builder: (context, state) => const CompleteProfileScreen(),
      ),
      GoRoute(
        path: '/user/:userId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final userId = state.pathParameters['userId'];
          return ProfileScreen(userId: userId);
        },
      ),
      GoRoute(
        path: '/events',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const EventsScreen(),
      ),
      GoRoute(
        path: '/resources',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ResourcesScreen(),
      ),
      GoRoute(
        path: '/groups',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const GroupsScreen(),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithBottomNav(navigationShell: navigationShell);
        },
        branches: [
          // 1. Feed Branch
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
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final extra = state.extra as String?;
                      return CreatePostScreen(
                        initialChannelId: extra ?? 'general',
                      );
                    },
                  ),
                  GoRoute(
                    path: 'reels',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final extra = state.extra as Map<String, dynamic>;
                      final videos = extra['videos'] as List<Post>;
                      final index = extra['index'] as int;
                      return ReelsScreen(videos: videos, initialIndex: index);
                    },
                  ),
                  GoRoute(
                    path: 'post-detail',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final extra = state.extra;
                      final post = extra is Post ? extra : null;
                      final postId = state.uri.queryParameters['postId'];
                      return PostDetailScreen(post: post, postId: postId);
                    },
                  ),
                  GoRoute(
                    path: 'hashtag/:tag',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final tag = state.pathParameters['tag']!;
                      return HashtagFeedScreen(hashtag: tag);
                    },
                  ),
                ],
              ),
            ],
          ),

          // 2. Search Branch
          StatefulShellBranch(
            navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'search'),
            routes: [
              GoRoute(
                path: '/search',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: SearchScreen()),
              ),
            ],
          ),

          // 3. AI Branch
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

          // 4. Map Branch
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

          // 5. Marketplace Branch
          StatefulShellBranch(
            navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'marketplace'),
            routes: [
              GoRoute(
                path: '/marketplace',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: MarketplaceScreen()),
                routes: [
                  GoRoute(
                    path: 'detail',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final item = state.extra as MarketplaceItem;
                      return MarketplaceDetailScreen(item: item);
                    },
                  ),
                ],
              ),
            ],
          ),

          // 6. Chat Branch
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
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const UserSearchScreen(),
                  ),
                  GoRoute(
                    path: 'create-group',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const CreateGroupScreen(),
                  ),
                  GoRoute(
                    path: ':channelId',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final channelId = state.pathParameters['channelId']!;
                      return ChatScreen(channelId: channelId);
                    },
                    routes: [
                      GoRoute(
                        path: 'info',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) {
                          final channelId = state.pathParameters['channelId']!;
                          return GroupInfoScreen(channelId: channelId);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // 7. Profile Branch
          StatefulShellBranch(
            navigatorKey: _profileNavigatorKey,
            routes: [
              GoRoute(
                path: '/profile',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ProfileScreen()),
                routes: [
                  GoRoute(
                    path: 'edit',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const EditProfileScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
