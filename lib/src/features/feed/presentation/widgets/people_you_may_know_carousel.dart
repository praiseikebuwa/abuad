import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/verification_badge.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../user/data/user_repository.dart';

class PeopleYouMayKnowCarousel extends ConsumerWidget {
  final VoidCallback? onSeeAll;

  const PeopleYouMayKnowCarousel({
    super.key,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final suggestionsAsync = ref.watch(peopleYouMayKnowProvider);

    return suggestionsAsync.when(
      data: (suggestions) {
        if (suggestions.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.02)
                : Colors.black.withValues(alpha: 0.015),
            border: Border.symmetric(
              horizontal: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                width: 0.8,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        CupertinoIcons.person_2_fill,
                        size: 16,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'People You May Know',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: theme.textTheme.bodyLarge?.color,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const Spacer(),
                    if (onSeeAll != null)
                      GestureDetector(
                        onTap: onSeeAll,
                        child: Text(
                          'See all',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondaryTeal,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Horizontal Swipeable List
              SizedBox(
                height: 235,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: suggestions.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final suggestion = suggestions[index];
                    return _SuggestedUserCard(
                      suggestion: suggestion,
                      onDismiss: () {
                        ref
                            .read(peopleYouMayKnowProvider.notifier)
                            .dismissUser(suggestion.user.uid);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _SuggestedUserCard extends ConsumerStatefulWidget {
  final SuggestedUser suggestion;
  final VoidCallback onDismiss;

  const _SuggestedUserCard({
    required this.suggestion,
    required this.onDismiss,
  });

  @override
  ConsumerState<_SuggestedUserCard> createState() => _SuggestedUserCardState();
}

class _SuggestedUserCardState extends ConsumerState<_SuggestedUserCard> {
  bool _isFollowingLocally = false;
  bool _isDismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = widget.suggestion.user;
    final reason = widget.suggestion.reason;

    final isFollowingAsync = ref.watch(isFollowingProvider(user.uid));
    final isFollowing = _isFollowingLocally || (isFollowingAsync.value ?? false);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _isDismissed ? 0.0 : 1.0,
      child: Container(
        width: 156,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2124) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Card Content
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                context.push('/profile/${user.uid}', extra: user);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Avatar & Info
                    Column(
                      children: [
                        const SizedBox(height: 4),
                        UserAvatar(
                          userId: user.uid,
                          avatarUrl: user.avatarUrl,
                          radius: 32,
                          showStoryRing: false,
                        ),
                        const SizedBox(height: 8),

                        // Name + Verification
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                user.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            if (user.isVerified) ...[
                              const SizedBox(width: 3),
                              VerificationBadge(
                                type: user.verificationType,
                                size: 12,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),

                        // Username / Handle
                        Text(
                          '@${user.handle}',
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 11.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),

                        // Algorithm Reason
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            reason,
                            style: TextStyle(
                              color: isDark ? Colors.grey[300] : Colors.grey[700],
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),

                    // Follow Button
                    SizedBox(
                      width: double.infinity,
                      height: 32,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFollowing
                              ? (isDark
                                  ? Colors.grey[800]
                                  : Colors.grey[200])
                              : AppColors.success,
                          foregroundColor: isFollowing
                              ? (isDark ? Colors.white70 : Colors.black)
                              : Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: isFollowing
                                ? BorderSide(
                                    color: isDark
                                        ? AppColors.borderDark
                                        : AppColors.borderLight,
                                  )
                                : BorderSide.none,
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          if (isFollowing) {
                            setState(() => _isFollowingLocally = false);
                            ref.read(userRepositoryProvider).unfollowUser(user.uid);
                          } else {
                            setState(() => _isFollowingLocally = true);
                            ref.read(userRepositoryProvider).followUser(user.uid);
                          }
                        },
                        child: Text(
                          isFollowing ? 'Following' : 'Follow',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: isFollowing
                                ? (isDark ? Colors.white70 : Colors.black)
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Top-right "X" Dismiss Button
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isDismissed = true);
                  Future.delayed(const Duration(milliseconds: 150), () {
                    widget.onDismiss();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.5)
                        : Colors.grey.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
