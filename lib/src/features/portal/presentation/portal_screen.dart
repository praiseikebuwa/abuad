import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PortalScreen extends ConsumerWidget {
  const PortalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Portal'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Theme.of(context).primaryColor,
                      child: const Icon(
                        Icons.person,
                        size: 30,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome Back!',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Student ID: 20230001',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Quick Stats
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    icon: Icons.grade,
                    title: 'CGPA',
                    value: '3.85',
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    icon: Icons.book,
                    title: 'Courses',
                    value: '6',
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Portal Features
            const Text(
              'Academic Tools',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            _buildFeatureCard(
              context,
              icon: Icons.calendar_today,
              title: 'Timetable',
              subtitle: 'View your class schedule',
              color: Colors.purple,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TimetableScreen(),
                  ),
                );
              },
            ),
            _buildFeatureCard(
              context,
              icon: Icons.calculate,
              title: 'GPA Calculator',
              subtitle: 'Calculate your semester GPA',
              color: Colors.orange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GPACalculatorScreen(),
                  ),
                );
              },
            ),
            _buildFeatureCard(
              context,
              icon: Icons.assessment,
              title: 'Results',
              subtitle: 'Check your exam results',
              color: Colors.teal,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ResultsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

// Timetable Screen
class TimetableScreen extends StatelessWidget {
  const TimetableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
    final schedule = {
      'Monday': [
        {'time': '8:00 AM', 'course': 'CSC 301', 'venue': 'LT1'},
        {'time': '10:00 AM', 'course': 'MTH 201', 'venue': 'LT2'},
      ],
      'Tuesday': [
        {'time': '9:00 AM', 'course': 'PHY 202', 'venue': 'Lab 1'},
      ],
      'Wednesday': [
        {'time': '8:00 AM', 'course': 'CSC 305', 'venue': 'LT1'},
        {'time': '12:00 PM', 'course': 'ENG 201', 'venue': 'LT3'},
      ],
      'Thursday': [
        {'time': '10:00 AM', 'course': 'CSC 307', 'venue': 'Lab 2'},
      ],
      'Friday': [
        {'time': '8:00 AM', 'course': 'MTH 203', 'venue': 'LT2'},
      ],
    };

    return Scaffold(
      appBar: AppBar(title: const Text('My Timetable')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
          final classes = schedule[day] ?? [];

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ExpansionTile(
              title: Text(
                day,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('${classes.length} classes'),
              children: classes.map((classInfo) {
                return ListTile(
                  leading: const Icon(Icons.access_time),
                  title: Text(classInfo['course']!),
                  subtitle: Text(
                    '${classInfo['time']} - ${classInfo['venue']}',
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

// GPA Calculator Screen
class GPACalculatorScreen extends StatefulWidget {
  const GPACalculatorScreen({super.key});

  @override
  State<GPACalculatorScreen> createState() => _GPACalculatorScreenState();
}

class _GPACalculatorScreenState extends State<GPACalculatorScreen> {
  final List<Map<String, dynamic>> _courses = [];
  double _gpa = 0.0;

  void _addCourse() {
    setState(() {
      _courses.add({'name': '', 'units': 3, 'grade': 'A'});
    });
  }

  void _calculateGPA() {
    if (_courses.isEmpty) return;

    final gradePoints = {
      'A': 5.0,
      'B': 4.0,
      'C': 3.0,
      'D': 2.0,
      'E': 1.0,
      'F': 0.0,
    };
    double totalPoints = 0;
    int totalUnits = 0;

    for (var course in _courses) {
      final units = course['units'] as int;
      final grade = course['grade'] as String;
      totalPoints += (gradePoints[grade] ?? 0) * units;
      totalUnits += units;
    }

    setState(() {
      _gpa = totalUnits > 0 ? totalPoints / totalUnits : 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GPA Calculator')),
      body: Column(
        children: [
          if (_gpa > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Column(
                children: [
                  const Text('Your GPA', style: TextStyle(fontSize: 16)),
                  Text(
                    _gpa.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _courses.length,
              itemBuilder: (context, index) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(flex: 2, child: Text('Course ${index + 1}')),
                        Expanded(
                          child: DropdownButton<int>(
                            value: _courses[index]['units'],
                            items: [1, 2, 3, 4, 5, 6].map((units) {
                              return DropdownMenuItem(
                                value: units,
                                child: Text('$units U'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _courses[index]['units'] = value!;
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: DropdownButton<String>(
                            value: _courses[index]['grade'],
                            items: ['A', 'B', 'C', 'D', 'E', 'F'].map((grade) {
                              return DropdownMenuItem(
                                value: grade,
                                child: Text(grade),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _courses[index]['grade'] = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'add',
            onPressed: _addCourse,
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'calc',
            onPressed: _calculateGPA,
            label: const Text('Calculate'),
            icon: const Icon(Icons.calculate),
          ),
        ],
      ),
    );
  }
}

// Results Screen
class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final results = [
      {
        'semester': '2023/2024 First Semester',
        'gpa': '3.92',
        'status': 'Excellent',
      },
      {
        'semester': '2022/2023 Second Semester',
        'gpa': '3.78',
        'status': 'Very Good',
      },
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('My Results')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: results.length,
        itemBuilder: (context, index) {
          final result = results[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green,
                child: Text(
                  result['gpa']!,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              title: Text(result['semester']!),
              subtitle: Text(result['status']!),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // Show detailed results
              },
            ),
          );
        },
      ),
    );
  }
}
