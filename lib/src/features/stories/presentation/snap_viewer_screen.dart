import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/utils/url_validator.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../domain/snap_model.dart';
import '../data/snap_repository.dart';

class SnapViewerScreen extends ConsumerStatefulWidget {
  final Map<String, List<Snap>> snapsGrouped;
  final String initialUserId;

  const SnapViewerScreen({
    super.key,
    required this.snapsGrouped,
    required this.initialUserId,
  });

  @override
  ConsumerState<SnapViewerScreen> createState() => _SnapViewerScreenState();
}

class _SnapViewerScreenState extends ConsumerState<SnapViewerScreen> {
  late PageController _pageController;
  late List<String> _userIds;
  late int _currentUserIndex;
  late int _currentSnapIndex;

  @override
  void initState() {
    super.initState();
    _userIds = widget.snapsGrouped.keys.toList();
    _currentUserIndex = _userIds.indexOf(widget.initialUserId);
    _currentSnapIndex = 0;
    _pageController = PageController(initialPage: _currentUserIndex);

    _markCurrentAsViewed();
  }

  void _markCurrentAsViewed() {
    final userId = _userIds[_currentUserIndex];
    final snaps = widget.snapsGrouped[userId]!;
    final snap = snaps[_currentSnapIndex];
    ref.read(snapRepositoryProvider).markSnapAsViewed(snap.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        itemCount: _userIds.length,
        onPageChanged: (index) {
          setState(() {
            _currentUserIndex = index;
            _currentSnapIndex = 0;
          });
          _markCurrentAsViewed();
        },
        itemBuilder: (context, userIndex) {
          final userId = _userIds[userIndex];
          final snaps = widget.snapsGrouped[userId]!;

          return Stack(
            children: [
              // Snap Image
              Positioned.fill(
                child: UrlValidator.isValidUrl(snaps[_currentSnapIndex].imageUrl)
                    ? CachedNetworkImage(
                        imageUrl: snaps[_currentSnapIndex].imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                        errorWidget: (context, url, error) => _buildErrorContent(),
                      )
                    : _buildErrorContent(),
              ),

              // Gradient Overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.5),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                ),
              ),

              // Progress Bar
              Positioned(
                top: 50,
                left: 10,
                right: 10,
                child: Row(
                  children: List.generate(snaps.length, (index) {
                    return Expanded(
                      child: Container(
                        height: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: index <= _currentSnapIndex
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // Header
              Positioned(
                top: 60,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    UserAvatar(
                      userId: snaps[_currentSnapIndex].userId,
                      avatarUrl: snaps[_currentSnapIndex].userAvatar,
                      radius: 18,
                      showStoryRing: false,
                      enableDefaultTap: false,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      snaps[_currentSnapIndex].userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Caption
              if (snaps[_currentSnapIndex].caption != null)
                Positioned(
                  bottom: 100,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      snaps[_currentSnapIndex].caption!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),

              // Tap Targets for navigation
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (_currentSnapIndex > 0) {
                            setState(() => _currentSnapIndex--);
                            _markCurrentAsViewed();
                          } else if (_currentUserIndex > 0) {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (_currentSnapIndex < snaps.length - 1) {
                            setState(() => _currentSnapIndex++);
                            _markCurrentAsViewed();
                          } else if (_currentUserIndex < _userIds.length - 1) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildErrorContent() {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, color: Colors.white54, size: 64),
            SizedBox(height: 16),
            Text(
              'Content unavailable',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
