import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/url_validator.dart';
import '../../domain/advertisement.dart';
import '../../data/advertisement_repository.dart';

class SponsoredAdCard extends ConsumerStatefulWidget {
  final Advertisement ad;
  final bool isCompact;

  const SponsoredAdCard({
    super.key,
    required this.ad,
    this.isCompact = false,
  });

  @override
  ConsumerState<SponsoredAdCard> createState() => _SponsoredAdCardState();
}

class _SponsoredAdCardState extends ConsumerState<SponsoredAdCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(advertisementRepositoryProvider).recordImpression(widget.ad.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? Colors.black : Colors.white;
    final cardBorder = isDark
        ? const Color(0xFF222222)
        : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Advertiser Info + "Sponsored" Badge
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: AppColors.secondaryTeal.withValues(alpha: 0.2),
                  backgroundImage: (widget.ad.advertiserAvatarUrl != null &&
                          UrlValidator.isValidUrl(widget.ad.advertiserAvatarUrl!))
                      ? CachedNetworkImageProvider(widget.ad.advertiserAvatarUrl!)
                      : null,
                  child: (widget.ad.advertiserAvatarUrl == null ||
                          !UrlValidator.isValidUrl(widget.ad.advertiserAvatarUrl!))
                      ? Text(
                          widget.ad.advertiserName.isNotEmpty
                              ? widget.ad.advertiserName[0].toUpperCase()
                              : 'A',
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.secondaryTeal,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.ad.advertiserName,
                              style: TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified,
                            color: Color(0xFF00E5FF),
                            size: 14,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentAmber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Sponsored',
                              style: TextStyle(
                                color: AppColors.accentAmber,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '• Campus Partner',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.open_in_new_rounded,
                    size: 18,
                    color: textSecondary,
                  ),
                  tooltip: 'Open Website',
                  onPressed: () {
                    ref
                        .read(advertisementRepositoryProvider)
                        .recordClickAndLaunch(widget.ad);
                  },
                ),
              ],
            ),
          ),

          // Headline & Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              widget.ad.title,
              style: TextStyle(
                color: textPrimary,
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ),
          if (widget.ad.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                widget.ad.description,
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 13.5,
                  height: 1.38,
                ),
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Ad Media Banner
          if (widget.ad.mediaUrl.isNotEmpty)
            GestureDetector(
              onTap: () {
                ref
                    .read(advertisementRepositoryProvider)
                    .recordClickAndLaunch(widget.ad);
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                height: widget.isCompact ? 160 : 210,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: isDark ? const Color(0xFF151515) : Colors.grey[200],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: widget.ad.mediaUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.secondaryTeal,
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: isDark ? Colors.grey[900] : Colors.grey[200],
                        child: const Icon(Icons.image, size: 40, color: Colors.grey),
                      ),
                    ),
                    // Linked marketplace item tag if applicable
                    if (widget.ad.marketplaceItemTitle != null)
                      Positioned(
                        bottom: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.shopping_bag_rounded,
                                color: AppColors.accentAmber,
                                size: 13,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                widget.ad.marketplaceItemTitle!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (widget.ad.marketplaceItemPrice != null) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '• ₦${widget.ad.marketplaceItemPrice!.toInt()}',
                                  style: const TextStyle(
                                    color: Color(0xFF00E5FF),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 12),

          // Action Bar & Call-to-Action button
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      ref
                          .read(advertisementRepositoryProvider)
                          .recordClickAndLaunch(widget.ad);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00E5FF), Color(0xFF0284C7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.ad.ctaLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
