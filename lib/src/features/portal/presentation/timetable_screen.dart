import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../data/academic_repository.dart';

class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key});

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _days.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showAddClassDialog({Map<String, dynamic>? existingClass}) {
    final isEditing = existingClass != null;
    final courseController = TextEditingController(text: existingClass?['course'] ?? '');
    final venueController = TextEditingController(text: existingClass?['venue'] ?? '');
    final timeController = TextEditingController(text: existingClass?['time'] ?? '08:00 - 10:00');
    final lecturerController = TextEditingController(text: existingClass?['lecturer'] ?? '');
    String selectedDay = existingClass?['day'] ?? _days[_tabController.index];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            isEditing ? 'Edit Class Schedule' : 'Add New Class',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedDay,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Day of Week',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  items: _days
                      .map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(color: Colors.white))))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedDay = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: courseController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Course Code & Name',
                    hintText: 'e.g. CSC 301 - Software Engineering',
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: timeController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Time Range',
                    hintText: 'e.g. 08:00 - 10:00',
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: venueController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Lecture Hall / Venue',
                    hintText: 'e.g. LT 1, Engineering Lab A, TDC Hall',
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lecturerController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Lecturer / Instructor (Optional)',
                    hintText: 'e.g. Dr. Adewale',
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondaryTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final course = courseController.text.trim();
                final venue = venueController.text.trim();
                final time = timeController.text.trim();
                final lecturer = lecturerController.text.trim();

                if (course.isEmpty) return;

                final repo = ref.read(academicRepositoryProvider);
                if (isEditing) {
                  await repo.updateTimetableClass({
                    ...existingClass,
                    'day': selectedDay,
                    'course': course,
                    'venue': venue.isNotEmpty ? venue : 'Main Campus',
                    'time': time.isNotEmpty ? time : 'TBA',
                    'lecturer': lecturer,
                  });
                } else {
                  await repo.addTimetableClass({
                    'day': selectedDay,
                    'course': course,
                    'venue': venue.isNotEmpty ? venue : 'Main Campus',
                    'time': time.isNotEmpty ? time : 'TBA',
                    'lecturer': lecturer,
                  });
                }

                if (ctx.mounted) Navigator.pop(ctx);
                HapticFeedback.lightImpact();
              },
              child: Text(isEditing ? 'Save Changes' : 'Add Class'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteClass(String id, String course) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Class?', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to remove "$course" from your timetable?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(academicRepositoryProvider).deleteTimetableClass(id);
              HapticFeedback.mediumImpact();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timetableAsync = ref.watch(timetableStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'My Timetable',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore_page_rounded),
            tooltip: 'Reset to Official Template',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1E293B),
                  title: const Text('Reset Timetable?', style: TextStyle(color: Colors.white)),
                  content: const Text(
                    'This will reload the official ABUAD department semester courses.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondaryTeal),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Reset', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(academicRepositoryProvider).resetTimetableToDefaults();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Course',
            onPressed: () => _showAddClassDialog(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(
            children: [
              // Search input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search course code, title, hall, or lecturer...',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 18, color: Colors.white54),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16, color: Colors.white54),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey[200],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.secondaryTeal,
                indicatorWeight: 3,
                labelColor: AppColors.secondaryTeal,
                unselectedLabelColor: Colors.grey,
                labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: _days.map((day) => Tab(text: day.substring(0, 3).toUpperCase())).toList(),
              ),
            ],
          ),
        ),
      ),
      body: timetableAsync.when(
        data: (allClasses) {
          return TabBarView(
            controller: _tabController,
            children: _days.map((day) {
              final dayClasses = allClasses.where((c) {
                final matchDay = (c['day'] as String? ?? '').toLowerCase() == day.toLowerCase();
                if (!matchDay) return false;
                if (_searchQuery.isEmpty) return true;
                final course = (c['course'] as String? ?? '').toLowerCase();
                final venue = (c['venue'] as String? ?? '').toLowerCase();
                final lecturer = (c['lecturer'] as String? ?? '').toLowerCase();
                return course.contains(_searchQuery) || venue.contains(_searchQuery) || lecturer.contains(_searchQuery);
              }).toList();

              if (dayClasses.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy_rounded, size: 56, color: Colors.grey.withValues(alpha: 0.4)),
                      const SizedBox(height: 14),
                      Text(
                        _searchQuery.isNotEmpty ? 'No classes matching "$_searchQuery"' : 'No classes scheduled for $day',
                        style: GoogleFonts.inter(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondaryTeal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: Text('Add $day Class'),
                        onPressed: () => _showAddClassDialog(),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: dayClasses.length,
                itemBuilder: (context, index) {
                  final c = dayClasses[index];
                  final id = c['id']?.toString() ?? '';
                  final time = c['time']?.toString() ?? 'TBA';
                  final course = c['course']?.toString() ?? 'Course';
                  final venue = c['venue']?.toString() ?? 'Hall';
                  final lecturer = c['lecturer']?.toString() ?? '';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Time Badge
                          Container(
                            width: 82,
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryTeal.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.secondaryTeal.withValues(alpha: 0.25)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.access_time_rounded, size: 14, color: AppColors.secondaryTeal),
                                const SizedBox(height: 4),
                                Text(
                                  time,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.robotoMono(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10.5,
                                    color: AppColors.secondaryTeal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Course Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  course,
                                  style: GoogleFonts.outfit(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        venue,
                                        style: TextStyle(color: Colors.grey[400], fontSize: 12.5),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (lecturer.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.person_outline_rounded, size: 14, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          lecturer,
                                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Actions
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                            color: const Color(0xFF1E293B),
                            onSelected: (val) {
                              if (val == 'edit') {
                                _showAddClassDialog(existingClass: c);
                              } else if (val == 'delete') {
                                _confirmDeleteClass(id, course);
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, color: Colors.white70, size: 18),
                                    SizedBox(width: 10),
                                    Text('Edit Class', style: TextStyle(color: Colors.white)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                    SizedBox(width: 10),
                                    Text('Delete', style: TextStyle(color: Colors.redAccent)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading timetable: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.secondaryTeal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Course'),
        onPressed: () => _showAddClassDialog(),
      ),
    );
  }
}
