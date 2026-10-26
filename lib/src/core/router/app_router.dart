import 'dart:async';
import 'package:abuad/src/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
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
import '../../features/chat/presentation/join_group_screen.dart';
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
import '../../features/search/presentation/hashtag_screen.dart';
import '../../features/marketplace/presentation/marketplace_screen.dart';
import '../../features/marketplace/presentation/marketplace_detail_screen.dart';
import '../../features/marketplace/presentation/seller_storefront_screen.dart';
import '../../features/marketplace/data/marketplace_repository.dart';
import '../../features/feed/presentation/reels_screen.dart';
import '../../features/feed/presentation/audio_track_screen.dart';
import '../../features/feed/domain/post.dart';
import '../../features/user/presentation/user_list_screen.dart';
import '../../features/stories/domain/story.dart';
import '../../features/stories/presentation/story_viewer_screen.dart';
import '../../features/advertisements/presentation/advertisements_screen.dart';
import '../../features/advertisements/presentation/create_advertisement_screen.dart';
import '../../features/chat/presentation/qr_scanner_screen.dart';
import '../../features/chat/presentation/broadcast_search_screen.dart';
import '../../features/chat/presentation/broadcast_message_screen.dart';
import '../../features/settings/presentation/support_screens.dart';
import '../../features/settings/presentation/legal_screen.dart';
import '../../features/ai/presentation/ai_screen.dart';
import '../../features/portal/presentation/portal_screen.dart';
import '../../features/portal/presentation/student_id_screen.dart';
import '../../features/portal/presentation/gpa_calculator_screen.dart';
import '../../features/portal/presentation/timetable_screen.dart';
import '../../features/portal/presentation/exam_countdown_screen.dart';
import '../../features/portal/presentation/cgpa_simulator_screen.dart';
import '../../features/portal/presentation/cbt_practice_screen.dart';
import '../../features/portal/presentation/attendance_tracker_screen.dart';
import '../../features/utilities/presentation/lost_found_screen.dart';
import '../../features/utilities/presentation/hostel_hub_screen.dart';
import '../../features/utilities/presentation/shuttle_board_screen.dart';
import '../../features/utilities/presentation/student_gigs_screen.dart';
import '../../features/utilities/presentation/campus_polls_screen.dart';
import '../../features/utilities/presentation/sports_center_screen.dart';
import '../../features/utilities/presentation/study_lounges_screen.dart';
import '../../features/utilities/presentation/campus_sos_screen.dart';
import '../../features/utilities/presentation/clinic_queue_screen.dart';
import '../../features/chat/presentation/sticker_creator_screen.dart';

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

      final uriPath = state.uri.path;
      final isPublicPostRoute = uriPath.startsWith('/post/') ||
          uriPath.startsWith('/p/') ||
          uriPath == '/post-detail';

      if (isFirstLaunch && !isOnboarding && !isPublicPostRoute) {
        return '/onboarding';
      }

      if (!isLoggedIn &&
          !isLoggingIn &&
          !isSigningUp &&
          !isOnboarding &&
          !isPublicPostRoute) {
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

          if (isIncomplete && !isCompletingProfile && !isPublicPostRoute) {
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
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(
        title: const Text('Page Not Found'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.link_off_rounded, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Page Not Found',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'The link or route "${state.uri.toString()}" could not be found.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home_rounded),
                label: const Text('Back to Home'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
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
              initialChannelId: (extra['channelId'] ?? extra['initialChannelId']) as String?,
              initialMedia: (extra['media'] ?? extra['initialMedia']) as XFile?,
              initialMode: (extra['mode'] ?? extra['initialMode']) as CameraMode?,
              initialContent: (extra['initialContent'] ?? extra['initialText'] ?? extra['content']) as String?,
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
        path: '/post/:postId',
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
      GoRoute(
        path: '/p/:postId',
        parentNavigatorKey: rootNavigatorKey,
        redirect: (context, state) {
          final postId = state.pathParameters['postId'];
          return postId != null ? '/post/$postId' : '/';
        },
      ),
      GoRoute(
        path: '/post-detail',
        parentNavigatorKey: rootNavigatorKey,
        redirect: (context, state) {
          final postId = state.uri.queryParameters['postId'];
          return postId != null ? '/post/$postId' : '/';
        },
      ),
      GoRoute(
        path: '/camera',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return CameraScreen(
            isForStory: extra?['isForStory'] ?? false,
            cameraContext: extra?['cameraContext'],
            directRecipientId: extra?['directRecipientId'],
            directRecipientName: extra?['directRecipientName'],
            onMediaCaptured: extra?['onMediaCaptured'],
          );
        },
      ),
      GoRoute(
        path: '/stories/:userId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final userId = state.pathParameters['userId']!;
          Map<String, List<Story>> storiesGrouped = {};
          bool singleUserMode = false;

          if (state.extra is Map<String, dynamic>) {
            final extraMap = state.extra as Map<String, dynamic>;
            storiesGrouped =
                (extraMap['storiesGrouped'] as Map<String, List<Story>>?) ?? {};
            singleUserMode = extraMap['singleUserMode'] == true;
          } else if (state.extra is Map<String, List<Story>>) {
            storiesGrouped = state.extra as Map<String, List<Story>>;
          }

          return StoryViewerScreen(
            storiesGrouped: storiesGrouped,
            initialUserId: userId,
            singleUserMode: singleUserMode,
          );
        },
      ),
      GoRoute(
        path: '/advertisements',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AdvertisementsScreen(),
        routes: [
          GoRoute(
            path: 'create',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => const CreateAdvertisementScreen(),
          ),
        ],
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
        path: '/profile/:userId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final userId = state.pathParameters['userId'];
          return ProfileScreen(userId: userId);
        },
      ),
      GoRoute(
        path: '/u/:userId',
        parentNavigatorKey: rootNavigatorKey,
        redirect: (context, state) {
          final userId = state.pathParameters['userId'];
          return userId != null ? '/user/$userId' : '/';
        },
      ),
      GoRoute(
        path: '/join/group/:channelId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final channelId = state.pathParameters['channelId'] ?? '';
          return JoinGroupScreen(channelId: channelId);
        },
      ),
      GoRoute(
        path: '/groups/join/:channelId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final channelId = state.pathParameters['channelId'] ?? '';
          return JoinGroupScreen(channelId: channelId);
        },
      ),
      GoRoute(
        path: '/group/join/:channelId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final channelId = state.pathParameters['channelId'] ?? '';
          return JoinGroupScreen(channelId: channelId);
        },
      ),
      GoRoute(
        path: '/channels/:channelId/join',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final channelId = state.pathParameters['channelId'] ?? '';
          return JoinGroupScreen(channelId: channelId);
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
        path: '/hashtag/:tag',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final tag = state.pathParameters['tag'] ?? 'trending';
          return buildPageWithAnimation(
            context: context,
            state: state,
            child: HashtagScreen(tag: tag),
          );
        },
      ),
      GoRoute(
        path: '/audio-track',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final extra = state.extra;
          final String audioId;
          final String title;
          final String authorName;
          final String authorHandle;
          final String? authorAvatarUrl;
          final String? authorId;

          if (extra is Post) {
            audioId = extra.id;
            authorHandle = extra.authorHandle.isNotEmpty ? extra.authorHandle : extra.authorName;
            title = 'Original audio · @$authorHandle';
            authorName = extra.authorName;
            authorAvatarUrl = extra.authorAvatarUrl;
            authorId = extra.authorId;
          } else if (extra is Map<String, dynamic>) {
            audioId = extra['audioId'] as String? ?? 'original_audio';
            title = extra['title'] as String? ?? 'Original audio';
            authorName = extra['authorName'] as String? ?? 'Creator';
            authorHandle = extra['authorHandle'] as String? ?? 'creator';
            authorAvatarUrl = extra['authorAvatarUrl'] as String?;
            authorId = extra['authorId'] as String?;
          } else {
            audioId = state.uri.queryParameters['audioId'] ?? 'original';
            title = state.uri.queryParameters['title'] ?? 'Original audio';
            authorName = state.uri.queryParameters['authorName'] ?? 'Creator';
            authorHandle = state.uri.queryParameters['authorHandle'] ?? 'creator';
            authorAvatarUrl = state.uri.queryParameters['authorAvatarUrl'];
            authorId = state.uri.queryParameters['authorId'];
          }

          return buildPageWithAnimation(
            context: context,
            state: state,
            child: AudioTrackScreen(
              audioId: audioId,
              title: title,
              authorName: authorName,
              authorHandle: authorHandle,
              authorAvatarUrl: authorAvatarUrl,
              authorId: authorId,
            ),
          );
        },
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
        path: '/portal',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => buildPageWithAnimation(
          context: context,
          state: state,
          child: const PortalScreen(),
        ),
      ),
      GoRoute(
        path: '/student-id',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => buildPageWithAnimation(
          context: context,
          state: state,
          child: const StudentIdScreen(),
        ),
      ),
      GoRoute(
        path: '/id',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => buildPageWithAnimation(
          context: context,
          state: state,
          child: const StudentIdScreen(),
        ),
      ),
      GoRoute(
        path: '/gpa',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => buildPageWithAnimation(
          context: context,
          state: state,
          child: const GPACalculatorScreen(),
        ),
      ),
      GoRoute(
        path: '/timetable',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => buildPageWithAnimation(
          context: context,
          state: state,
          child: const TimetableScreen(),
        ),
      ),
      GoRoute(
        path: '/lost-found',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => buildPageWithAnimation(
          context: context,
          state: state,
          child: const LostFoundScreen(),
        ),
      ),
      GoRoute(
        path: '/exam-countdown',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => buildPageWithAnimation(
          context: context,
          state: state,
          child: const ExamCountdownScreen(),
        ),
      ),
      GoRoute(
        path: '/cgpa-simulator',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => buildPageWithAnimation(
          context: context,
          state: state,
          child: const CgpaSimulatorScreen(),
        ),
      ),
      GoRoute(
        path: '/cbt-practice',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => buildPageWithAnimation(
          context: context,
          state: state,
          child: const CbtPracticeScreen(),
        ),
      ),
      GoRoute(
        path: '/attendance-tracker',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => buildPageWithAnimation(
          context: context,
          state: state,
          child: const AttendanceTrackerScreen(),
        ),
      ),
      GoRoute(
        path: '/hostel-hub',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => buildPageWithAnimation(
          context: context,
          state: state,
          child: const HostelHubScreen(),
        ),
      ),
      GoRoute(
        path: '/shuttle-board',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => buildPageWithAnimation(
          context: context,
          state: state,
          child: const ShuttleBoardScreen(),
        ),
      ),
      GoRoute(
        path: '/student-gigs',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => buildPageWithAnimation(
          context: context,
          state: state,
          child: const StudentGigsScreen(),
        ),
      ),
      GoRoute(
        path: '/campus-polls',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => buildPageWithAnimation(
          context: context,
          state: state,
          child: const CampusPollsScreen(),
        ),
      ),
      GoRoute(
        path: '/sports-center',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => buildPageWithAnimation(
          context: context,
          state: state,
          child: const SportsCenterScreen(),
        ),
      ),
      GoRoute(
        path: '/study-lounges',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => buildPageWithAnimation(
          context: context,
          state: state,
          child: const StudyLoungesScreen(),
        ),
      ),
      GoRoute(
        path: '/campus-sos',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => buildPageWithAnimation(
          context: context,
          state: state,
          child: const CampusSosScreen(),
        ),
      ),
      GoRoute(
        path: '/clinic-queue',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => buildPageWithAnimation(
          context: context,
          state: state,
          child: const ClinicQueueScreen(),
        ),
      ),
      GoRoute(
        path: '/sticker-creator',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) => buildPageWithAnimation(
          context: context,
          state: state,
          child: const StickerCreatorScreen(),
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
                      final item = state.extra is MarketplaceItem ? state.extra as MarketplaceItem : null;
                      final itemId = state.uri.queryParameters['id'] ?? state.uri.queryParameters['itemId'];
                      return MarketplaceDetailScreen(item: item, itemId: itemId);
                    },
                  ),
                  GoRoute(
                    path: 'item/:itemId',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final itemId = state.pathParameters['itemId'];
                      final item = state.extra is MarketplaceItem ? state.extra as MarketplaceItem : null;
                      return MarketplaceDetailScreen(item: item, itemId: itemId);
                    },
                  ),
                  GoRoute(
                    path: 'seller/:sellerId',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final sellerId = state.pathParameters['sellerId']!;
                      final extra = state.extra as Map<String, dynamic>?;
                      return SellerStorefrontScreen(
                        sellerId: sellerId,
                        initialSellerName: extra?['name'],
                        initialSellerAvatar: extra?['avatar'],
                      );
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
