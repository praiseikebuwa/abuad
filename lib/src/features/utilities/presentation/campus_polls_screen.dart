import 'package:flutter/material.dart';

class CampusPollsScreen extends StatefulWidget {
  const CampusPollsScreen({super.key});

  @override
  State<CampusPollsScreen> createState() => _CampusPollsScreenState();
}

class _CampusPollsScreenState extends State<CampusPollsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _newQuestionCtrl = TextEditingController();
  final List<TextEditingController> _optionCtrls = [
    TextEditingController(text: 'Strongly Agree'),
    TextEditingController(text: 'Strongly Disagree'),
  ];

  final List<Map<String, dynamic>> _polls = [
    {
      'id': 'p1',
      'category': 'Hall Debates',
      'hall': 'Bello Hall vs Queen Hall',
      'question': 'Should curfew hours for hostel visitation during final exam weeks be extended to 10:00 PM?',
      'author': 'SRC Parliamentary Council',
      'timeAgo': '2 hours ago',
      'totalVotes': 642,
      'hasVoted': true,
      'userVotedIndex': 0,
      'options': [
        {'title': 'Yes, extend to 10 PM for group studies', 'votes': 488},
        {'title': 'No, maintain 8 PM for safety & quiet', 'votes': 154},
      ],
      'commentsCount': 89,
    },
    {
      'id': 'p2',
      'category': 'Campus Life',
      'hall': 'All Colleges',
      'question': 'Which cafeteria serves the best Jollof Rice on campus this semester?',
      'author': 'Foodies Society ABUAD',
      'timeAgo': '5 hours ago',
      'totalVotes': 1024,
      'hasVoted': false,
      'userVotedIndex': -1,
      'options': [
        {'title': 'Talent Cafeteria (College of Law)', 'votes': 410},
        {'title': 'Royal Cafeteria (Engineering)', 'votes': 320},
        {'title': 'Silver Spoon (MHS)', 'votes': 184},
        {'title': 'White House Diner', 'votes': 110},
      ],
      'commentsCount': 142,
    },
    {
      'id': 'p3',
      'category': 'Academics',
      'hall': 'Sciences & Engineering',
      'question': 'Would you prefer all continuous assessment (CA) quizzes to be strictly CBT format rather than written scripts?',
      'author': 'ABUAD Tech Students Union',
      'timeAgo': '1 day ago',
      'totalVotes': 812,
      'hasVoted': true,
      'userVotedIndex': 0,
      'options': [
        {'title': 'Strictly CBT (Instant scoring & fair)', 'votes': 580},
        {'title': 'Written scripts (Partial credit counts)', 'votes': 232},
      ],
      'commentsCount': 67,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _newQuestionCtrl.dispose();
    for (var ctrl in _optionCtrls) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _vote(int pollIndex, int optionIndex) {
    bool isChanged = false;
    setState(() {
      final poll = _polls[pollIndex];
      final prevVoteIndex = poll['userVotedIndex'] as int? ?? -1;
      if (poll['hasVoted'] == true) {
        if (prevVoteIndex == optionIndex) return;
        isChanged = true;
        if (prevVoteIndex >= 0 && prevVoteIndex < (poll['options'] as List).length) {
          final oldVotes = poll['options'][prevVoteIndex]['votes'] as int;
          poll['options'][prevVoteIndex]['votes'] = (oldVotes - 1).clamp(0, 999999);
        }
        poll['options'][optionIndex]['votes'] = (poll['options'][optionIndex]['votes'] as int) + 1;
        poll['userVotedIndex'] = optionIndex;
      } else {
        poll['hasVoted'] = true;
        poll['userVotedIndex'] = optionIndex;
        poll['options'][optionIndex]['votes'] = (poll['options'][optionIndex]['votes'] as int) + 1;
        poll['totalVotes'] = (poll['totalVotes'] as int) + 1;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isChanged ? 'Vote changed! Real-time tally updated.' : 'Vote recorded! Real-time tally updated.'),
      ),
    );
  }

  void _openCreatePollModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: isDark ? Colors.black : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Launch Campus Poll / Hall Debate',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ask a question to your hall, college, or whole university.',
                      style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _newQuestionCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'What is your debate or question topic?',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Poll Options',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(_optionCtrls.length, (idx) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _optionCtrls[idx],
                                decoration: InputDecoration(
                                  hintText: 'Option ${idx + 1}',
                                  prefixIcon: Icon(Icons.radio_button_unchecked, size: 18, color: Colors.indigoAccent),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  isDense: true,
                                ),
                              ),
                            ),
                            if (_optionCtrls.length > 2)
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                                onPressed: () {
                                  setModalState(() {
                                    _optionCtrls.removeAt(idx);
                                  });
                                },
                              ),
                          ],
                        ),
                      );
                    }),
                    if (_optionCtrls.length < 5)
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Another Option'),
                        onPressed: () {
                          setModalState(() {
                            _optionCtrls.add(TextEditingController());
                          });
                        },
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigoAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          if (_newQuestionCtrl.text.trim().isEmpty) return;
                          setState(() {
                            _polls.insert(0, {
                              'id': 'p_${DateTime.now().millisecondsSinceEpoch}',
                              'category': 'Hall Debates',
                              'hall': 'Campus Wide',
                              'question': _newQuestionCtrl.text.trim(),
                              'author': 'You',
                              'timeAgo': 'Just now',
                              'totalVotes': 0,
                              'hasVoted': false,
                              'userVotedIndex': -1,
                              'options': _optionCtrls
                                  .where((c) => c.text.trim().isNotEmpty)
                                  .map((c) => {'title': c.text.trim(), 'votes': 0})
                                  .toList(),
                              'commentsCount': 0,
                            });
                          });
                          _newQuestionCtrl.clear();
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Poll published to campus!')),
                          );
                        },
                        child: const Text('Publish Poll', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.how_to_vote_rounded, color: Colors.indigoAccent),
            SizedBox(width: 8),
            Text('Campus Polls & Debates'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Create Poll',
            onPressed: _openCreatePollModal,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.indigoAccent,
          indicatorColor: Colors.indigoAccent,
          tabs: const [
            Tab(text: 'Trending Debates'),
            Tab(text: 'Hostel Clashes'),
            Tab(text: 'Academics'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPollsList(_polls),
          _buildPollsList(_polls.where((p) => p['category'] == 'Hall Debates').toList()),
          _buildPollsList(_polls.where((p) => p['category'] == 'Academics').toList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreatePollModal,
        backgroundColor: Colors.indigoAccent,
        icon: const Icon(Icons.how_to_vote, color: Colors.white),
        label: const Text('Start Poll', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildPollsList(List<Map<String, dynamic>> polls) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (polls.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.poll_outlined, size: 60, color: Colors.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            const Text('No polls in this category yet.', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: polls.length,
      itemBuilder: (context, idx) {
        final poll = polls[idx];
        final totalVotes = poll['totalVotes'] as int;
        final hasVoted = poll['hasVoted'] as bool;
        final userVotedIdx = poll['userVotedIndex'] as int;
        final options = poll['options'] as List;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111827) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black45 : Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.indigoAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        poll['hall'],
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigoAccent),
                      ),
                    ),
                    Text(
                      poll['timeAgo'],
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  poll['question'],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 14),
                ...List.generate(options.length, (optIdx) {
                  final opt = options[optIdx];
                  final votes = opt['votes'] as int;
                  final percentage = totalVotes > 0 ? (votes / totalVotes) : 0.0;
                  final isSelected = hasVoted && userVotedIdx == optIdx;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: InkWell(
                      onTap: () {
                        final realIdx = _polls.indexWhere((p) => p['id'] == poll['id']);
                        if (realIdx != -1) _vote(realIdx, optIdx);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          Container(
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: isSelected
                                  ? Colors.indigoAccent.withValues(alpha: isDark ? 0.22 : 0.12)
                                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.indigoAccent
                                    : (isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0)),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                          ),
                          if (hasVoted)
                            FractionallySizedBox(
                              widthFactor: percentage,
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: isSelected
                                      ? Colors.indigoAccent.withValues(alpha: 0.35)
                                      : Colors.indigoAccent.withValues(alpha: 0.15),
                                ),
                              ),
                            ),
                          Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.check_circle_rounded
                                      : (hasVoted ? Icons.radio_button_unchecked : Icons.radio_button_off),
                                  size: 18,
                                  color: isSelected ? Colors.indigoAccent : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    opt['title'],
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (hasVoted)
                                  Text(
                                    '${(percentage * 100).toStringAsFixed(1)}% ($votes)',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.people_outline, size: 16, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '$totalVotes student votes',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                    const Spacer(),
                    Icon(Icons.chat_bubble_outline_rounded, size: 16, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${poll['commentsCount']} comments',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
