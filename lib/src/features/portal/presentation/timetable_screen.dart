import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class TimetableScreen extends StatelessWidget {
  const TimetableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Timetable'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'MON'),
              Tab(text: 'TUE'),
              Tab(text: 'WED'),
              Tab(text: 'THU'),
              Tab(text: 'FRI'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildDayList(context, 'Monday'),
            _buildDayList(context, 'Tuesday'),
            _buildDayList(context, 'Wednesday'),
            _buildDayList(context, 'Thursday'),
            _buildDayList(context, 'Friday'),
          ],
        ),
      ),
    );
  }

  Widget _buildDayList(BuildContext context, String day) {
    // Demo data for now
    final classes = _getDemoClasses(day);

    if (classes.isEmpty) {
      return const Center(child: Text('No classes scheduled for this day'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: classes.length,
      itemBuilder: (context, index) {
        final c = classes[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 80,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryTeal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        c['time']!,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondaryTeal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c['course']!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            c['venue']!,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Map<String, String>> _getDemoClasses(String day) {
    switch (day) {
      case 'Monday':
        return [
          {
            'time': '08:00',
            'course': 'CSC 301 - Software Engineering',
            'venue': 'LT 1',
          },
          {
            'time': '10:00',
            'course': 'CSC 303 - Database Systems',
            'venue': 'LT 2',
          },
          {
            'time': '14:00',
            'course': 'GST 311 - Entrepreneurship',
            'venue': 'Main Hall',
          },
        ];
      case 'Tuesday':
        return [
          {
            'time': '09:00',
            'course': 'CSC 305 - Operating Systems',
            'venue': 'Lab A',
          },
          {
            'time': '11:00',
            'course': 'MAT 301 - Linear Algebra',
            'venue': 'LT 4',
          },
        ];
      case 'Wednesday':
        return [
          {
            'time': '08:00',
            'course': 'CSC 301 - Software Engineering',
            'venue': 'LT 1',
          },
          {'time': '12:00', 'course': 'CSC 307 - Web Tech', 'venue': 'Lab B'},
        ];
      case 'Thursday':
        return [
          {
            'time': '10:00',
            'course': 'CSC 303 - Database Systems',
            'venue': 'LT 2',
          },
          {'time': '14:00', 'course': 'CSC 309 - AI Intro', 'venue': 'LT 5'},
        ];
      case 'Friday':
        return [
          {
            'time': '09:00',
            'course': 'MAT 301 - Linear Algebra',
            'venue': 'LT 4',
          },
          {'time': '15:00', 'course': 'Sports & Recreation', 'venue': 'Pitch'},
        ];
      default:
        return [];
    }
  }
}
