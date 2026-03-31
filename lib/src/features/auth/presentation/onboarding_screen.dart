import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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

  OnboardingPageData({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class OnboardingPageContent extends StatelessWidget {
  final OnboardingPageData data;

  const OnboardingPageContent({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon Container with Animation
          Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: data.color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(data.icon, size: 100, color: data.color),
              )
              .animate()
              .fade(duration: 800.ms)
              .scale(delay: 200.ms, curve: Curves.elasticOut),

          const SizedBox(height: 60),

          // Title
          Text(
                data.title,
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
                data.description,
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
