import 'package:abuad/src/shared/widgets/user_avatar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/verification_badge.dart';
import '../../../../core/utils/url_validator.dart';
import 'package:abuad/src/features/feed/data/post_repository.dart';
import '../../../auth/data/auth_repository.dart';
import '../../domain/post.dart' as domain;
import '../providers/feed_provider.dart';
import 'animated_like_button.dart';
import 'poll_widget.dart';
import 'video_post_widget.dart';
import '../../domain/report.dart';
import 'report_bottom_sheet.dart';
import 'full_screen_image_view.dart';
import 'full_screen_video_view.dart';
import 'post_media_carousel.dart';
import '../../../../shared/widgets/share_sheet.dart';
import '../../../../shared/widgets/abuad_markdown.dart';
import 'link_preview_card.dart';
import 'document_preview_card.dart';

class PostCard extends ConsumerStatefulWidget {
  final domain.Post post;
  final VoidCallback? onTap;
  final VoidCallback? onVideoTap;

  const PostCard({super.key, required this.post, this.onTap, this.onVideoTap});

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  Timer? _impressionTimer;
  Timer? _captionTimer;
  bool _impressionFired = false;
  bool _showVideoCaption = false;

  domain.Post get post => widget.post;

  @override
  void initState() {
    super.initState();
    // Feature 5: Impression tracking — fire view count after 1.5s of visibility
    _impressionTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted && !_impressionFired) {
        _impressionFired = true;
        ref.read(postRepositoryProvider).incrementViewCount(post.id);
      }
    });
    if (widget.post.mediaType == domain.MediaType.video) {
      _showVideoCaption = true;
      _captionTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _showVideoCaption = false);
        }
      });
    }
  }

  @override
  void dispose() {
    _impressionTimer?.cancel();
    _captionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(postRepositoryProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final livePost = ref.watch(postProvider(post.id)).value ?? post;
    final activeActionId = ref.watch(activePostActionProvider);
    final showActionOverlay = activeActionId == post.id;

    // Determine if this is a "Pure Repost" (no added commentary)
    final isPureRepost = post.repostData != null && post.content.trim().isEmpty;

    // Data to Display (Swap if Pure Repost)
    final displayAuthorName = isPureRepost
        ? (post.repostData!['author_name'] ?? 'Unknown')
        : post.authorName;
    final displayAvatarUrl = isPureRepost
        ? post.repostData!['author_avatar_url']
        : post.authorAvatarUrl;
    final displayContent = isPureRepost
        ? (post.repostData!['content'] ?? '')
        : post.content;
    final displayLinkUrl = isPureRepost
        ? (post.repostData!['link_url'] as String?)
        : post.linkUrl;
    final displayMediaUrl = isPureRepost
        ? (post.repostData!['media_url'] ?? '')
        : post.mediaUrl;
    final displayMediaTypeStr = isPureRepost
        ? (post.repostData!['media_type'] as String?)
        : null;
    final displayTimestamp = isPureRepost
        ? (DateTime.tryParse(post.repostData!['timestamp'] ?? '') ??
              post.timestamp)
        : post.timestamp;
    final displayIsVerified = isPureRepost
        ? (post.repostData!['is_verified'] == true)
        : post.isVerified;
    final displayVerificationType = isPureRepost
        ? (post.repostData!['verification_type'] ?? 'none')
        : post.verificationType;
    final displayIsAnonymous = isPureRepost
        ? (post.repostData!['is_anonymous'] == true)
        : post.isAnonymous;

    final videoCaption = (post.mediaAltText?.trim().isNotEmpty ?? false)
        ? post.mediaAltText!.trim()
        : '$displayAuthorName • ${_channelLabel(post.channelId)} video';

    // Media Type Enum Conversion
    domain.MediaType displayMediaType = post.mediaType;
    if (isPureRepost && displayMediaTypeStr != null) {
      displayMediaType = domain.MediaType.values.firstWhere(
        (e) => e.name == displayMediaTypeStr,
        orElse: () => domain.MediaType.none,
      );
    }
    if (displayMediaUrl.isNotEmpty) {
      final lowerUrl = displayMediaUrl.toLowerCase();
      if (lowerUrl.contains('.mp4') ||
          lowerUrl.contains('.mov') ||
          lowerUrl.contains('.webm') ||
          lowerUrl.contains('.m3u8') ||
          lowerUrl.contains('/videos/') ||
          displayMediaTypeStr == 'video') {
        displayMediaType = domain.MediaType.video;
      } else if (lowerUrl.contains('giphy') ||
          lowerUrl.endsWith('.gif') ||
          displayMediaTypeStr == 'gif') {
        displayMediaType = domain.MediaType.gif;
      } else if (lowerUrl.endsWith('.pdf') ||
          lowerUrl.endsWith('.doc') ||
          lowerUrl.endsWith('.docx') ||
          lowerUrl.endsWith('.ppt') ||
          lowerUrl.endsWith('.pptx') ||
          lowerUrl.endsWith('.xls') ||
          lowerUrl.endsWith('.xlsx') ||
          lowerUrl.endsWith('.txt') ||
          displayMediaTypeStr == 'document' ||
          post.mediaType == domain.MediaType.document) {
        displayMediaType = domain.MediaType.document;
      } else if (displayMediaType == domain.MediaType.none) {
        displayMediaType = domain.MediaType.image;
      }
    }

    // Determine author ID to watch
    final authorIdToWatch = isPureRepost
        ? post.repostData!['author_id']
        : post.authorId;
    final shouldWatch = !displayIsAnonymous && authorIdToWatch != null;

    final locationText = (post.locationName?.trim().isNotEmpty == true)
        ? post.locationName!.trim()
        : (post.latitude != null ? 'ABUAD Campus' : null);

    final cardContent = InkWell(
      onTap: widget.onTap ?? () => _openPostDetail(context),
      onLongPress: _displayActionOverlay,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(color: Colors.transparent),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Repost Header (Only for Pure Repost)
            if (isPureRepost)
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0, left: 34.0),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.repeat,
                      size: 16,
                      color: AppColors.secondaryTeal,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${post.authorName} reposted',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            StreamBuilder<AppUser?>(
              stream: shouldWatch
                  ? ref.read(userRepositoryProvider).watchUser(authorIdToWatch!)
                  : const Stream.empty(),
              builder: (context, snapshot) {
                final user = snapshot.data;
                final effectiveAuthorName =
                    user?.displayName ?? displayAuthorName;
                final effectiveAvatarUrl = user?.avatarUrl ?? displayAvatarUrl;
                final effectiveIsVerified =
                    user?.isVerified ?? displayIsVerified;
                final effectiveVerificationType =
                    user?.verificationType ?? displayVerificationType;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Avatar (Displayed Author)
                    UserAvatar(
                      userId: authorIdToWatch ?? '',
                      avatarUrl: displayIsAnonymous ? null : effectiveAvatarUrl,
                      radius: 22,
                      showStoryRing: !displayIsAnonymous,
                      backgroundColor: displayIsAnonymous
                          ? (isDark ? Colors.grey[700] : Colors.grey[800])
                          : (isDark ? Colors.grey[800] : Colors.grey[200]),
                      onTap: displayIsAnonymous
                          ? () {} // No-op for anonymous
                          : null, // Default navigation
                    ),
                    const SizedBox(width: 12),

                    // Right Column: Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Name + Verified + Timestamp + Follow (Single Line), More Menu (Right)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        displayIsAnonymous
                                            ? 'Anonymous Student'
                                            : effectiveAuthorName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          letterSpacing: -0.2,
                                          color: theme.textTheme.bodyLarge?.color,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    if (effectiveIsVerified && !displayIsAnonymous) ...[
                                      const SizedBox(width: 4),
                                      VerificationBadge(
                                        type: effectiveVerificationType,
                                        size: 14,
                                      ),
                                    ],
                                    const SizedBox(width: 6),
                                    Text(
                                      '• ${timeago.format(displayTimestamp, locale: 'en_short')}',
                                      style: TextStyle(
                                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                                        fontSize: 13,
                                      ),
                                    ),
                                    Consumer(
                                      builder: (context, ref, child) {
                                        final currentUserId = ref.watch(authRepositoryProvider).currentUser?.uid ??
                                            ref.watch(currentUserProvider).value?.uid;
                                        if ((currentUserId != null && currentUserId == post.authorId) || post.isAnonymous) {
                                          return const SizedBox.shrink();
                                        }
                                        final isFollowingAsync = ref.watch(
                                          isFollowingProvider(post.authorId),
                                        );
                                        return isFollowingAsync.when(
                                          data: (isFollowing) {
                                            if (isFollowing) return const SizedBox.shrink();
                                            return Padding(
                                              padding: const EdgeInsets.only(left: 8.0),
                                              child: GestureDetector(
                                                onTap: () {
                                                  ref
                                                      .read(userRepositoryProvider)
                                                      .followUser(post.authorId);
                                                },
                                                child: Text(
                                                  'Follow',
                                                  style: TextStyle(
                                                    color: AppColors.secondaryTeal,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                          loading: () => const SizedBox.shrink(),
                                          error: (_, _) => const SizedBox.shrink(),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => _showPostMenu(context, ref, post),
                                icon: Icon(
                                  Icons.more_horiz,
                                  size: 20,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          if (locationText != null && displayMediaUrl.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Row(
                                children: [
                                  const Icon(
                                    CupertinoIcons.location_fill,
                                    size: 12,
                                    color: AppColors.secondaryTeal,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    locationText,
                                    style: const TextStyle(
                                      color: AppColors.secondaryTeal,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Post Content
                          if (displayContent.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: _buildHighlightedContent(
                                context,
                                displayContent,
                                theme,
                                ref,
                              ),
                            ),
                          LinkPreviewCard(
                            url:
                                displayLinkUrl ??
                                UrlValidator.extractFirstUrl(displayContent),
                            margin: const EdgeInsets.only(bottom: 10),
                          ),

                          // Repost (Quote) Rendering
                          if (!isPureRepost && post.repostData != null) ...[
                            GestureDetector(
                              onTap: () {
                                final originalPost = domain.Post.fromMap(
                                  post.repostData!,
                                );
                                context.push(
                                  '/post/${originalPost.id}',
                                  extra: originalPost,
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(
                                  bottom: 12,
                                  top: 4,
                                ),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.03)
                                      : Colors.black.withValues(alpha: 0.02),
                                  border: Border.all(
                                    color: isDark
                                        ? AppColors.borderDark
                                        : AppColors.borderLight,
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        if (post.repostData!['author_avatar_url'] !=
                                            null) ...[
                                          UserAvatar(
                                            userId:
                                                post.repostData!['author_id'] ??
                                                '',
                                            avatarUrl: post
                                                .repostData!['author_avatar_url'],
                                            radius: 10,
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        Flexible(
                                          child: Text(
                                            post.repostData!['author_name'] ??
                                                'Unknown',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            '@${post.repostData!['author_handle'] ?? ''}',
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.grey[500]
                                                  : Colors.grey[600],
                                              fontSize: 13,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          ' • ${timeago.format(DateTime.tryParse(post.repostData!['timestamp'] ?? '') ?? DateTime.now(), locale: 'en_short')}',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.grey[500]
                                                : Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if ((post.repostData!['content'] as String?)
                                            ?.isNotEmpty ??
                                        false)
                                      Text(
                                        post.repostData!['content'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          height: 1.3,
                                        ),
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    if ((post.repostData!['media_url']
                                                as String?)
                                            ?.isNotEmpty ??
                                        false) ...[
                                      const SizedBox(height: 10),
                                      (() {
                                        final rawMedia = post.repostData!['media_url'] as String?;
                                        final formattedMedia = UrlValidator.formatImageUrl(rawMedia);
                                        return (formattedMedia.isNotEmpty &&
                                                UrlValidator.isValidUrl(formattedMedia))
                                            ? CachedNetworkImage(
                                                imageUrl: formattedMedia,
                                                height: 160,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                              )
                                            : Container(
                                                height: 160,
                                                width: double.infinity,
                                                color: isDark
                                                    ? Colors.grey[900]
                                                    : Colors.grey[200],
                                                child: const Icon(Icons.image),
                                              );
                                      })(),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],

                          // Poll Rendering
                          if (post.pollData != null) ...[
                            PollWidget(post: post, repo: repo),
                            const SizedBox(height: 12),
                          ],

                          // Media (Displayed - Original or Reposted)
                          if (displayMediaUrl.isNotEmpty) ...[
                            if (displayMediaType == domain.MediaType.video)
                              Stack(
                                alignment: Alignment.bottomCenter,
                                children: [
                                  VideoPostWidget(
                                    videoUrl: displayMediaUrl,
                                    onTap: () {
                                      if (widget.onVideoTap != null) {
                                        widget.onVideoTap!();
                                      } else {
                                        context.push(
                                          '/reels',
                                          extra: {
                                            'videos': [post],
                                            'initialIndex': 0,
                                          },
                                        );
                                      }
                                    },
                                    onOpenFullscreen: () {
                                      if (widget.onVideoTap != null) {
                                        widget.onVideoTap!();
                                      } else {
                                        context.push(
                                          '/reels',
                                          extra: {
                                            'videos': [post],
                                            'initialIndex': 0,
                                          },
                                        );
                                      }
                                    },
                                  ),
                                  if (_showVideoCaption)
                                    _buildVideoCaption(
                                      videoCaption,
                                      isDark,
                                    ),
                                  if (locationText != null)
                                    Positioned(
                                      left: 12,
                                      bottom: 12,
                                      child: IgnorePointer(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.65,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                CupertinoIcons.location_fill,
                                                size: 14,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                locationText,
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
                                    ),
                                ],
                              )
                            else if (displayMediaType == domain.MediaType.document)
                              DocumentPreviewCard(
                                documentUrl: displayMediaUrl,
                                fileName: (post.mediaAltText != null && post.mediaAltText!.isNotEmpty)
                                    ? post.mediaAltText
                                    : null,
                              )
                            else
                              PostMediaCarousel(
                                imageUrls: post.allMediaUrls.isNotEmpty
                                    ? post.allMediaUrls
                                    : (displayMediaUrl.isNotEmpty ? [displayMediaUrl] : []),
                                postId: post.id,
                                locationText: locationText,
                              ),
                            const SizedBox(height: 12),
                          ],

                          // Actions Row (Matching reference screenshot UI)
                          Row(
                            children: [
                              // 1. Heart / Like Button
                              Consumer(
                                builder: (context, ref, child) {
                                  final optimisticMap = ref.watch(optimisticLikeProvider);
                                  final apiLiked = ref.watch(isPostLikedProvider(post.id)).value ?? false;
                                  final isLiked = optimisticMap.containsKey(post.id)
                                      ? optimisticMap[post.id]!
                                      : apiLiked;
                                  final optimisticCount = optimisticMap.containsKey(post.id)
                                      ? livePost.likesCount + (optimisticMap[post.id]! ? 1 : -1)
                                      : livePost.likesCount;
                                  return AnimatedLikeButton(
                                    isLiked: isLiked,
                                    count: optimisticCount.clamp(0, 999999),
                                    inactiveColor: isDark ? Colors.grey[500]! : Colors.grey[600]!,
                                    onTap: () async {
                                      ref.read(optimisticLikeProvider.notifier).toggle(post.id, apiLiked);
                                      try {
                                        await ref.read(postRepositoryProvider).toggleLike(post.id);
                                        ref.read(optimisticLikeProvider.notifier).confirm(post.id);
                                      } catch (_) {
                                        ref.read(optimisticLikeProvider.notifier).revert(post.id, apiLiked);
                                      }
                                    },
                                  );
                                },
                              ),
                              const SizedBox(width: 16),
                              // 2. Comment Button
                              _ActionButton(
                                icon: CupertinoIcons.chat_bubble,
                                count: livePost.commentsCount,
                                color: isDark ? Colors.grey[500]! : Colors.grey[600]!,
                                onTap: () => context.push(
                                  '/post/${post.id}',
                                  extra: post,
                                ),
                              ),
                              const SizedBox(width: 16),
                              // 3. Repost Button
                              _ActionButton(
                                icon: Icons.repeat,
                                count: livePost.repostCount > 0 ? livePost.repostCount : null,
                                color: isDark ? Colors.grey[500]! : Colors.grey[600]!,
                                onTap: () => _showRepostBottomSheet(context, ref, post),
                              ),
                              const SizedBox(width: 16),
                              // 4. Share / Forward Button
                              _ActionButton(
                                icon: CupertinoIcons.arrowshape_turn_up_right,
                                count: livePost.sharesCount > 0 ? livePost.sharesCount : null,
                                color: isDark ? Colors.grey[500]! : Colors.grey[600]!,
                                onTap: () => ShareSheet.show(context, post),
                              ),
                              const Spacer(),
                              // 4. Bookmark / Save Button (Far Right)
                              Consumer(
                                builder: (context, ref, child) {
                                  final optimisticSaveMap = ref.watch(optimisticSaveProvider);
                                  final apiSaved = ref.watch(isPostSavedProvider(post.id)).value ?? livePost.isSaved;
                                  final isSaved = optimisticSaveMap.containsKey(post.id)
                                      ? optimisticSaveMap[post.id]!
                                      : apiSaved;
                                  final optimisticSaveCount = optimisticSaveMap.containsKey(post.id)
                                      ? (livePost.savesCount + (optimisticSaveMap[post.id]! ? (apiSaved ? 0 : 1) : (apiSaved ? -1 : 0)))
                                      : livePost.savesCount;
                                  const goldColor = Color(0xFFFFB800);
                                  return _ActionButton(
                                    icon: isSaved ? CupertinoIcons.bookmark_solid : CupertinoIcons.bookmark,
                                    count: optimisticSaveCount > 0 ? optimisticSaveCount : (isSaved ? 1 : null),
                                    color: isSaved
                                        ? goldColor
                                        : (isDark ? Colors.grey[500]! : Colors.grey[600]!),
                                    onTap: () async {
                                      HapticFeedback.lightImpact();
                                      ref.read(optimisticSaveProvider.notifier).toggle(post.id, apiSaved);
                                      try {
                                        await ref.read(postRepositoryProvider).togglePostSave(post.id);
                                        ref.read(optimisticSaveProvider.notifier).confirm(post.id);
                                      } catch (_) {
                                        ref.read(optimisticSaveProvider.notifier).revert(post.id, apiSaved);
                                      }
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
    return Stack(
          clipBehavior: Clip.none,
          children: [
            cardContent,
            if (showActionOverlay) _buildActionOverlay(context, isDark),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.1, end: 0, duration: 300.ms);
  }

  String _channelLabel(String channelId) {
    if (channelId.isEmpty || channelId == 'general') return 'General';
    final parts = channelId.split(RegExp(r'[_\s]+'));
    return parts
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  Widget _buildVideoCaption(String text, bool isDark) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(0, 0, 0, 0.55),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(12),
            ),
          ),
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ),
    );
  }

  static void _showPostMenu(
    BuildContext context,
    WidgetRef ref,
    domain.Post post,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final repo = ref.read(postRepositoryProvider);
          final currentUserId = repo.currentUserId ??
              ref.read(authRepositoryProvider).currentUser?.uid ??
              ref.read(currentUserProvider).value?.uid;
          final isOwnPost = currentUserId != null && post.authorId == currentUserId;

          return SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isOwnPost)
                  ListTile(
                    leading: const Icon(CupertinoIcons.delete, color: Colors.red),
                    title: const Text(
                      'Delete Post',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () async {
                      final navigator = Navigator.of(context);
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Post'),
                          content: const Text(
                            'Are you sure you want to delete this post? This action cannot be undone.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        navigator.pop(); // Close bottom sheet
                        try {
                          await repo.deletePost(post.id);
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(content: Text('Post deleted')),
                          );
                        } catch (e) {
                          scaffoldMessenger.showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
                  ),
                Builder(
                  builder: (context) {
                    final isSavedAsync = ref.watch(isPostSavedProvider(post.id));
                    final isSaved = isSavedAsync.value ?? false;
                    return ListTile(
                      leading: Icon(
                        isSaved ? CupertinoIcons.bookmark_solid : CupertinoIcons.bookmark,
                        color: isSaved ? const Color(0xFFFFB800) : null,
                      ),
                      title: Text(isSaved ? 'Unsave Post' : 'Save Post'),
                      onTap: () {
                        Navigator.pop(context);
                        ref.read(postRepositoryProvider).togglePostSave(post.id);
                      },
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(CupertinoIcons.arrowshape_turn_up_right),
                  title: const Text('Share Post'),
                  onTap: () {
                    Navigator.pop(context);
                    ShareSheet.show(context, post);
                  },
                ),
                if (post.mediaUrl.isNotEmpty &&
                    (post.mediaType == domain.MediaType.image ||
                        post.mediaType == domain.MediaType.gif))
                  ListTile(
                    leading: const Icon(Icons.download),
                    title: Text(
                      post.mediaType == domain.MediaType.video
                          ? 'Save Video'
                          : 'Save Image',
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      if (post.mediaType == domain.MediaType.video) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FullScreenVideoView(
                              videoUrl: post.mediaUrl,
                              heroTag: 'post_media_${post.id}',
                            ),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FullScreenImageView(
                              imageUrl: post.mediaUrl,
                              heroTag: 'post_media_${post.id}',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                if (!isOwnPost)
                  ListTile(
                    leading: const Icon(
                      CupertinoIcons.hand_thumbsdown,
                      color: Colors.blueGrey,
                    ),
                    title: const Text('Not Interested'),
                    subtitle: const Text('See fewer posts like this'),
                    onTap: () {
                      Navigator.pop(context);
                      ref.read(hiddenPostsProvider.notifier).hide(post.id);
                      if (post.hashtags.isNotEmpty) {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Tune your feed'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Also mute these topics?'),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  children: post.hashtags
                                      .take(5)
                                      .map(
                                        (tag) => ActionChip(
                                          label: Text('#$tag'),
                                          onPressed: () {
                                            ref
                                                .read(mutedHashtagsProvider.notifier)
                                                .mute(tag);
                                            Navigator.pop(ctx);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Muted #$tag')),
                                            );
                                          },
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Skip'),
                              ),
                            ],
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Post hidden from your feed')),
                        );
                      }
                    },
                  ),
                if (!isOwnPost)
                  ListTile(
                    leading: const Icon(Icons.block, color: Colors.orange),
                    title: const Text(
                      'Block User',
                      style: TextStyle(color: Colors.orange),
                    ),
                    onTap: () async {
                      final navigator = Navigator.of(context);
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Block User?'),
                          content: Text(
                            'Are you sure you want to block ${post.authorName}? You will no longer see their posts and they won\'t be able to message you.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(foregroundColor: Colors.orange),
                              child: const Text('Block'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        navigator.pop(); // Close bottom sheet
                        await ref.read(userRepositoryProvider).blockUser(post.authorId);
                        scaffoldMessenger.showSnackBar(
                          SnackBar(content: Text('${post.authorName} blocked')),
                        );
                      }
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.report_outlined),
                  title: const Text('Report Post'),
                  onTap: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => ReportBottomSheet(
                        targetId: post.id,
                        type: ReportType.post,
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cancel),
                  title: const Text('Cancel'),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showRepostBottomSheet(
    BuildContext context,
    WidgetRef ref,
    domain.Post originalPost,
  ) {
    final commentController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final commentText = commentController.text.trim();
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        Navigator.pop(context);
                        try {
                          await ref
                              .read(postRepositoryProvider)
                              .repost(originalPost, commentText);
                          ref.invalidate(paginatedFeedProvider);
                          final currentUserId = ref.read(authRepositoryProvider).currentUser?.uid;
                          if (currentUserId != null) {
                            ref.invalidate(userPostsProvider(currentUserId));
                          }
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text("Post reposted successfully!"),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        } catch (e) {
                          debugPrint('Error posting repost: $e');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text("Repost"),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User Avatar
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.grey,
                      child: Icon(Icons.person, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: commentController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: "Add a comment...",
                          border: InputBorder.none,
                        ),
                        maxLines: 4,
                        minLines: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Quoted Post Preview
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      if (originalPost.mediaUrl.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: originalPost.mediaUrl,
                            height: 60,
                            width: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              originalPost.authorName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              originalPost.content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightedContent(
    BuildContext context,
    String text,
    ThemeData theme,
    WidgetRef ref,
  ) {
    if (text.isEmpty) return const SizedBox.shrink();
    final isDark = theme.brightness == Brightness.dark;
    return AbuadMarkdownContent(
      content: text,
      textStyle: TextStyle(
        fontSize: 16,
        height: 1.38,
        color: theme.textTheme.bodyLarge?.color ?? (isDark ? Colors.white : Colors.black87),
      ),
    );
  }

  void _openPostDetail(BuildContext context) {
    ref.read(activePostActionProvider.notifier).hide();
    context.push('/post/${post.id}', extra: post);
  }

  void _displayActionOverlay() {
    HapticFeedback.mediumImpact();
    ref.read(activePostActionProvider.notifier).show(post.id);
  }

  Widget _buildActionOverlay(BuildContext context, bool isDark) {
    final backgroundColor = isDark
        ? const Color.fromRGBO(0, 0, 0, 0.55)
        : const Color.fromRGBO(255, 255, 255, 0.9);
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => ref.read(activePostActionProvider.notifier).hide(),
            behavior: HitTestBehavior.opaque,
            child: Container(
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
            ),
          ),
          Positioned(
            right: 14,
            top: 14,
            bottom: 14,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _overlayActionButton(
                  icon: Icons.rocket_launch,
                  label: 'Boost this post',
                  color: AppColors.secondaryTeal,
                  onTap: () => _handleBoost(context),
                ),
                const SizedBox(height: 12),
                _overlayActionButton(
                  icon: Icons.emoji_emotions_outlined,
                  label: 'Add reaction',
                  color: isDark ? Colors.white : Colors.black87,
                  onTap: () => _handleAddReaction(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _overlayActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final rootNotifier = ref.read(activePostActionProvider.notifier);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          onTap();
          rootNotifier.hide();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withAlpha(40),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withAlpha(120)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleBoost(BuildContext context) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Boost queued for this post'),
        duration: Duration(milliseconds: 900),
      ),
    );
  }

  void _handleAddReaction(BuildContext context) {
    if (!context.mounted) return;
    final reactions = ['🔥', '❤️', '👏', '😮', '😂', '👍'];
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (modalContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Send a reaction',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: reactions.map((emoji) {
                  return ActionChip(
                    label: Text(emoji, style: const TextStyle(fontSize: 26)),
                    onPressed: () {
                      Navigator.pop(modalContext);
                      messenger.showSnackBar(
                        SnackBar(content: Text('Reacted with $emoji')),
                      );
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(modalContext),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final int? count;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.count,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final countText = count != null ? formatCount(count!) : '';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque, // Ensure tap target
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 6.0, // Reduced padding for compact fit
          vertical: 8.0,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: count == null
                  ? color // Use passed color (grey/themed)
                  : (count! > 0 ? color : color.withValues(alpha: 0.7)),
            ),
            if (countText.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                countText,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
