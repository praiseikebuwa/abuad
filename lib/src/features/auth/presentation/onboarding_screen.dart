import 'dart:ui';
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

  VideoPlayerController? _activeController;
  bool _isVideoInitialized = false;

  final List<OnboardingPageData> _pages = [
    OnboardingPageData(
      title: 'Welcome to Abuad life',
      description:
          'The heartbeat of Afe Babalola University. Connect, explore, and thrive in our digital campus.',
      icon: Icons.school_rounded,
      videoAsset: 'assets/onboarding_video_1.mp4',
    ),
    OnboardingPageData(
      title: 'Vibrant Social Feed',
      description:
          'Stay updated with campus news, share your moments, and connect with fellow students.',
      icon: Icons.dynamic_feed_rounded,
      videoAsset: 'assets/onboarding_video_2.mp4',
    ),
    OnboardingPageData(
      title: 'Unified Student Portal',
      description:
          'Access your GPA calculator, timetable, and campus maps all in one place.',
      icon: Icons.account_balance_rounded,
      videoAsset: 'assets/onboarding_video_3.mp4',
    ),
    OnboardingPageData(
      title: 'University Marketplace',
      description:
          'Buy and sell books, gadgets, and services within the secure ABUAD student community.',
      icon: Icons.shopping_bag_rounded,
      videoAsset: 'assets/onboarding_video_4.mp4',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeVideoForPage(_currentPage);
  }

  Future<void> _initializeVideoForPage(int index) async {
    final oldController = _activeController;
    _activeController = null;
    if (mounted) {
      setState(() {
        _isVideoInitialized = false;
      });
    }
    await oldController?.dispose();

    if (index < 0 || index >= _pages.length) return;

    final assetPath = _pages[index].videoAsset;
    try {
      final controller = VideoPlayerController.asset(assetPath);
      await controller.initialize();
      if (mounted && index == _currentPage) {
        _activeController = controller;
        setState(() {
          _isVideoInitialized = true;
        });
        controller.setLooping(true);
        controller.setVolume(0);
        controller.play();
      } else {
        await controller.dispose();
      }
    } catch (e) {
      debugPrint('Failed to initialize video for slide $index: $e');
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
    _initializeVideoForPage(index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _activeController?.dispose();
    super.dispose();
  }

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
    try {
      await ref.read(firstLaunchRepositoryProvider).setFirstLaunchComplete();
    } catch (_) {}

    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeController = _activeController;
    final isActiveInitialized = _isVideoInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Dynamic Background Video per Slide
          SizedBox.expand(
            child: isActiveInitialized && activeController != null
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: activeController.value.size.width,
                      height: activeController.value.size.height,
                      child: VideoPlayer(activeController),
                    ),
                  )
                : Container(color: Colors.black),
          ),

          // 2. Dark Gradient Overlay for Readability
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.2),
                    Colors.black.withValues(alpha: 0.6),
                    Colors.black.withValues(alpha: 0.9),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // 3. Content
          SafeArea(
            child: Column(
              children: [
                // Top App branding
                Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child:
                      Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.blur_on,
                                color: Colors.white,
                                size: 28,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Abuad life',
                                style: GoogleFonts.outfit(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          )
                          .animate()
                          .fadeIn(duration: 800.ms)
                          .slideY(begin: -0.5, end: 0),
                ),

                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      return _buildPageContent(_pages[index]);
                    },
                  ),
                ),

                // 4. Bottom Controls with Glassmorphism styling
                _buildBottomControls(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageContent(OnboardingPageData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Glassmorphic Icon Bubble
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(data.icon, size: 48, color: Colors.white),
              ),
            ),
          ).animate().scale(
            delay: 200.ms,
            duration: 600.ms,
            curve: Curves.easeOutBack,
          ),

          const SizedBox(height: 32),

          // Title
          Text(
                data.title,
                style: GoogleFonts.outfit(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.1,
                ),
              )
              .animate()
              .fadeIn(delay: 400.ms)
              .slideY(begin: 0.2, end: 0, duration: 600.ms),

          const SizedBox(height: 16),

          // Description
          Text(
                data.description,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  color: Colors.white.withValues(alpha: 0.85),
                  height: 1.5,
                  fontWeight: FontWeight.w300,
                ),
              )
              .animate()
              .fadeIn(delay: 600.ms)
              .slideY(begin: 0.2, end: 0, duration: 600.ms),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Skip Button
          TextButton(
            onPressed: _completeOnboarding,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              'SKIP',
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ),

          // Page Indicators
          Row(
            children: List.generate(
              _pages.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: _currentPage == index ? 32 : 8,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),

          // Next / Get Started Button (Glassmorphic)
          GestureDetector(
            onTap: _onNext,
            child:
                ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          height: 60,
                          width: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.3),
                                Colors.white.withValues(alpha: 0.1),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Icon(
                            _currentPage == _pages.length - 1
                                ? Icons.check_rounded
                                : Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    )
                    .animate(key: ValueKey(_currentPage))
                    .scale(duration: 300.ms, curve: Curves.easeOutBack),
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
  final String videoAsset;

  OnboardingPageData({
    required this.title,
    required this.description,
    required this.icon,
    required this.videoAsset,
  });
}
