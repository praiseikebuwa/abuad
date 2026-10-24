import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'gpa_calculator_screen.dart';
import 'timetable_screen.dart';
import 'student_id_screen.dart';
import '../data/academic_repository.dart';
import '../../user/data/user_repository.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

class PortalScreen extends ConsumerWidget {
  const PortalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;
    final displayName = user?.displayName.isNotEmpty == true ? user!.displayName : 'Student';
    final matricNumber = user != null && user.uid.length >= 6
        ? '21/ENG02/${user.uid.substring(user.uid.length - 4)}'
        : 'Student ID: 20230001';

    return Scaffold(
      appBar: AppBar(title: const Text('Student Portal'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StudentIdScreen()),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                        backgroundImage: user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty
                            ? CachedNetworkImageProvider(user.avatarUrl!)
                            : null,
                        child: user?.avatarUrl == null || user!.avatarUrl!.isEmpty
                            ? Icon(Icons.person, size: 28, color: Theme.of(context).primaryColor)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              matricNumber,
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.badge_outlined, color: Colors.teal),
                    ],
                  ),
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
              icon: Icons.badge_rounded,
              title: 'Digital Student ID',
              subtitle: 'Smart student card & barcode',
              color: Colors.teal,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const StudentIdScreen(),
                  ),
                );
              },
            ),
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
            const SizedBox(height: 24),
            const Text(
              'Your Results',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ref
                .watch(resultsStreamProvider)
                .when(
                  data: (results) {
                    if (results.isEmpty) {
                      return const Center(child: Text('No results saved yet'));
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final result = results[index];
                        return _buildResultCard(context, ref, result);
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Text('Error: $e'),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> result,
  ) {
    final gpa = result['gpa'] as double;
    final semester = result['semester'] as String;
    final timestamp =
        result['timestamp'] as dynamic; // Can be Timestamp or null

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: gpa >= 4.5
              ? Colors.green
              : (gpa >= 3.5 ? Colors.blue : Colors.orange),
          child: Text(
            gpa.toStringAsFixed(1),
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        title: Text(
          semester,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          timestamp != null ? timeago.format(timestamp.toDate()) : 'Recently',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
          onPressed: () =>
              ref.read(academicRepositoryProvider).deleteResult(result['id']),
        ),
        onTap: () {
          // Show details if needed
        },
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
            color: color.withValues(alpha: 0.1),
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
