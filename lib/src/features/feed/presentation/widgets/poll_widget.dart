import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/post_repository.dart';
import '../../domain/post.dart';

class PollWidget extends StatefulWidget {
  final Post post;
  final PostRepository repo;

  const PollWidget({super.key, required this.post, required this.repo});

  @override
  State<PollWidget> createState() => _PollWidgetState();
}

class _PollWidgetState extends State<PollWidget> {
  int? _optimisticVotedIndex;
  int? _selectedPendingIndex;
  Map<String, dynamic>? _livePollData;

  @override
  void didUpdateWidget(PollWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post.pollData != oldWidget.post.pollData) {
      _livePollData = widget.post.pollData;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pollData = _livePollData ?? widget.post.pollData;
    if (pollData == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final List<dynamic> optionsRaw = pollData['options'] ?? [];

    // Safely parse options (could be String or Map)
    final options = optionsRaw.map((opt) {
      if (opt is String) return opt;
      if (opt is Map) return opt['text']?.toString() ?? 'Option';
      return opt.toString();
    }).toList();

    // Safely parse votes
    final List<dynamic> votesRaw = pollData['votes'] ?? [];
    final voters = Map<String, dynamic>.from(pollData['voters'] ?? {});
    final currentUserId = widget.repo.currentUserId;
    int? serverVotedIndex;
    if (currentUserId != null && currentUserId.isNotEmpty) {
      if (voters.containsKey(currentUserId)) {
        serverVotedIndex = (voters[currentUserId] as num?)?.toInt();
      }
    } else if (pollData['userVotedIndex'] != null) {
      serverVotedIndex = (pollData['userVotedIndex'] as num?)?.toInt();
    }

    final userVoteIndex = _optimisticVotedIndex ?? serverVotedIndex;
    final hasVoted = userVoteIndex != null;

    final votes = List<int>.generate(options.length, (i) {
      int baseCount = 0;
      if (i < votesRaw.length) {
        baseCount = (votesRaw[i] as num?)?.toInt() ?? 0;
      } else if (i < optionsRaw.length && optionsRaw[i] is Map) {
        baseCount = (optionsRaw[i]['votes'] as num?)?.toInt() ?? 0;
      }
      // Apply optimistic vote delta if newly voted or changed vote locally
      if (_optimisticVotedIndex != null && serverVotedIndex != _optimisticVotedIndex) {
        if (_optimisticVotedIndex == i) baseCount += 1;
        if (serverVotedIndex != null && serverVotedIndex == i) baseCount = (baseCount - 1).clamp(0, 999999);
      }
      return baseCount;
    });

    // Check poll expiration
    final endsAtStr = pollData['ends_at'] as String?;
    final endsAt = endsAtStr != null && endsAtStr.isNotEmpty
        ? DateTime.tryParse(endsAtStr)
        : widget.post.timestamp.add(const Duration(days: 1));
    final now = DateTime.now();
    final isEnded = endsAt != null && now.isAfter(endsAt);

    // If ended or user has voted, show results mode
    final showResults = hasVoted || isEnded;
    final totalVotes = votes.fold<int>(0, (sum, item) => sum + item);

    // Compute remaining time text
    final String pollStatusText;
    if (isEnded) {
      pollStatusText = 'Poll ended';
    } else if (endsAt != null) {
      final diff = endsAt.difference(now);
      if (diff.inDays >= 1) {
        pollStatusText = 'Poll ends in ${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'}';
      } else if (diff.inHours >= 1) {
        pollStatusText = 'Poll ends in ${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'}';
      } else if (diff.inMinutes >= 1) {
        pollStatusText = 'Poll ends in ${diff.inMinutes} ${diff.inMinutes == 1 ? 'minute' : 'minutes'}';
      } else {
        pollStatusText = 'Poll ends soon';
      }
    } else {
      pollStatusText = 'Poll active';
    }

    final String? question = pollData['question'] as String?;

    // Theme-adaptive styling matching feed design system
    final cardBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFFE2E8F0);
    final cardBgColor = isDark
        ? const Color(0xFF0F172A)
        : Colors.white;
    final textColor = isDark
        ? Colors.white
        : const Color(0xFF0F172A);
    final secondaryTextColor = isDark
        ? Colors.white.withValues(alpha: 0.6)
        : const Color(0xFF64748B);
    const accentBlue = Color(0xFF2563EB);
    const primaryBlue = Color(0xFF3B82F6);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBgColor,
        border: Border.all(color: cardBorderColor, width: 1.0),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black45 : Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Badge: [Poll]
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: primaryBlue.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: primaryBlue.withValues(alpha: 0.35), width: 0.8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.poll_rounded, color: primaryBlue, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Poll',
                      style: TextStyle(
                        color: primaryBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                pollStatusText,
                style: TextStyle(
                  color: secondaryTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (question != null && question.trim().isNotEmpty) ...[
            Text(
              question,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: textColor,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
          ],

          ...List.generate(options.length, (index) {
            final optionText = options[index];
            final voteCount = index < votes.length ? votes[index] : 0;
            final percentage = totalVotes == 0 ? 0.0 : (voteCount / totalVotes);
            final isUserVoted = userVoteIndex == index;
            final isSelectedPending = _selectedPendingIndex == index;

            final optionBg = isUserVoted
                ? primaryBlue.withValues(alpha: isDark ? 0.22 : 0.12)
                : (isDark ? const Color(0xFF161E2E) : const Color(0xFFF8FAFC));
            final optionBorder = isUserVoted || isSelectedPending
                ? primaryBlue
                : (isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE2E8F0));

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () async {
                  if (isEnded || userVoteIndex == index) return;

                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedPendingIndex = index;
                    _optimisticVotedIndex = index;
                  });

                  // Execute vote API and sync state
                  final updatedPoll = await widget.repo.votePoll(widget.post.id, index);
                  if (mounted && updatedPoll != null) {
                    setState(() {
                      _livePollData = updatedPoll;
                      _selectedPendingIndex = null;
                    });
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 50,
                  decoration: BoxDecoration(
                    color: optionBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: optionBorder,
                      width: isUserVoted || isSelectedPending ? 1.5 : 1.0,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Stack(
                      children: [
                        // Animated Horizontal Progress Bar for Results View
                        if (showResults)
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 450),
                            curve: Curves.easeOutCubic,
                            tween: Tween<double>(begin: 0.0, end: percentage),
                            builder: (context, value, _) {
                              return FractionallySizedBox(
                                widthFactor: value,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isUserVoted
                                          ? [
                                              primaryBlue.withValues(alpha: isDark ? 0.45 : 0.25),
                                              primaryBlue.withValues(alpha: isDark ? 0.6 : 0.35),
                                            ]
                                          : [
                                              isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
                                              isDark ? Colors.white.withValues(alpha: 0.14) : Colors.black.withValues(alpha: 0.08),
                                            ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                        // Option Content & Label (Centered vertically)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // State 1: Radio button outline before voting
                                if (!showResults) ...[
                                  Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelectedPending
                                            ? primaryBlue
                                            : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                                        width: isSelectedPending ? 5 : 1.6,
                                      ),
                                      color: isSelectedPending ? primaryBlue : Colors.transparent,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],

                                // State 2: User Voted checkmark icon
                                if (showResults && isUserVoted) ...[
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: primaryBlue,
                                    size: 19,
                                  ),
                                  const SizedBox(width: 10),
                                ],

                                // Option text (adaptive text color)
                                Expanded(
                                  child: Text(
                                    optionText,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: isUserVoted ? FontWeight.bold : FontWeight.w500,
                                      color: isUserVoted && !isDark ? primaryBlue : textColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),

                                // State 3: Percentage label on right
                                if (showResults) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '${(percentage * 100).round()}%',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isUserVoted ? FontWeight.w800 : FontWeight.w600,
                                      color: isUserVoted ? primaryBlue : secondaryTextColor,
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
              ),
            );
          }),

          // Footer: Vote count & Tap to vote hint
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              '$totalVotes ${totalVotes == 1 ? 'vote' : 'votes'}${hasVoted || isEnded ? '' : ' • Tap to vote'}',
              style: TextStyle(
                color: secondaryTextColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
