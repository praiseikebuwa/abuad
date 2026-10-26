import 'package:flutter/material.dart';

class SportsCenterScreen extends StatefulWidget {
  const SportsCenterScreen({super.key});

  @override
  State<SportsCenterScreen> createState() => _SportsCenterScreenState();
}

class _SportsCenterScreenState extends State<SportsCenterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _liveMatches = [
    {
      'tournament': 'VC Cup Football 2026 - Quarter Final',
      'minute': '74\'',
      'isLive': true,
      'teamA': 'College of Engineering (COENG)',
      'teamB': 'College of Law (LAW)',
      'scoreA': 2,
      'scoreB': 1,
      'scorers': 'Eng: Babatunde 23\', Emeka 68\' | Law: Femi 41\' (Pen)',
      'venue': 'ABUAD Sports Complex Main Bowl',
    },
    {
      'tournament': 'Inter-Hall Basketball Championship',
      'minute': 'Q3 - 04:12',
      'isLive': true,
      'teamA': 'Bello Hall Titans',
      'teamB': 'Wema Hall Kings',
      'scoreA': 58,
      'scoreB': 54,
      'scorers': 'Top scorer: David (Titans) 22 pts',
      'venue': 'Indoor Basketball Arena',
    },
  ];

  final List<Map<String, dynamic>> _fixtures = [
    {
      'date': 'Tomorrow, 4:00 PM',
      'tournament': 'VC Cup Semi-Final 1',
      'teamA': 'College of MHS',
      'teamB': 'Sciences & Computing',
      'venue': 'Main Stadium Field 1',
    },
    {
      'date': 'Saturday, 3:30 PM',
      'tournament': 'Female Volleyball Cup',
      'teamA': 'Queen Hall Sparks',
      'teamB': 'Silver Hall Queens',
      'venue': 'Outdoor Volleyball Court',
    },
    {
      'date': 'Sunday, 5:00 PM',
      'tournament': 'VC Cup Semi-Final 2',
      'teamA': 'COENG',
      'teamB': 'Winner of MHS/SMS',
      'venue': 'Main Stadium Field 1',
    },
  ];

  final List<Map<String, dynamic>> _standings = [
    {'pos': 1, 'team': 'Engineering (COENG)', 'p': 4, 'w': 3, 'd': 1, 'l': 0, 'pts': 10, 'gd': '+6'},
    {'pos': 2, 'team': 'Computing & Sciences', 'p': 4, 'w': 3, 'd': 0, 'l': 1, 'pts': 9, 'gd': '+4'},
    {'pos': 3, 'team': 'College of Law', 'p': 4, 'w': 2, 'd': 1, 'l': 1, 'pts': 7, 'gd': '+2'},
    {'pos': 4, 'team': 'Medicine & Health (MHS)', 'p': 4, 'w': 2, 'd': 0, 'l': 2, 'pts': 6, 'gd': '0'},
    {'pos': 5, 'team': 'Social & Mgmt Sciences', 'p': 4, 'w': 1, 'd': 0, 'l': 3, 'pts': 3, 'gd': '-4'},
    {'pos': 6, 'team': 'College of Pharmacy', 'p': 4, 'w': 0, 'd': 0, 'l': 4, 'pts': 0, 'gd': '-8'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.sports_soccer_rounded, color: Colors.greenAccent),
            SizedBox(width: 8),
            Text('ABUAD Sports & VC Cup'),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.greenAccent,
          indicatorColor: Colors.greenAccent,
          tabs: const [
            Tab(text: 'Live Scores'),
            Tab(text: 'Fixtures'),
            Tab(text: 'Table Standings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLiveTab(isDark),
          _buildFixturesTab(isDark),
          _buildStandingsTab(isDark),
        ],
      ),
    );
  }

  Widget _buildLiveTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade800, Colors.teal.shade900],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            children: [
              Icon(Icons.sensors, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Live real-time match reporting from ABUAD Sports Complex.',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ..._liveMatches.map((m) {
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 3,
            color: isDark ? Colors.black : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        m['tournament'],
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.greenAccent.shade700),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.redAccent, width: 1),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.redAccent),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              m['minute'],
                              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          m['teamA'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black45 : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${m['scoreA']} - ${m['scoreB']}',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          m['teamB'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    m['scorers'],
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        m['venue'],
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFixturesTab(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _fixtures.length,
      itemBuilder: (context, idx) {
        final fix = _fixtures[idx];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          color: isDark ? Colors.black : Colors.white,
          child: ListTile(
            contentPadding: const EdgeInsets.all(14),
            leading: CircleAvatar(
              backgroundColor: Colors.greenAccent.withValues(alpha: 0.15),
              child: const Icon(Icons.event, color: Colors.greenAccent),
            ),
            title: Text('${fix['teamA']} vs ${fix['teamB']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(fix['tournament'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                Text('${fix['date']} • ${fix['venue']}', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])),
              ],
            ),
            trailing: OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Reminder set for ${fix['teamA']} vs ${fix['teamB']}!')),
                );
              },
              child: const Text('Remind', style: TextStyle(fontSize: 12)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStandingsTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: isDark ? Colors.black : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'VC Cup 2026 Inter-College Football League',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Divider(),
                Table(
                  columnWidths: const {
                    0: FixedColumnWidth(30),
                    1: FlexColumnWidth(),
                    2: FixedColumnWidth(28),
                    3: FixedColumnWidth(28),
                    4: FixedColumnWidth(28),
                    5: FixedColumnWidth(32),
                    6: FixedColumnWidth(34),
                  },
                  children: [
                    TableRow(
                      children: [
                        const Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const Text('College', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const Text('P', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const Text('W', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const Text('D', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const Text('GD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const Text('PTS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.greenAccent)),
                      ],
                    ),
                    const TableRow(
                      children: [SizedBox(height: 8), SizedBox(height: 8), SizedBox(height: 8), SizedBox(height: 8), SizedBox(height: 8), SizedBox(height: 8), SizedBox(height: 8)],
                    ),
                    ..._standings.map((s) {
                      return TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text('${s['pos']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(s['team'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text('${s['p']}', style: const TextStyle(fontSize: 12)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text('${s['w']}', style: const TextStyle(fontSize: 12)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text('${s['d']}', style: const TextStyle(fontSize: 12)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text('${s['gd']}', style: const TextStyle(fontSize: 12)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text('${s['pts']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.greenAccent)),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
