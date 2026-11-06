import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/widgets/verification_badge.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../../shared/widgets/formatted_comment_content.dart';
import '../../../user/data/user_repository.dart';
import '../../data/post_repository.dart';
import '../../domain/post.dart';

/// Distinctive Creator Badge with clean blue text
class CreatorBadge extends StatelessWidget {
  final double fontSize;
  const CreatorBadge({super.key, this.fontSize = 10});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: const Color(0xFF0284C7).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: const Color(0xFF0284C7).withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Text(
        'Creator',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF0284C7),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// A structured container representing a top-level comment and its direct replies
class CommentThreadData {
  final Map<String, dynamic> rootComment;
  final List<Map<String, dynamic>> replies;
  final bool isPinned;
  final int verificationTier; // 3: Gold, 2: Purple/Violet, 1: Blue, 0: None
  final int engagementScore;

  const CommentThreadData({
    required this.rootComment,
    required this.replies,
    required this.isPinned,
    required this.verificationTier,
    required this.engagementScore,
  });
}

/// Comment & Reply Thread View:
/// Priority 0: Explicitly Pinned Conversations (Pinned by creator)
/// Priority 1: Gold Verified Users
/// Priority 2: Purple / Violet Verified Users
/// Priority 3: Blue Verified Users
/// Priority 4: Other / Non-Verified Comments (Under "Other comments" divider)
class CommentThreadView extends ConsumerStatefulWidget {
  final Post post;
  final List<Map<String, dynamic>> comments;
  final Function(String commentId, String userName) onReply;
  final Function(BuildContext context, String commentId, bool isOwn, {String? currentContent, bool? isPinned})? onMenu;
  final String? currentUserId;
  final bool isScrollable;

  const CommentThreadView({
    super.key,
    required this.post,
    required this.comments,
    required this.onReply,
    this.onMenu,
    this.currentUserId,
    this.isScrollable = true,
  });

  @override
  ConsumerState<CommentThreadView> createState() => _CommentThreadViewState();
}

class _CommentThreadViewState extends ConsumerState<CommentThreadView> {
  /// Track how many replies are currently revealed for each thread (0 = collapsed)
  final Map<String, int> _visibleRepliesCount = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    // 1. Partition comments into top-level and replies
    final Map<String, List<Map<String, dynamic>>> repliesByParentId = {};
    final List<Map<String, dynamic>> topLevelComments = [];

    // Deduplicate incoming raw comments
    final seenIds = <String>{};
    final deduped = <Map<String, dynamic>>[];
    for (final c in widget.comments) {
      final id = (c['id'] ?? '').toString();
      if (id.isNotEmpty && !seenIds.contains(id)) {
        seenIds.add(id);
        deduped.add(c);
      }
    }

    for (final c in deduped) {
      final parentId = c['parentId']?.toString();
      if (parentId != null && parentId.isNotEmpty && parentId != 'null') {
        repliesByParentId.putIfAbsent(parentId, () => []).add(c);
      } else {
        topLevelComments.add(c);
      }
    }

    // Sort replies chronologically (oldest to newest) within each thread
    for (final replies in repliesByParentId.values) {
      replies.sort((a, b) {
        final tsA = (a['timestamp'] is int) ? a['timestamp'] as int : 0;
        final tsB = (b['timestamp'] is int) ? b['timestamp'] as int : 0;
        return tsA.compareTo(tsB);
      });
    }

    final creatorId = widget.post.authorId;

    // 2. Build CommentThreadData objects
    final List<CommentThreadData> threads = topLevelComments.map((root) {
      final rootId = root['id']?.toString() ?? '';
      final replies = repliesByParentId[rootId] ?? const [];
      final isPinned = root['isPinned'] == true || root['pinned'] == true;

      // Extract verification tier
      final vType = root['authorVerificationType'] ??
          root['author_verification_type'] ??
          (root['author']?['verificationType'] ??
              (root['author']?['isVerified'] == true ? 'blue' : 'none'));
      final tierWeight = VerificationBadge.getTierWeight(vType);

      final likes = (root['likesCount'] as num?)?.toInt() ?? 0;
      final replyCount = replies.length;
      final engagementScore = (likes * 3) + (replyCount * 2);

      return CommentThreadData(
        rootComment: root,
        replies: replies,
        isPinned: isPinned,
        verificationTier: tierWeight,
        engagementScore: engagementScore,
      );
    }).toList();

    // 3. Segment into display priority tiers
    // Tier 0: Explicitly Pinned Threads (Top)
    final pinnedThreads = <CommentThreadData>[];
    // Tier 1: Gold Verified Users (3)
    final goldThreads = <CommentThreadData>[];
    // Tier 2: Purple / Violet Verified Users (2)
    final purpleThreads = <CommentThreadData>[];
    // Tier 3: Blue Verified Users (1)
    final blueThreads = <CommentThreadData>[];
    // Tier 4: Other / Non-Verified Comments (0)
    final otherThreads = <CommentThreadData>[];

    for (final thread in threads) {
      if (thread.isPinned) {
        pinnedThreads.add(thread);
      } else if (thread.verificationTier == 3) {
        goldThreads.add(thread);
      } else if (thread.verificationTier == 2) {
        purpleThreads.add(thread);
      } else if (thread.verificationTier == 1) {
        blueThreads.add(thread);
      } else {
        otherThreads.add(thread);
      }
    }

    // Secondary deterministic sorting within each tier: engagement score, then timestamp
    int compareSecondary(CommentThreadData a, CommentThreadData b) {
      if (a.engagementScore != b.engagementScore) {
        return b.engagementScore.compareTo(a.engagementScore);
      }
      final tsA = (a.rootComment['timestamp'] is int) ? a.rootComment['timestamp'] as int : 0;
      final tsB = (b.rootComment['timestamp'] is int) ? b.rootComment['timestamp'] as int : 0;
      return tsB.compareTo(tsA);
    }

    pinnedThreads.sort(compareSecondary);
    goldThreads.sort(compareSecondary);
    purpleThreads.sort(compareSecondary);
    blueThreads.sort(compareSecondary);
    otherThreads.sort(compareSecondary);

    final hasVerifiedOrPinned = pinnedThreads.isNotEmpty ||
        goldThreads.isNotEmpty ||
        purpleThreads.isNotEmpty ||
        blueThreads.isNotEmpty;

    final allItems = <Widget>[];

    // Priority 0: Explicitly Pinned Threads
    for (final t in pinnedThreads) {
      allItems.add(_buildThreadCard(t, isDark: isDark));
    }

    // Priority 1: Gold Verified
    for (final t in goldThreads) {
      allItems.add(_buildThreadCard(t, isDark: isDark));
    }

    // Priority 2: Purple / Violet Verified
    for (final t in purpleThreads) {
      allItems.add(_buildThreadCard(t, isDark: isDark));
    }

    // Priority 3: Blue Verified
    for (final t in blueThreads) {
      allItems.add(_buildThreadCard(t, isDark: isDark));
    }

    // Priority 4: Non-Verified / Other Comments
    if (otherThreads.isNotEmpty) {
      if (hasVerifiedOrPinned) {
        allItems.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Text(
                  'Other comments',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: textSecondary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Divider(
                    height: 1,
                    thickness: 0.8,
                    color: borderColor.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      for (final t in otherThreads) {
        allItems.add(_buildThreadCard(t, isDark: isDark));
      }
    }

    if (allItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.chat_bubble_2,
                size: 42,
                color: isDark ? Colors.white24 : Colors.grey[400],
              ),
              const SizedBox(height: 10),
              Text(
                'No comments yet',
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Be the first to share your thoughts!',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.isScrollable) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: allItems.length,
        itemBuilder: (context, index) => allItems[index],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: allItems,
    );
  }

  Widget _buildThreadCard(
    CommentThreadData thread, {
    required bool isDark,
  }) {
    final root = thread.rootComment;
    final rootId = root['id']?.toString() ?? '';
    final totalReplies = thread.replies.length;
    final visibleCount = _visibleRepliesCount[rootId] ?? 0;
    final isExpanded = visibleCount > 0;
    final creatorId = widget.post.authorId;
    final isRootByCreator = (root['authorId'] ?? root['userId'] ?? '').toString() == creatorId;

    Widget cardBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pinned by creator banner - only shown if explicitly pinned
        if (thread.isPinned)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.pin_fill,
                  size: 13,
                  color: Color(0xFF0284C7),
                ),
                const SizedBox(width: 5),
                Text(
                  'Pinned by creator',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                  ),
                ),
                if (isRootByCreator) ...[
                  const SizedBox(width: 6),
                  const CreatorBadge(),
                ],
              ],
            ),
          ),

        // Main Parent Comment Tile
        _CommentRow(
          comment: root,
          postId: widget.post.id,
          creatorId: creatorId,
          isRoot: true,
          replyCount: totalReplies,
          isExpanded: isExpanded,
          onToggleReplies: () {
            setState(() {
              if (isExpanded) {
                _visibleRepliesCount[rootId] = 0;
              } else {
                _visibleRepliesCount[rootId] = math.min(3, totalReplies);
              }
            });
          },
          onReply: () => widget.onReply(
            rootId,
            (root['authorName'] ?? root['userName'] ?? 'Student').toString(),
          ),
          onMenu: widget.onMenu != null
              ? (ctx, id, isOwn, {content, isPinned}) => widget.onMenu!(
                    ctx,
                    id,
                    isOwn,
                    currentContent: content,
                    isPinned: isPinned ?? (root['isPinned'] == true),
                  )
              : null,
          currentUserId: widget.currentUserId,
          isDark: isDark,
        ),

        // Nested Replies Tree with Dot connector drawing & 3-by-3 pagination
        if (thread.replies.isNotEmpty)
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _RepliesTree(
              rootId: rootId,
              postId: widget.post.id,
              creatorId: creatorId,
              replies: thread.replies,
              visibleCount: visibleCount,
              currentUserId: widget.currentUserId,
              onReply: widget.onReply,
              onMenu: widget.onMenu,
              isDark: isDark,
              onShowMore: () {
                setState(() {
                  _visibleRepliesCount[rootId] = math.min(visibleCount + 3, totalReplies);
                });
              },
              onHideReplies: () {
                setState(() {
                  _visibleRepliesCount[rootId] = 0;
                });
              },
            ),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 240),
            firstCurve: Curves.easeOutCubic,
            secondCurve: Curves.easeOutCubic,
          ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: cardBody,
    );
  }
}

/// Indented Replies Tree with dotted/branched connector lines and node dots
class _RepliesTree extends StatelessWidget {
  final String rootId;
  final String postId;
  final String creatorId;
  final List<Map<String, dynamic>> replies;
  final int visibleCount;
  final String? currentUserId;
  final Function(String commentId, String userName) onReply;
  final Function(BuildContext context, String commentId, bool isOwn, {String? currentContent, bool? isPinned})? onMenu;
  final bool isDark;
  final VoidCallback onShowMore;
  final VoidCallback onHideReplies;

  const _RepliesTree({
    required this.rootId,
    required this.postId,
    required this.creatorId,
    required this.replies,
    required this.visibleCount,
    required this.currentUserId,
    required this.onReply,
    this.onMenu,
    required this.isDark,
    required this.onShowMore,
    required this.onHideReplies,
  });

  @override
  Widget build(BuildContext context) {
    final connectorColor = isDark
        ? const Color(0xFF475569).withValues(alpha: 0.6)
        : const Color(0xFFCBD5E1);

    final displayedReplies = replies.take(visibleCount).toList();
    final remaining = replies.length - displayedReplies.length;

    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...displayedReplies.asMap().entries.map((entry) {
            final index = entry.key;
            final reply = entry.value;
            final isLast = index == displayedReplies.length - 1 && remaining == 0;
            final replyAuthorId = (reply['authorId'] ?? reply['userId'] ?? '').toString();
            final isCreatorReply = creatorId.isNotEmpty && replyAuthorId == creatorId;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Custom drawn dotted/curved branch connector
                  SizedBox(
                    width: 24,
                    child: CustomPaint(
                      painter: _ThreadConnectorPainter(
                        isLast: isLast,
                        color: isCreatorReply ? const Color(0xFF0284C7) : connectorColor,
                        isHighlighted: isCreatorReply,
                      ),
                    ),
                  ),
                  // Reply content item
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _CommentRow(
                        comment: reply,
                        postId: postId,
                        creatorId: creatorId,
                        isRoot: false,
                        replyCount: 0,
                        isExpanded: false,
                        onToggleReplies: () {},
                        onReply: () => onReply(
                          rootId,
                          (reply['authorName'] ?? reply['userName'] ?? 'Student').toString(),
                        ),
                        onMenu: onMenu != null
                            ? (ctx, id, isOwn, {content, isPinned}) => onMenu!(
                                  ctx,
                                  id,
                                  isOwn,
                                  currentContent: content,
                                  isPinned: isPinned ?? (reply['isPinned'] == true),
                                )
                            : null,
                        currentUserId: currentUserId,
                        isDark: isDark,
                        isCreatorReply: isCreatorReply,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Pagination controls: Show more (X remaining) | Hide replies
          if (displayedReplies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 2, bottom: 6),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 6,
                children: [
                  if (remaining > 0)
                    GestureDetector(
                      onTap: onShowMore,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              CupertinoIcons.arrow_turn_down_right,
                              size: 11,
                              color: Color(0xFF6366F1),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Show more replies ($remaining remaining)',
                              style: const TextStyle(
                                color: Color(0xFF6366F1),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  GestureDetector(
                    onTap: onHideReplies,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.chevron_up,
                            size: 10,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Hide replies',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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

/// Custom painter that draws the authentic tree branch line and connector node dot
class _ThreadConnectorPainter extends CustomPainter {
  final bool isLast;
  final Color color;
  final bool isHighlighted;

  _ThreadConnectorPainter({
    required this.isLast,
    required this.color,
    required this.isHighlighted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = isHighlighted ? 1.8 : 1.4
      ..style = PaintingStyle.stroke;

    const startX = 6.0;
    const branchY = 16.0;
    final endX = size.width - 2.0;

    // Vertical line from top
    if (isLast) {
      // Curve to the right
      final path = Path()
        ..moveTo(startX, 0)
        ..lineTo(startX, branchY - 6)
        ..quadraticBezierTo(startX, branchY, startX + 6, branchY)
        ..lineTo(endX, branchY);
      canvas.drawPath(path, paint);
    } else {
      // Continuous vertical line through the height
      canvas.drawLine(
        const Offset(startX, 0),
        Offset(startX, size.height),
        paint,
      );
      // Horizontal branch
      canvas.drawLine(
        const Offset(startX, branchY),
        Offset(endX, branchY),
        paint,
      );
    }

    // Connector node dot at the branch end
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(endX, branchY), isHighlighted ? 3.0 : 2.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _ThreadConnectorPainter oldDelegate) {
    return oldDelegate.isLast != isLast ||
        oldDelegate.color != color ||
        oldDelegate.isHighlighted != isHighlighted;
  }
}

/// Individual comment / reply row component with author info, badges, content, like & reply actions
class _CommentRow extends ConsumerWidget {
  final Map<String, dynamic> comment;
  final String postId;
  final String creatorId;
  final bool isRoot;
  final int replyCount;
  final bool isExpanded;
  final VoidCallback onToggleReplies;
  final VoidCallback onReply;
  final Function(BuildContext context, String commentId, bool isOwn, {String? content, bool? isPinned})? onMenu;
  final String? currentUserId;
  final bool isDark;
  final bool isCreatorReply;

  const _CommentRow({
    required this.comment,
    required this.postId,
    required this.creatorId,
    required this.isRoot,
    required this.replyCount,
    required this.isExpanded,
    required this.onToggleReplies,
    required this.onReply,
    this.onMenu,
    required this.currentUserId,
    required this.isDark,
    this.isCreatorReply = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentId = comment['id']?.toString() ?? '';
    final authorId = (comment['authorId'] ?? comment['userId'] ?? '').toString();
    final rawName = (comment['authorName'] ?? comment['userName'] ?? 'Student').toString();
    final rawAvatar = comment['authorAvatarUrl'] ?? comment['userAvatar'] as String?;
    final rawVerificationType = (comment['authorVerificationType'] ?? 'none').toString();

    int tsInt = (comment['timestamp'] is int && (comment['timestamp'] as int) > 0)
        ? comment['timestamp'] as int
        : DateTime.now().millisecondsSinceEpoch;
    final timestamp = DateTime.fromMillisecondsSinceEpoch(tsInt);

    final bool isOwn = currentUserId != null && authorId.isNotEmpty && authorId == currentUserId;
    final bool isLiked = comment['isLiked'] == true;
    final int likesCount = (comment['likesCount'] as num?)?.toInt() ?? 0;
    final content = (comment['content'] ?? '').toString();
    final isAuthorCreator = creatorId.isNotEmpty && authorId == creatorId;

    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return StreamBuilder<AppUser?>(
      stream: authorId.isNotEmpty
          ? ref.read(userRepositoryProvider).watchUser(authorId)
          : const Stream.empty(),
      builder: (context, userSnapshot) {
        final user = userSnapshot.data;
        final effectiveName = (user != null && user.displayName.isNotEmpty)
            ? user.displayName
            : (rawName.isNotEmpty ? rawName : 'Student');
        final effectiveAvatar = user?.avatarUrl ?? rawAvatar;
        final effectiveVerification = user?.verificationType ?? rawVerificationType;
        final isVerified = user?.isVerified == true ||
            (effectiveVerification != 'none' && effectiveVerification.isNotEmpty);

        return InkWell(
          onLongPress: onMenu != null
              ? () => onMenu!(
                    context,
                    commentId,
                    isOwn,
                    content: content,
                    isPinned: comment['isPinned'] == true,
                  )
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isRoot ? 12 : 6,
              vertical: isRoot ? 8 : 4,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                GestureDetector(
                  onTap: () {
                    if (authorId.isNotEmpty) context.push('/user/$authorId');
                  },
                  child: UserAvatar(
                    userId: authorId,
                    avatarUrl: effectiveAvatar,
                    displayName: effectiveName,
                    radius: isRoot ? 18 : 14,
                    showStoryRing: isRoot,
                  ),
                ),
                const SizedBox(width: 10),

                // Main Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Username + Verification Badge + Creator Badge + Timestamp + More
                      Row(
                        children: [
                          Flexible(
                            child: GestureDetector(
                              onTap: () {
                                if (authorId.isNotEmpty) context.push('/user/$authorId');
                              },
                              child: Text(
                                effectiveName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: isRoot ? 13.5 : 12.5,
                                  color: textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 4),
                            VerificationBadge(
                              type: effectiveVerification,
                              size: isRoot ? 13.5 : 12,
                            ),
                          ],
                          if (isAuthorCreator) ...[
                            const SizedBox(width: 5),
                            const CreatorBadge(fontSize: 9.5),
                          ],
                          const SizedBox(width: 8),
                          Text(
                            timeago.format(timestamp, locale: 'en_short'),
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          if (onMenu != null)
                            GestureDetector(
                              onTap: () => onMenu!(
                                context,
                                commentId,
                                isOwn,
                                content: content,
                                isPinned: comment['isPinned'] == true,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(left: 6, bottom: 2),
                                child: Icon(
                                  Icons.more_horiz,
                                  size: 16,
                                  color: textSecondary.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Comment Text
                      FormattedCommentContent(
                        content: content,
                        textStyle: TextStyle(
                          fontSize: isRoot ? 13.5 : 12.5,
                          color: textPrimary,
                          height: 1.35,
                        ),
                      ),

                      // Optional image attachment
                      if (comment['imageUrl'] != null && comment['imageUrl'] != '') ...[
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: comment['imageUrl'],
                            maxHeightDiskCache: 350,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              height: 140,
                              color: isDark ? Colors.white10 : Colors.black12,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 6),

                      // Bottom Action Row: Like ♡ count | Reply | View N replies ∨
                      Row(
                        children: [
                          // Like button & count
                          GestureDetector(
                            onTap: () {
                              ref.read(postRepositoryProvider).toggleCommentLike(postId, commentId);
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                                  size: 14.5,
                                  color: isLiked ? Colors.redAccent : textSecondary,
                                ),
                                if (likesCount > 0) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    '$likesCount',
                                    style: TextStyle(
                                      color: isLiked ? Colors.redAccent : textSecondary,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Reply action button
                          GestureDetector(
                            onTap: onReply,
                            child: Text(
                              'Reply',
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),

                          // View replies expand / collapse toggle (for root comments with replies)
                          if (isRoot && replyCount > 0) ...[
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: onToggleReplies,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isExpanded
                                        ? 'Hide replies'
                                        : (replyCount == 1 ? 'Show reply' : 'Show replies ($replyCount)'),
                                    style: TextStyle(
                                      color: const Color(0xFF6366F1),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    isExpanded
                                        ? CupertinoIcons.chevron_up
                                        : CupertinoIcons.chevron_down,
                                    size: 11,
                                    color: const Color(0xFF6366F1),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
