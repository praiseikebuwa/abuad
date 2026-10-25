import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/theme/app_colors.dart';
import '../../user/data/user_repository.dart';
import '../data/academic_repository.dart';
import 'abuad_portal_webview_screen.dart';
import 'student_id_screen.dart';
import 'timetable_screen.dart';
import 'exam_countdown_screen.dart';
import 'gpa_calculator_screen.dart';
import 'cgpa_simulator_screen.dart';
import 'attendance_tracker_screen.dart';
import 'cbt_practice_screen.dart';

class PortalScreen extends ConsumerWidget {
  const PortalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;
    final displayName = user?.displayName.isNotEmpty == true ? user!.displayName : 'Student';
    final matricNumber = user != null && user.uid.length >= 6
        ? '21/ENG02/${user.uid.substring(user.uid.length - 4)}'
        : '21/ENG02/089';

    final resultsAsync = ref.watch(resultsStreamProvider);
    final timetableAsync = ref.watch(timetableStreamProvider);

    final results = resultsAsync.value ?? [];
    double calculatedCgpa = 4.0;
    if (results.isNotEmpty) {
      double totalQuality = 0;
      int totalUnits = 0;
      final gradeMap = {'A': 5.0, 'B': 4.0, 'C': 3.0, 'D': 2.0, 'E': 1.0, 'F': 0.0};
      for (final r in results) {
        final courses = r['courses'] as List<dynamic>? ?? [];
        for (final c in courses) {
          final u = (c['units'] as num?)?.toInt() ?? 3;
          final g = (c['grade'] as String?)?.toUpperCase() ?? 'A';
          totalQuality += (gradeMap[g] ?? 4.0) * u;
          totalUnits += u;
        }
      }
      calculatedCgpa = totalUnits > 0 ? (totalQuality / totalUnits) : (results.first['gpa'] as num).toDouble();
    }

    final coursesCount = timetableAsync.value?.length ?? 6;

    return Scaffold(
      appBar: AppBar(
        title: Text('Student Academic Portal', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student Profile Welcome Card
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
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: AppColors.secondaryTeal.withValues(alpha: 0.15),
                        backgroundImage: user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty
                            ? CachedNetworkImageProvider(user.avatarUrl!)
                            : null,
                        child: user?.avatarUrl == null || user!.avatarUrl!.isEmpty
                            ? const Icon(Icons.person, size: 26, color: AppColors.secondaryTeal)
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: GoogleFonts.outfit(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              matricNumber,
                              style: GoogleFonts.robotoMono(color: Colors.grey[400], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.badge_outlined, color: AppColors.secondaryTeal),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Hero: ABUAD Integrated e-Portal Card
            _buildOfficialPortalCard(context),
            const SizedBox(height: 20),

            // Quick Academic Stats
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    icon: Icons.grade_rounded,
                    title: 'Current CGPA',
                    value: calculatedCgpa.toStringAsFixed(2),
                    color: calculatedCgpa >= 4.5 ? Colors.amber : (calculatedCgpa >= 3.5 ? Colors.green : Colors.blue),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    icon: Icons.auto_stories_rounded,
                    title: 'Active Courses',
                    value: coursesCount.toString(),
                    color: Colors.purpleAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Academic Tools Section
            Text(
              'Academic Utilities & Services',
              style: GoogleFonts.outfit(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            _buildFeatureCard(
              context,
              icon: Icons.language_rounded,
              title: 'ABUAD Integrated e-Portal',
              subtitle: 'Official webview with 1-tap auto sign-in',
              color: const Color(0xFF0284C7),
              badge: 'LIVE',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AbuadPortalWebViewScreen()),
                );
              },
            ),
            _buildFeatureCard(
              context,
              icon: Icons.badge_rounded,
              title: 'Digital Student ID',
              subtitle: 'Verified card, barcode & QR profile',
              color: AppColors.secondaryTeal,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StudentIdScreen()),
                );
              },
            ),
            _buildFeatureCard(
              context,
              icon: Icons.calendar_month_rounded,
              title: 'Class Timetable',
              subtitle: 'Weekly lecture schedule & venues',
              color: const Color(0xFF8B5CF6),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TimetableScreen()),
                );
              },
            ),
            _buildFeatureCard(
              context,
              icon: Icons.timer_outlined,
              title: 'Exam Countdown & Pomodoro',
              subtitle: 'Assessment milestones & study planner',
              color: const Color(0xFFEF4444),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ExamCountdownScreen()),
                );
              },
            ),
            _buildFeatureCard(
              context,
              icon: Icons.calculate_rounded,
              title: 'GPA Calculator (ABUAD 5.0)',
              subtitle: 'Compute semester GPA & save records',
              color: const Color(0xFFF59E0B),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const GPACalculatorScreen()),
                );
              },
            ),
            _buildFeatureCard(
              context,
              icon: Icons.trending_up_rounded,
              title: 'CGPA Simulator & Honors',
              subtitle: 'Simulate required grades for First Class',
              color: const Color(0xFF10B981),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CgpaSimulatorScreen()),
                );
              },
            ),
            _buildFeatureCard(
              context,
              icon: Icons.fact_check_rounded,
              title: 'Attendance Tracker',
              subtitle: '70% exam clearance monitor & chapel records',
              color: const Color(0xFF06B6D4),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AttendanceTrackerScreen()),
                );
              },
            ),
            _buildFeatureCard(
              context,
              icon: Icons.quiz_rounded,
              title: 'CBT Practice Drills',
              subtitle: 'GST & university mock examination sets',
              color: const Color(0xFFEC4899),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CbtPracticeScreen()),
                );
              },
            ),

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Saved Semester Results',
                  style: GoogleFonts.outfit(fontSize: 19, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const GPACalculatorScreen()),
                    );
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Result'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            resultsAsync.when(
              data: (list) {
                if (list.isEmpty) {
                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.receipt_long_outlined, size: 40, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text('No semester records saved yet', style: GoogleFonts.inter(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final result = list[index];
                    return _buildResultCard(context, ref, result);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Text('Error: $e'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfficialPortalCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F2B33),
            Color(0xFF0B192C),
            Color(0xFF1E293B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondaryTeal.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: AppColors.secondaryTeal.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.school_rounded, color: AppColors.secondaryTeal, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Afe Babalola University',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Integrated e-Portal',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.greenAccent, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.bolt, color: Colors.greenAccent, size: 13),
                      SizedBox(width: 3),
                      Text(
                        'Auto-Sign In',
                        style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Connect directly to portal.abuad.edu.ng/PortalHome. Securely vaults your student matric & password for seamless 1-tap sign-in.',
              style: GoogleFonts.inter(color: Colors.white60, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondaryTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                    label: Text(
                      'Launch e-Portal (Auto Sign-In)',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AbuadPortalWebViewScreen()),
                      );
                    },
                  ),
                ),
              ],
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
    final gpa = (result['gpa'] as num).toDouble();
    final semester = result['semester']?.toString() ?? 'Semester';
    final timestamp = result['timestamp']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: gpa >= 4.5
              ? Colors.green
              : (gpa >= 3.5 ? AppColors.secondaryTeal : Colors.orange),
          child: Text(
            gpa.toStringAsFixed(2),
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          semester,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14.5),
        ),
        subtitle: Text(
          timestamp != null
              ? timeago.format(DateTime.tryParse(timestamp) ?? DateTime.now())
              : 'Recent',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
          onPressed: () => ref.read(academicRepositoryProvider).deleteResult(result['id']),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.robotoMono(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 11.5),
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
    String? badge,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }
}
