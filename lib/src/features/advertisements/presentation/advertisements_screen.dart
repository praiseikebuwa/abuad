import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../data/advertisement_repository.dart';
import 'create_advertisement_screen.dart';
import 'widgets/sponsored_ad_card.dart';

class AdvertisementsScreen extends ConsumerWidget {
  const AdvertisementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = isDark ? Colors.black : const Color(0xFFF8FAFC);
    final surface = isDark ? const Color(0xFF111111) : Colors.white;
    final border = isDark ? const Color(0xFF222222) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    final activeAdsAsync = ref.watch(activeAdsProvider);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Campus Advertisements',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.secondaryTeal),
            tooltip: 'Create Advertisement',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CreateAdvertisementScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: activeAdsAsync.when(
        data: (ads) {
          final totalImpressions =
              ads.fold<int>(0, (sum, a) => sum + a.impressionsCount);
          final totalClicks =
              ads.fold<int>(0, (sum, a) => sum + a.clicksCount);

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            children: [
              // Promo / Callout Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00E5FF), Color(0xFF0284C7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.campaign_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Reach Thousands of Students',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'COMING SOON',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Promote your clothing brand, hostel deliveries, tech workshop, or website across Feed, Stories, and Marketplace with direct tap links.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Row(
                              children: [
                                Icon(Icons.stars_rounded, color: Color(0xFF0284C7)),
                                SizedBox(width: 8),
                                Text('Coming Soon'),
                              ],
                            ),
                            content: const Text(
                              'Ad Creation & Campus Payments are paused for now and will be live in an upcoming update! You can explore the design studio in preview mode.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Close'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const CreateAdvertisementScreen(),
                                    ),
                                  );
                                },
                                child: const Text('Open Preview Studio'),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.visibility_rounded, size: 16),
                      label: const Text(
                        'Ad Creation (Coming Soon)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0284C7),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Analytics Summary Row
              Row(
                children: [
                  _buildStatCard(
                    title: 'Active Ads',
                    value: '${ads.length}',
                    icon: Icons.pie_chart_outline,
                    color: const Color(0xFF8B5CF6),
                    surface: surface,
                    border: border,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(width: 10),
                  _buildStatCard(
                    title: 'Impressions',
                    value: '$totalImpressions',
                    icon: Icons.remove_red_eye_outlined,
                    color: const Color(0xFF00E5FF),
                    surface: surface,
                    border: border,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(width: 10),
                  _buildStatCard(
                    title: 'Clicks / Taps',
                    value: '$totalClicks',
                    icon: Icons.touch_app_outlined,
                    color: const Color(0xFF10B981),
                    surface: surface,
                    border: border,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ],
              ),

              const SizedBox(height: 22),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Active Campaigns (${ads.length})',
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              const CreateAdvertisementScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New Ad'),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              if (ads.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      children: [
                        Icon(Icons.ad_units_outlined,
                            size: 48, color: textSecondary),
                        const SizedBox(height: 12),
                        Text(
                          'No active advertisements yet',
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap "New Ad" to start your first campaign!',
                          style: TextStyle(color: textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...ads.map((ad) => SponsoredAdCard(ad: ad)),

              const SizedBox(height: 40),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Error loading ads: $e',
            style: TextStyle(color: textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color surface,
    required Color border,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
