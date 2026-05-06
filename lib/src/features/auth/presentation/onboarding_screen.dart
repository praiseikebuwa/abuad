import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../../../core/providers/shared_preferences_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPageData> _pages = [
    OnboardingPageData(
      title: 'Welcome to ABUAD Nest',
      description:
          'The heartbeat of Afe Babalola University. Connect, explore, and thrive in our digital campus.',
      icon: Icons.school_rounded,
      color: const Color(0xFF1A237E), // Deep Indigo
      videoPath: 'assets/onboarding video.mp4',
    ),
    OnboardingPageData(
      title: 'Vibrant Social Feed',
      description:
          'Stay updated with campus news, share your moments, and connect with fellow students.',
      icon: Icons.dynamic_feed_rounded,
      color: const Color(0xFF006064), // Cyan
    ),
    OnboardingPageData(
      title: 'Unified Student Portal',
      description:
          'Access your GPA calculator, timetable, and campus maps all in one place.',
      icon: Icons.account_balance_rounded,
      color: const Color(0xFF004D40), // Teal
    ),
    OnboardingPageData(
      title: 'University Marketplace',
      description:
          'Buy and sell books, gadgets, and services within the secure ABUAD student community.',
      icon: Icons.shopping_bag_rounded,
      color: const Color(0xFFE65100), // Orange
    ),
  ];

  void _onNext() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _completeOnboarding() async {
    await ref.read(firstLaunchRepositoryProvider).setFirstLaunchComplete();
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              final page = _pages[index];
              return OnboardingPageContent(data: page);
            },
          ),

          // Bottom Navigation
          Positioned(
            bottom: 60,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Skip Button
                TextButton(
                  onPressed: _completeOnboarding,
                  child: Text(
                    'SKIP',
                    style: GoogleFonts.outfit(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),

                // Indicators
                Row(
                  children: List.generate(
                    _pages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: _currentPage == index ? 24 : 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? _pages[_currentPage].color
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),

                // Next Button
                CircleAvatar(
                      radius: 28,
                      backgroundColor: _pages[_currentPage].color,
                      child: IconButton(
                        icon: Icon(
                          _currentPage == _pages.length - 1
                              ? Icons.check
                              : Icons.arrow_forward_rounded,
                          color: Colors.white,
                        ),
                        onPressed: _onNext,
                      ),
                    )
                    .animate(key: ValueKey(_currentPage))
                    .scale(duration: 300.ms, curve: Curves.easeOutBack),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPageData {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String? videoPath;

  OnboardingPageData({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.videoPath,
  });
}

class OnboardingPageContent extends StatefulWidget {
  final OnboardingPageData data;

  const OnboardingPageContent({super.key, required this.data});

  @override
  State<OnboardingPageContent> createState() => _OnboardingPageContentState();
}

class _OnboardingPageContentState extends State<OnboardingPageContent> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.data.videoPath != null) {
      _controller = VideoPlayerController.asset(widget.data.videoPath!)
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _isInitialized = true;
            });
            _controller?.setLooping(true);
            _controller?.play();
            _controller?.setVolume(0); // Mute for onboarding
          }
        });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Media Container (Video or Icon)
          SizedBox(
            height: 300,
            child: widget.data.videoPath != null
                ? Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: widget.data.color.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _isInitialized
                        ? AspectRatio(
                            aspectRatio: _controller!.value.aspectRatio,
                            child: VideoPlayer(_controller!),
                          )
                        : const Center(child: CircularProgressIndicator()),
                  )
                : Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: widget.data.color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.data.icon, size: 100, color: widget.data.color),
                  )
                    .animate()
                    .fade(duration: 800.ms)
                    .scale(delay: 200.ms, curve: Curves.elasticOut),
          ),

          const SizedBox(height: 60),

          // Title
          Text(
            widget.data.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          )
              .animate()
              .fade(delay: 400.ms)
              .slideY(begin: 0.2, end: 0, duration: 600.ms),

          const SizedBox(height: 20),

          // Description
          Text(
            widget.data.description,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.5,
            ),
          )
              .animate()
              .fade(delay: 600.ms)
              .slideY(begin: 0.2, end: 0, duration: 600.ms),
        ],
      ),
    );
  }
}
