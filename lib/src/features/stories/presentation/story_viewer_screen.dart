import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../domain/story.dart';
import '../data/story_repository.dart';
import 'package:abuad/src/features/user/data/user_repository.dart';
import '../../feed/domain/report.dart';
import '../../feed/presentation/widgets/report_bottom_sheet.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'create_story_screen.dart';
import 'package:abuad/src/core/utils/url_validator.dart';

/// Full-screen story viewer with Snapchat-style controls
class StoryViewerScreen extends ConsumerStatefulWidget {
  final Map<String, List<Story>> storiesGrouped;
  final String initialUserId;
  final int initialStoryIndex;

  const StoryViewerScreen({
    super.key,
    required this.storiesGrouped,
    required this.initialUserId,
    this.initialStoryIndex = 0,
  });

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen> {
  late PageController _userPageController;
  late int _currentUserIndex;
  late int _currentStoryIndex;
  Timer? _storyTimer;
  bool _isPaused = false;
  late List<String> _userIds;
  late TextEditingController _messageController;
  late FocusNode _focusNode;
  bool _isTyping = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _userIds = widget.storiesGrouped.keys.toList();

    // Find initial user index
    _currentUserIndex = _userIds.indexOf(widget.initialUserId);
    if (_currentUserIndex == -1) _currentUserIndex = 0;

    _currentStoryIndex = widget.initialStoryIndex;
    _userPageController = PageController(initialPage: _currentUserIndex);
    _messageController = TextEditingController();
    _focusNode = FocusNode();

    _messageController.addListener(() {
      if (_messageController.text.isNotEmpty && !_isTyping) {
        setState(() => _isTyping = true);
      } else if (_messageController.text.isEmpty && _isTyping) {
        setState(() => _isTyping = false);
      }
    });

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _storyTimer?.cancel();
        setState(() => _isPaused = true);
      } else {
        if (_messageController.text.isEmpty) {
          setState(() {
            _isPaused = false;
            _startStoryTimer();
          });
        }
      }
    });

    // Mark first story as viewed and start timer
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markCurrentStoryViewed();
      _startStoryTimer();
    });
  }

  @override
  void dispose() {
    _storyTimer?.cancel();
    _userPageController.dispose();
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startStoryTimer() {
    _storyTimer?.cancel();
    if (_isPaused) return;

    _storyTimer = Timer(const Duration(seconds: 5), () {
      _nextStory();
    });
  }

  void _markCurrentStoryViewed() {
    final currentUserId = _userIds[_currentUserIndex];
    final stories = widget.storiesGrouped[currentUserId]!;
    if (_currentStoryIndex < stories.length) {
      final story = stories[_currentStoryIndex];
      ref.read(storyRepositoryProvider).markAsViewed(story.id);
    }
  }

  void _safePop() {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;
    _storyTimer?.cancel();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/');
    }
  }

  void _nextStory() {
    if (_isNavigating) return;
    
    final currentUserId = _userIds[_currentUserIndex];
    final stories = widget.storiesGrouped[currentUserId]!;

    if (_currentStoryIndex < stories.length - 1) {
      // Next story of current user
      setState(() {
        _currentStoryIndex++;
      });
      _markCurrentStoryViewed();
      _startStoryTimer();
    } else {
      // Next user's stories
      if (_currentUserIndex < _userIds.length - 1) {
        setState(() {
          _currentUserIndex++;
          _currentStoryIndex = 0;
        });
        _userPageController.animateToPage(
          _currentUserIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        _markCurrentStoryViewed();
        _startStoryTimer();
      } else {
        // End of all stories
        _safePop();
      }
    }
  }

  void _previousStory() {
    if (_currentStoryIndex > 0) {
      // Previous story of current user
      setState(() {
        _currentStoryIndex--;
      });
      _startStoryTimer();
    } else {
      // Previous user's stories
      if (_currentUserIndex > 0) {
        setState(() {
          _currentUserIndex--;
          final prevUserId = _userIds[_currentUserIndex];
          _currentStoryIndex = widget.storiesGrouped[prevUserId]!.length - 1;
        });
        _userPageController.animateToPage(
          _currentUserIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        _startStoryTimer();
      }
    }
  }

  void _deleteCurrentStory() async {
    final currentUserId = _userIds[_currentUserIndex];
    final stories = widget.storiesGrouped[currentUserId]!;
    final story = stories[_currentStoryIndex];

    // Confirm deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Story?'),
        content: const Text('This story will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(storyRepositoryProvider).deleteStory(story.id);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Story deleted')));
          // Move to next or close
          if (stories.length == 1) {
            _safePop();
          } else {
            _nextStory();
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      _storyTimer?.cancel();
      setState(() => _isPaused = true);
      await launchUrl(url, mode: LaunchMode.externalApplication);
      if (mounted) {
        setState(() {
          _isPaused = false;
          _startStoryTimer();
        });
      }
    }
  }

  Future<void> _likeCurrentStory() async {
    final currentUserId = _userIds[_currentUserIndex];
    final stories = widget.storiesGrouped[currentUserId]!;
    final story = stories[_currentStoryIndex];
    final myId = ref.read(currentUserProvider).value?.uid;

    if (myId == null) return;

    final isLiking = !story.hasLiked(myId);

    await ref.read(storyRepositoryProvider).likeStory(story.id, isLiking: isLiking);

    // Update local state if needed (Stream should handle it, but for snappiness)
    if (mounted) {
      setState(() {
        // Force rebuild to show like animation if implemented
      });
    }
  }

  void _reshareStory(Story story) {
    _storyTimer?.cancel();
    setState(() => _isPaused = true);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateStoryScreen(resharedStory: story),
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _isPaused = false;
          _startStoryTimer();
        });
      }
    });
  }

  void _shareStory(Story story) {
    _storyTimer?.cancel();
    setState(() => _isPaused = true);

    final text =
        'Check out this story on ABUAD Nest! ${story.caption ?? ""}\n\nhttps://abuadapp.web.app/post/${story.id}';
    Share.share(text).then((_) {
      if (mounted) {
        setState(() {
          _isPaused = false;
          _startStoryTimer();
        });
      }
    });
  }

  void _sendMessage(Story story) {
    if (_messageController.text.trim().isEmpty) return;
    
    // Logic to send story reply as a chat message
    // For now, just clear and unfocus
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reply sent!')),
    );
    
    _messageController.clear();
    _focusNode.unfocus();
  }

  void _showViewers(Story story) {
    _storyTimer?.cancel();
    setState(() => _isPaused = true);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildViewersSheet(context, story),
    ).whenComplete(() {
      if (mounted) {
        setState(() {
          _isPaused = false;
          _startStoryTimer();
        });
      }
    });
  }

  Widget _buildViewersSheet(BuildContext context, Story story) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const TabBar(
                tabs: [
                  Tab(text: 'Viewers'),
                  Tab(text: 'Likes'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildUserList(story.viewers),
                    _buildUserList(story.likes, isLikeList: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserList(List<String> userIds, {bool isLikeList = false}) {
    if (userIds.isEmpty) {
      return const Center(child: Text('No users yet'));
    }
    return ListView.builder(
      itemCount: userIds.length,
      itemBuilder: (context, index) {
        final userId = userIds[index];
        return Consumer(
          builder: (context, ref, child) {
            final userAsync = ref.watch(userProvider(userId));
            return userAsync.when(
              data: (user) {
                final avatarUrl = user?.avatarUrl;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: (avatarUrl != null &&
                            UrlValidator.isValidUrl(avatarUrl))
                        ? CachedNetworkImageProvider(avatarUrl)
                        : null,
                    child: (avatarUrl == null ||
                            !UrlValidator.isValidUrl(avatarUrl))
                        ? Text(user?.displayName[0].toUpperCase() ?? '?')
                        : null,
                  ),
                  title: Text(user?.displayName ?? 'Unknown'),
                  trailing: isLikeList
                      ? const Icon(Icons.favorite, color: Colors.red, size: 20)
                      : null,
                );
              },
              loading: () => const ListTile(title: Text('Loading...')),
              error: (_, _) => const SizedBox(),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _safePop();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < width / 3) {
            _previousStory();
          } else if (details.globalPosition.dx > 2 * width / 3) {
            _nextStory();
          }
        },
        onLongPressStart: (_) {
          setState(() {
            _isPaused = true;
          });
          _storyTimer?.cancel();
        },
        onLongPressEnd: (_) {
          setState(() {
            _isPaused = false;
            _startStoryTimer();
          });
        },
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity! > 0) {
            _safePop();
          }
        },
        child: PageView.builder(
          controller: _userPageController,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _userIds.length,
          onPageChanged: (index) {
            setState(() {
              _currentUserIndex = index;
              _currentStoryIndex = 0;
            });
            _markCurrentStoryViewed();
            _startStoryTimer();
          },
          itemBuilder: (context, userIndex) {
            final userId = _userIds[userIndex];
            final stories = widget.storiesGrouped[userId]!;

            // FIX: Only use _currentStoryIndex for the active user index
            // Pre-cached neighbors should use index 0 to avoid RangeError
            final actualStoryIndex = userIndex == _currentUserIndex
                ? _currentStoryIndex
                : 0;
            final story = stories[actualStoryIndex];

            return Consumer(
              builder: (context, ref, child) {
                final viewerId = ref.watch(currentUserProvider).value?.uid;
                final userAsync = ref.watch(userProvider(userId));

                return userAsync.when(
                  data: (user) {
                    final userName = user?.displayName ?? (story.userName.isNotEmpty ? story.userName : 'Unknown');
                    final userAvatar = user?.avatarUrl ?? (story.userAvatar.isNotEmpty ? story.userAvatar : null);

                    final isOwnStory = story.authorId == viewerId;

                    return Stack(
                      children: [
                        // Story Content (Image or Text)
                        Center(
                          child: story.type == 'text'
                              ? Container(
                                  color: Color(
                                    story.backgroundColor ?? 0xFF000000,
                                  ),
                                  width: double.infinity,
                                  height: double.infinity,
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.all(32),
                                  child: Text(
                                    story.content,
                                    textAlign: _parseTextAlign(story.textAlign),
                                    style: TextStyle(
                                      color: Color(
                                        story.textColor ?? 0xFFFFFFFF,
                                      ),
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: story.fontFamily ?? 'Roboto',
                                    ),
                                  ),
                                )
                              : CachedNetworkImage(
                                  imageUrl: story.content,
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  height: double.infinity,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      const Center(
                                        child: Icon(
                                          Icons.error,
                                          color: Colors.white,
                                          size: 48,
                                        ),
                                      ),
                                ),
                        ),

                        // Gradient overlay at top
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 200,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.6),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Progress bars
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 8,
                          left: 8,
                          right: 8,
                          child: Row(
                            children: List.generate(
                              stories.length,
                              (index) => Expanded(
                                child: Container(
                                  height: 3,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: index < _currentStoryIndex
                                        ? 1.0
                                        : index == _currentStoryIndex
                                        ? (_isPaused ? 0.5 : 1.0)
                                        : 0.0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // User info header
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 20,
                          left: 12,
                          right: 12,
                          child: Row(
                            children: [
                              // Profile Avatar & Name (Navigates to Profile)
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    setState(() => _isPaused = true);
                                    _storyTimer?.cancel();
                                    context.push('/user/$userId').then((_) {
                                      if (mounted) {
                                        setState(() {
                                          _isPaused = false;
                                          _startStoryTimer();
                                        });
                                      }
                                    });
                                  },
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundImage: (userAvatar != null &&
                                                UrlValidator.isValidUrl(
                                                  userAvatar,
                                                ))
                                            ? CachedNetworkImageProvider(
                                              userAvatar,
                                            )
                                            : null,
                                        backgroundColor: const Color(
                                          0xFF8B5CF6,
                                        ),
                                        child: (userAvatar == null ||
                                                !UrlValidator.isValidUrl(
                                                  userAvatar,
                                                ))
                                            ? Text(
                                              userName.isNotEmpty
                                                  ? userName[0].toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              userName,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              timeago.format(story.createdAt),
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.8,
                                                ),
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Follow button (If not followed)
                              if (!isOwnStory &&
                                  !(ref
                                          .watch(
                                            isFollowingProvider(userId),
                                          )
                                          .value ??
                                      true))
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: TextButton(
                                    onPressed: () {
                                      ref
                                          .read(userRepositoryProvider)
                                          .followUser(userId);
                                    },
                                    style: TextButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 4,
                                      ),
                                      minimumSize: const Size(60, 30),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    child: const Text(
                                      'Follow',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              // Viewers Count (Author Only)
                              if (isOwnStory)
                                GestureDetector(
                                  onTap: () => _showViewers(story),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.4,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.remove_red_eye,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${story.viewers.length}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              if (isOwnStory)
                                IconButton(
                                  onPressed: _deleteCurrentStory,
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                  ),
                                ),
                              IconButton(
                                onPressed: _safePop,
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                              ),
                              if (!isOwnStory)
                                IconButton(
                                  onPressed: () {
                                    setState(() => _isPaused = true);
                                    _storyTimer?.cancel();
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (context) => ReportBottomSheet(
                                        targetId: story.id,
                                        type: ReportType.story,
                                      ),
                                    ).then((_) {
                                      if (mounted) {
                                        setState(() {
                                          _isPaused = false;
                                          _startStoryTimer();
                                        });
                                      }
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.report_outlined,
                                    color: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Reshare indicator (Attribution)
                        if (story.reshareAuthorName != null)
                          Positioned(
                            top: MediaQuery.of(context).padding.top + 85,
                            left: 12,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.15,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.repeat,
                                        color: Color(0xFFC4B5FD),
                                        size: 14,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Reshared from @${story.reshareAuthorName}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // Mentions and Caption
                        Positioned(
                          bottom: 80,
                          left: 16,
                          right: 16,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (story.mentions.isNotEmpty)
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  alignment: WrapAlignment.center,
                                  children: story.mentions
                                      .map(
                                        (mention) => GestureDetector(
                                          onTap: () {
                                            _storyTimer?.cancel();
                                            setState(() => _isPaused = true);
                                            ref
                                                .read(userRepositoryProvider)
                                                .getUserByHandle(mention)
                                                .then((user) {
                                                  if (user != null && mounted) {
                                                    context.push(
                                                      '/user/${user.uid}',
                                                    );
                                                  } else if (mounted) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          'User @$mention not found',
                                                        ),
                                                      ),
                                                    );
                                                    setState(() {
                                                      _isPaused = false;
                                                      _startStoryTimer();
                                                    });
                                                  }
                                                });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(
                                                alpha: 0.5,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                              border: Border.all(
                                                color: const Color(
                                                  0xFF8B5CF6,
                                                ).withValues(alpha: 0.8),
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(
                                                    0xFF8B5CF6,
                                                  ).withValues(alpha: 0.2),
                                                  blurRadius: 4,
                                                  spreadRadius: 1,
                                                ),
                                              ],
                                            ),
                                            child: Text(
                                              '@$mention',
                                              style: const TextStyle(
                                                color: Color(0xFFC4B5FD),
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              if (story.mentions.isNotEmpty &&
                                  story.caption != null &&
                                  story.caption!.isNotEmpty)
                                const SizedBox(height: 8),
                              if (story.caption != null &&
                                  story.caption!.isNotEmpty &&
                                  story.type != 'text')
                                Text(
                                  story.caption!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    shadows: [
                                      Shadow(
                                        blurRadius: 4,
                                        color: Colors.black,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Link Button (Visit Link)
                        if (story.linkUrl != null && story.linkUrl!.isNotEmpty)
                          Positioned(
                            bottom: 90,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: GestureDetector(
                                onTap: () => _launchUrl(story.linkUrl!),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF8B5CF6),
                                        Color(0xFFEC4899),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(
                                        Icons.share_outlined,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Visit Link',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // Actions Bar (Bottom)
                        Positioned(
                          bottom: MediaQuery.of(context).padding.bottom + 16,
                          left: 16,
                          right: 16,
                          child: Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(30),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(30),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.2),
                                        ),
                                      ),
                                      child: TextField(
                                        controller: _messageController,
                                        focusNode: _focusNode,
                                        style: const TextStyle(color: Colors.white, fontSize: 15),
                                        decoration: InputDecoration(
                                          hintText: 'Send message...',
                                          hintStyle: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.6),
                                            fontSize: 14,
                                          ),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                        ),
                                        onSubmitted: (_) => _sendMessage(story),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 300),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!_isTyping && !_focusNode.hasFocus) ...[
                                      const SizedBox(width: 12),
                                      IconButton(
                                        onPressed: _likeCurrentStory,
                                        icon: Icon(
                                          story.hasLiked(viewerId!)
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color: story.hasLiked(viewerId)
                                              ? Colors.red
                                              : Colors.white,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => _reshareStory(story),
                                        icon: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF8B5CF6,
                                            ).withValues(alpha: 0.15),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: const Color(
                                                0xFF8B5CF6,
                                              ).withValues(alpha: 0.3),
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(
                                                  0xFF8B5CF6,
                                                ).withValues(alpha: 0.2),
                                                blurRadius: 8,
                                                spreadRadius: 0,
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.repeat,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => _shareStory(story),
                                        icon: const Icon(
                                          Icons.ios_share,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                      ),
                                    ] else ...[
                                      const SizedBox(width: 8),
                                      IconButton(
                                        onPressed: () => _sendMessage(story),
                                        icon: const Icon(
                                          Icons.send_rounded,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(
                    child: Text(
                      "Error: $e",
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ),
    );
  }

  TextAlign _parseTextAlign(String? align) {
    switch (align) {
      case 'left':
        return TextAlign.left;
      case 'right':
        return TextAlign.right;
      default:
        return TextAlign.center;
    }
  }
}
