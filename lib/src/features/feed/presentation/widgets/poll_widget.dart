import 'package:flutter/material.dart';
import '../../data/post_repository.dart';
import '../../domain/post.dart';

class PollWidget extends StatelessWidget {
  final Post post;
  final PostRepository repo;

  const PollWidget({super.key, required this.post, required this.repo});

  @override
  Widget build(BuildContext context) {
    if (post.pollData == null) return const SizedBox.shrink();

    final pollData = post.pollData!;
    final List<dynamic> optionsRaw = pollData['options'] ?? [];

    // Safely parse options (could be String or Map)
    final options = optionsRaw.map((opt) {
      if (opt is String) return opt;
      if (opt is Map) return opt['text']?.toString() ?? 'Option';
      return opt.toString();
    }).toList();

    // Safely parse votes
    final List<dynamic> votesRaw = pollData['votes'] ?? [];
    final votes = List<int>.generate(options.length, (i) {
      if (i < votesRaw.length) {
        return (votesRaw[i] as num?)?.toInt() ?? 0;
      }
      // Fallback: check if votes are inside the option maps
      if (i < optionsRaw.length && optionsRaw[i] is Map) {
        return (optionsRaw[i]['votes'] as num?)?.toInt() ?? 0;
      }
      return 0;
    });

    final voters = Map<String, dynamic>.from(pollData['voters'] ?? {});
    final totalVotes = votes.fold(0, (sum, item) => sum + item);
    final currentUserId = repo.currentUserId;
    final userVoteIndex = currentUserId != null
        ? (voters[currentUserId] as num?)?.toInt()
        : null;
    final hasVoted = userVoteIndex != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            post.pollData?['question'] ?? 'Poll',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          ...List.generate(options.length, (index) {
            final voteCount = index < votes.length ? votes[index] : 0;
            final percentage = totalVotes == 0 ? 0.0 : (voteCount / totalVotes);
            final isSelected = userVoteIndex == index;

            return GestureDetector(
              onTap: () {
                if (!hasVoted) {
                  repo.votePoll(post.id, index);
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                height: 40,
                child: Stack(
                  children: [
                    // Background
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50], // Very light grey base
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? Colors.blue : Colors.grey[300]!,
                        ),
                      ),
                    ),
                    // Progress Bar
                    if (hasVoted)
                      FractionallySizedBox(
                        widthFactor: percentage,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    // Content
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              options[index],
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Colors.blue
                                    : Colors.black87,
                              ),
                            ),
                          ),
                          if (hasVoted) ...[
                            Text(
                              '${(percentage * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.check_circle,
                              color: Colors.blue,
                              size: 18,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              '$totalVotes votes${hasVoted ? '' : ' • Tap to vote'}',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
