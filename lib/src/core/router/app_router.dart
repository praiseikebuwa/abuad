import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/camera/presentation/camera_screen.dart';

import '../../features/feed/presentation/feed_screen.dart';
import '../../features/feed/presentation/create_post_screen.dart';
import '../../features/feed/presentation/post_detail_screen.dart';
import '../../features/feed/presentation/hashtag_feed_screen.dart';
import '../../features/chat/presentation/chat_list_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/chat/presentation/user_search_screen.dart';
import '../../features/chat/presentation/create_group_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/chat/presentation/chat_info_screen.dart';
import '../../features/chat/presentation/group_settings_screen.dart';
import '../../features/chat/presentation/chat_settings_screen.dart';
import '../../features/map/presentation/map_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/share_profile_screen.dart';
import '../../shared/widgets/scaffold_with_bottom_nav.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/presentation/complete_profile_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/banned_screen.dart';
import '../../features/auth/data/auth_repository.dart';
import '../providers/shared_preferences_provider.dart';
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
import '../../features/user/presentation/user_list_screen.dart';
import '../../features/stories/domain/story.dart';
import '../../features/stories/presentation/story_viewer_screen.dart';
import '../../features/chat/presentation/qr_scanner_screen.dart';
import '../../features/chat/presentation/broadcast_search_screen.dart';
import '../../features/chat/presentation/broadcast_message_screen.dart';
import '../../features/settings/presentation/support_screens.dart';
import '../../features/settings/presentation/legal_screen.dart';
import '../../features/ai/presentation/ai_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final _feedNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'feed');
final _chatNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'chat');
final _mapNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'map');
final _profileNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'profile');

CustomTransitionPage<T> buildPageWithAnimation<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
  Duration duration = const Duration(milliseconds: 220),
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fadeAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      final slideAnimation = Tween<Offset>(
        begin: const Offset(0.0, 0.04),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      ));

      return FadeTransition(
        opacity: fadeAnimation,
        child: SlideTransition(
          position: slideAnimation,
          child: child,
        ),
      );
    },
  );
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(
      // Only watch user data if logged in to avoid empty document path errors
      authRepo.currentUser != null
          ? ref
                .watch(userRepositoryProvider)
                .watchUser(authRepo.currentUser!.uid)
          : authRepo.authStateChanges,
    ),
    redirect: (context, state) {
      final isLoggedIn = authRepo.currentUser != null;
      final isFirstLaunch = ref
          .read(firstLaunchRepositoryProvider)
          .isFirstLaunch();

      final isLoggingIn = state.uri.toString() == '/login';
      final isSigningUp = state.uri.toString() == '/signup';
      final isOnboarding = state.uri.toString() == '/onboarding';
      final isCompletingProfile = state.uri.toString() == '/complete-profile';
      final isBanned = state.uri.toString() == '/banned';

      if (isFirstLaunch && !isOnboarding) {
        return '/onboarding';
      }

      if (!isLoggedIn &&
          !isLoggingIn &&
          !isSigningUp &&
          !isOnboarding) {
        return '/login';
      }

      if (isLoggedIn) {
        if (isOnboarding) return null;

        final user = authRepo.currentUser;
        if (user != null) {
          final isIncomplete =
              user.department == null || user.department!.trim().isEmpty;

          if (user.isBanned && !isBanned) {
            return '/banned';
          }

          if (isIncomplete && !isCompletingProfile) {
            return '/complete-profile';
          }

          if (!isIncomplete &&
              (isLoggingIn || isSigningUp || isCompletingProfile || isBanned)) {
            return '/';
          }
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        redirect: (context, state) => '/',
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/complete-profile',
        builder: (context, state) => const CompleteProfileScreen(),
      ),
      GoRoute(
        path: '/create-post',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Map<String, dynamic>) {
            return CreatePostScreen(
              initialChannelId: extra['channelId'],
              initialMedia: extra['media'],
              initialMode: extra['mode'],
            );
          }
          final channelId = extra as String?;
          return CreatePostScreen(initialChannelId: channelId);
        },
      ),
      GoRoute(
        path: '/banned',
        builder: (context, state) => const BannedScreen(),
      ),
      GoRoute(
        path: '/camera',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return CameraScreen(
            isForStory: extra?['isForStory'] ?? false,
            onMediaCaptured: extra?['onMediaCaptured'],
          );
        },
      ),
      GoRoute(
        path: '/stories/:userId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final userId = state.pathParameters['userId']!;
          final storiesGrouped = state.extra as Map<String, List<Story>>? ?? {};
          return StoryViewerScreen(
            storiesGrouped: storiesGrouped,
            initialUserId: userId,
          );
        },
      ),
      GoRoute(
        path: '/user/:userId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final userId = state.pathParameters['userId'];
          return ProfileScreen(userId: userId);
        },
        routes: [
          GoRoute(
            path: 'connections',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) {
              final userId = state.pathParameters['userId']!;
              final extra = state.extra as Map<String, dynamic>?;
              final initialIndex = extra?['initialIndex'] as int? ?? 0;
              return UserListScreen(userId: userId, initialIndex: initialIndex);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/user/:userId/share',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final userId = state.pathParameters['userId']!;
          return ShareProfileScreen(userId: userId);
        },
      ),
      GoRoute(
        path: '/events',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => buildPageWithAnimation(
          context: context,
          state: state,
          child: const EventsScreen(),
        ),
      ),
      GoRoute(
        path: '/resources',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => buildPageWithAnimation(
          context: context,
          state: state,
          child: const ResourcesScreen(),
        ),
      ),
      GoRoute(
        path: '/groups',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => buildPageWithAnimation(
          context: context,
          state: state,
          child: const GroupsScreen(),
        ),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => buildPageWithAnimation(
          context: context,
          state: state,
          child: const SettingsScreen(),
        ),
        routes: [
          GoRoute(
            path: 'help',
            parentNavigatorKey: rootNavigatorKey,
            pageBuilder: (context, state) => buildPageWithAnimation(
              context: context,
              state: state,
              child: const HelpCenterScreen(),
            ),
          ),
          GoRoute(
            path: 'support',
            parentNavigatorKey: rootNavigatorKey,
            pageBuilder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return buildPageWithAnimation(
                context: context,
                state: state,
                child: SupportFormScreen(
                  title: extra?['title'] ?? 'Support',
                  type: extra?['type'] ?? 'feedback',
                ),
              );
            },
          ),
          GoRoute(
            path: 'privacy',
            parentNavigatorKey: rootNavigatorKey,
            pageBuilder: (context, state) => buildPageWithAnimation(
              context: context,
              state: state,
              child: const LegalScreen(
                title: 'Privacy Policy',
                markdownPath: 'assets/legal/privacy_policy.md',
              ),
            ),
          ),
          GoRoute(
            path: 'terms',
            parentNavigatorKey: rootNavigatorKey,
            pageBuilder: (context, state) => buildPageWithAnimation(
              context: context,
              state: state,
              child: const LegalScreen(
                title: 'Terms of Service',
                markdownPath: 'assets/legal/terms_of_service.md',
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => buildPageWithAnimation(
          context: context,
          state: state,
          child: const NotificationsScreen(),
        ),
      ),
      GoRoute(
        path: '/ai',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => buildPageWithAnimation(
          context: context,
          state: state,
          child: const AiScreen(),
        ),
      ),
      GoRoute(
        path: '/reels',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final payload = state.extra;
          List<Post> videos = [];
          int initialIndex = 0;
          if (payload is Map<String, dynamic>) {
            final rawVideos = payload['videos'];
            if (rawVideos is Iterable) {
              videos = rawVideos.whereType<Post>().toList();
            }
            initialIndex = (payload['initialIndex'] as int?) ??
                (payload['index'] as int?) ??
                0;
          } else if (payload is List<Post>) {
            videos = payload;
          } else if (payload is Post) {
            videos = [payload];
          }
          return ReelsScreen(
            videos: videos,
            initialIndex: initialIndex,
          );
        },
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
                      final payload = state.extra;
                      List<Post> videos = [];
                      int initialIndex = 0;
                      if (payload is Map<String, dynamic>) {
                        final rawVideos = payload['videos'];
                        if (rawVideos is Iterable) {
                          videos = rawVideos.whereType<Post>().toList();
                        }
                        initialIndex = (payload['initialIndex'] as int?) ??
                            (payload['index'] as int?) ??
                            0;
                      } else if (payload is List<Post>) {
                        videos = payload;
                      } else if (payload is Post) {
                        videos = [payload];
                      }
                      return ReelsScreen(
                        videos: videos,
                        initialIndex: initialIndex,
                      );
                    },
                  ),
                  GoRoute(
                    path: 'post/:postId',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final extra = state.extra;
                      final post = extra is Post ? extra : null;
                      final postId =
                          state.pathParameters['postId'] ??
                          state.uri.queryParameters['postId'];
                      return PostDetailScreen(post: post, postId: postId);
                    },
                  ),
                  // Keeping post-detail for backward compatibility if needed, but routing it to the above
                  GoRoute(
                    path: 'post-detail',
                    parentNavigatorKey: rootNavigatorKey,
                    redirect: (context, state) {
                      final postId = state.uri.queryParameters['postId'];
                      if (postId != null) {
                        return '/post/$postId';
                      }
                      return null;
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
                pageBuilder: (context, state) => buildPageWithAnimation(
                  context: context,
                  state: state,
                  child: const SearchScreen(),
                ),
              ),
            ],
          ),

          // 3. Map Branch
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
                      final item = state.extra;
                      if (item is! MarketplaceItem) {
                        // Extra was null or wrong type – go back to marketplace
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => Navigator.of(context).maybePop(),
                        );
                        return const MarketplaceScreen();
                      }
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
                    path: 'settings',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => buildPageWithAnimation(
                      context: context,
                      state: state,
                      child: const ChatSettingsScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'user-search',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => buildPageWithAnimation(
                      context: context,
                      state: state,
                      child: const UserSearchScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'create-group',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => buildPageWithAnimation(
                      context: context,
                      state: state,
                      child: const CreateGroupScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'scanner',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => buildPageWithAnimation(
                      context: context,
                      state: state,
                      child: const QRScannerScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'broadcast',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) => buildPageWithAnimation(
                      context: context,
                      state: state,
                      child: const BroadcastSearchScreen(),
                    ),
                    routes: [
                      GoRoute(
                        path: 'compose',
                        parentNavigatorKey: rootNavigatorKey,
                        pageBuilder: (context, state) {
                          final recipients = state.extra as List<AppUser>;
                          return buildPageWithAnimation(
                            context: context,
                            state: state,
                            child: BroadcastMessageScreen(recipients: recipients),
                          );
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: ':channelId',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final channelId = state.pathParameters['channelId']!;
                      final extra = state.extra;
                      MarketplaceItem? initialProduct;
                      String? initialText;
                      if (extra is MarketplaceItem) {
                        initialProduct = extra;
                        initialText = 'Hi, I\'m interested in your "${extra.title}" (₦${extra.price.toStringAsFixed(0)}). Is this still available?';
                      } else if (extra is Map<String, dynamic>) {
                        initialProduct = extra['initialProduct'] as MarketplaceItem?;
                        initialText = extra['initialText'] as String?;
                      } else if (extra is String) {
                        initialText = extra;
                      }
                      return ChatScreen(
                        channelId: channelId,
                        initialProduct: initialProduct,
                        initialText: initialText,
                      );
                    },
                    routes: [
                      GoRoute(
                        path: 'info',
                        parentNavigatorKey: rootNavigatorKey,
                        pageBuilder: (context, state) {
                          final channelId = state.pathParameters['channelId']!;
                          return buildPageWithAnimation(
                            context: context,
                            state: state,
                            child: ChatInfoScreen(channelId: channelId),
                          );
                        },
                      ),
                      GoRoute(
                        path: 'group-settings',
                        parentNavigatorKey: rootNavigatorKey,
                        pageBuilder: (context, state) {
                          final channelId = state.pathParameters['channelId']!;
                          return buildPageWithAnimation(
                            context: context,
                            state: state,
                            child: GroupSettingsScreen(channelId: channelId),
                          );
                        },
                      ),
                      GoRoute(
                        path: 'settings',
                        parentNavigatorKey: rootNavigatorKey,
                        pageBuilder: (context, state) {
                          final channelId = state.pathParameters['channelId']!;
                          return buildPageWithAnimation(
                            context: context,
                            state: state,
                            child: ChatSettingsScreen(channelId: channelId),
                          );
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
