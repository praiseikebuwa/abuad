import 'package:flutter/material.dart';

class StudyLoungesScreen extends StatefulWidget {
  const StudyLoungesScreen({super.key});

  @override
  State<StudyLoungesScreen> createState() => _StudyLoungesScreenState();
}

class _StudyLoungesScreenState extends State<StudyLoungesScreen> {
  String? _activeLoungeId;
  bool _isMuted = true;
  bool _handRaised = false;

  final List<Map<String, dynamic>> _lounges = [
    {
      'id': 'l1',
      'title': 'GST 111 & 112 Exam Marathon Revision',
      'course': 'GST 111 / GST 112',
      'host': 'Demilade (Faculty President)',
      'listeners': 38,
      'speakers': 4,
      'isLive': true,
      'tags': ['Finals Prep', 'Past Questions', 'Open Mic'],
      'pinnedNote': 'Reviewing 2024 past questions from 8 PM - 10 PM. Download the PDF in the attachments!',
    },
    {
      'id': 'l2',
      'title': 'Engineering Math MTH 201 Differential Equations',
      'course': 'MTH 201 / ENG 201',
      'host': 'Emmanuel A.',
      'listeners': 19,
      'speakers': 3,
      'isLive': true,
      'tags': ['Engineering', 'Calculus', 'Problem Solving'],
      'pinnedNote': 'Solving question 4 from CA 2 right now.',
    },
    {
      'id': 'l3',
      'title': 'Quiet Pomodoro Co-Working Lounge (Lo-Fi Beats)',
      'course': 'All Courses',
      'host': 'ABUAD Study Guild',
      'listeners': 54,
      'speakers': 1,
      'isLive': true,
      'tags': ['Pomodoro', 'Silent Study', 'Deep Focus'],
      'pinnedNote': 'Interval: 50m focus / 10m break. Microphones muted for silent focus.',
    },
    {
      'id': 'l4',
      'title': 'College of Law: Criminal Law Moot & Case Studies',
      'course': 'LAW 205',
      'host': 'Chidinma O.',
      'listeners': 12,
      'speakers': 2,
      'isLive': false,
      'tags': ['Law', 'Case Law', 'Moot Court'],
      'pinnedNote': 'Scheduled for tonight at 9:00 PM.',
    },
  ];

  void _joinLounge(Map<String, dynamic> lounge) {
    setState(() {
      _activeLoungeId = lounge['id'];
      _isMuted = true;
      _handRaised = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Joined "${lounge['title']}"'),
        action: SnackBarAction(
          label: 'Leave',
          textColor: Colors.redAccent,
          onPressed: () {
            setState(() {
              _activeLoungeId = null;
            });
          },
        ),
      ),
    );
  }

  void _createLoungeDialog() {
    final titleCtrl = TextEditingController();
    final courseCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Start an Audio Study Lounge'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Lounge Topic',
                  hintText: 'e.g., CHM 101 Organic Chemistry Breakdown',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: courseCtrl,
                decoration: const InputDecoration(
                  labelText: 'Course Code',
                  hintText: 'e.g., CHM 101',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, foregroundColor: Colors.white),
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) return;
                setState(() {
                  _lounges.insert(0, {
                    'id': 'l_${DateTime.now().millisecondsSinceEpoch}',
                    'title': titleCtrl.text.trim(),
                    'course': courseCtrl.text.trim().isEmpty ? 'General Study' : courseCtrl.text.trim(),
                    'host': 'You',
                    'listeners': 1,
                    'speakers': 1,
                    'isLive': true,
                    'tags': ['Student Created', 'Discussion'],
                    'pinnedNote': 'Welcome to the lounge! Feel free to unmute and ask questions.',
                  });
                  _activeLoungeId = _lounges[0]['id'];
                });
                Navigator.pop(ctx);
              },
              child: const Text('Start Room'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeLounge = _lounges.firstWhere((l) => l['id'] == _activeLoungeId, orElse: () => {});

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.record_voice_over_rounded, color: Colors.purpleAccent),
            SizedBox(width: 8),
            Text('Audio Study Lounges'),
          ],
        ),
      ),
      body: Column(
        children: [
          // If user is currently in a room, show active bottom sheet / banner
          if (_activeLoungeId != null && activeLounge.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade900, Colors.deepPurple.shade800],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.greenAccent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeLounge['title'] ?? '',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Host: ${activeLounge['host']} • ${activeLounge['listeners']} in room',
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(_isMuted ? Icons.mic_off : Icons.mic, color: _isMuted ? Colors.redAccent : Colors.white),
                    tooltip: _isMuted ? 'Unmute' : 'Mute',
                    onPressed: () {
                      setState(() {
                        _isMuted = !_isMuted;
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.back_hand, color: _handRaised ? Colors.amberAccent : Colors.white70),
                    tooltip: 'Raise Hand',
                    onPressed: () {
                      setState(() {
                        _handRaised = !_handRaised;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_handRaised ? 'Hand raised to speak' : 'Hand lowered'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    tooltip: 'Leave Room',
                    onPressed: () {
                      setState(() {
                        _activeLoungeId = null;
                      });
                    },
                  ),
                ],
              ),
            ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Live Campus Study Circles',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${_lounges.where((l) => l['isLive'] == true).length} active',
                      style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._lounges.map((lounge) {
                  final isCurrent = lounge['id'] == _activeLoungeId;
                  final isLive = lounge['isLive'] as bool;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isCurrent ? Colors.purpleAccent : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    color: isDark ? Colors.black : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isLive ? Colors.redAccent.withOpacity(0.15) : Colors.grey.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isLive ? Icons.radio_button_checked : Icons.schedule,
                                      size: 12,
                                      color: isLive ? Colors.redAccent : Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isLive ? 'LIVE' : 'UPCOMING',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isLive ? Colors.redAccent : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.purpleAccent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  lounge['course'],
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purpleAccent,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Icon(Icons.headset, size: 16, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                '${lounge['listeners']}',
                                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            lounge['title'],
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Host: ${lounge['host']}',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            children: (lounge['tags'] as List).map<Widget>((tag) {
                              return Chip(
                                label: Text(tag, style: const TextStyle(fontSize: 10)),
                                padding: EdgeInsets.zero,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black : Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.push_pin, size: 14, color: Colors.purpleAccent),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    lounge['pinnedNote'],
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isCurrent ? Colors.grey[800] : Colors.purpleAccent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                if (isCurrent) {
                                  setState(() => _activeLoungeId = null);
                                } else {
                                  _joinLounge(lounge);
                                }
                              },
                              icon: Icon(isCurrent ? Icons.exit_to_app : Icons.mic_none),
                              label: Text(
                                isCurrent ? 'Leave Lounge' : (isLive ? 'Join Audio Lounge' : 'Set Reminder'),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createLoungeDialog,
        backgroundColor: Colors.purpleAccent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Lounge', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
