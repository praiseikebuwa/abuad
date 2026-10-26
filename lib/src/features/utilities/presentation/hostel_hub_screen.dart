import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class HostelHubScreen extends StatefulWidget {
  const HostelHubScreen({super.key});

  @override
  State<HostelHubScreen> createState() => _HostelHubScreenState();
}

class _HostelHubScreenState extends State<HostelHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Maintenance tickets
  final List<_MaintenanceTicket> _tickets = [
    _MaintenanceTicket(
      id: '#TKT-2041',
      hall: 'Nelson Mandela Hall',
      room: 'B204',
      category: 'Plumbing',
      issue: 'Water pressure low and leaking sink drainage pipe.',
      status: 'Assigned',
      reportedTime: '2 hours ago',
      priority: 'High',
    ),
    _MaintenanceTicket(
      id: '#TKT-1988',
      hall: 'Wema Bank Hall',
      room: 'C108',
      category: 'Electrical',
      issue: 'Ceiling fan regulator sparking and not turning on.',
      status: 'Completed',
      reportedTime: 'Yesterday',
      priority: 'Urgent',
    ),
    _MaintenanceTicket(
      id: '#TKT-1940',
      hall: 'Afe Hall',
      room: 'A312',
      category: 'Carpentry',
      issue: 'Wardrobe door hinge detached from frame.',
      status: 'Pending',
      reportedTime: '3 days ago',
      priority: 'Normal',
    ),
  ];

  // Roommate profiles
  final List<_RoommateMatch> _roommates = [
    _RoommateMatch(
      name: 'Femi Oladipo',
      handle: 'femi_ola',
      level: '300 Level',
      college: 'College of Law',
      compatibility: 96,
      avatarInitials: 'FO',
      color: const Color(0xFF8B5CF6),
      sleepHabit: 'Night Owl (1 AM)',
      studyStyle: 'Silent Study in Room',
      cleanliness: 'Very Tidy & Organized',
      bio: 'Looking for a calm, studious roommate in Nelson Mandela or Talent Hall for next session.',
    ),
    _RoommateMatch(
      name: 'Chidi Okonkwo',
      handle: 'chidi_tech',
      level: '200 Level',
      college: 'Computer Science',
      compatibility: 89,
      avatarInitials: 'CO',
      color: const Color(0xFF3B82F6),
      sleepHabit: 'Early Riser (6 AM)',
      studyStyle: 'Library & TDC study',
      cleanliness: 'Moderate & Respectful',
      bio: 'Coder & gamer. Respectful of personal space and quiet study hours.',
    ),
    _RoommateMatch(
      name: 'Tobi Alabi',
      handle: 'tobi_mgt',
      level: '400 Level',
      college: 'Economics & Mgt',
      compatibility: 82,
      avatarInitials: 'TA',
      color: const Color(0xFF10B981),
      sleepHabit: 'Flexible Schedule',
      studyStyle: 'Group discussions',
      cleanliness: 'Always clean shared areas',
      bio: 'Finalist student looking for someone focused on graduating well.',
    ),
  ];

  // Report issue form controllers
  String _selectedHall = 'Nelson Mandela Hall';
  String _selectedCategory = 'Plumbing';
  final String _selectedPriority = 'Normal';
  final TextEditingController _roomNumberController = TextEditingController(text: 'B204');
  final TextEditingController _issueDescriptionController = TextEditingController();

  final List<String> _abuadHalls = [
    'Nelson Mandela Hall',
    'Wema Bank Hall',
    'Afe Hall',
    'Talent Discovery Hall',
    'Queen Mother Hall',
    'Prosperity Hall',
    'Postgraduate Hall',
    'Silver Hall',
  ];

  final List<String> _categories = [
    'Plumbing',
    'Electrical',
    'Carpentry',
    'AC & Refrigerator',
    'Painting / Wall',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _roomNumberController.dispose();
    _issueDescriptionController.dispose();
    super.dispose();
  }

  void _submitTicket() {
    final text = _issueDescriptionController.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _tickets.insert(
        0,
        _MaintenanceTicket(
          id: '#TKT-${2050 + _tickets.length}',
          hall: _selectedHall,
          room: _roomNumberController.text.trim(),
          category: _selectedCategory,
          issue: text,
          status: 'Pending',
          reportedTime: 'Just now',
          priority: _selectedPriority,
        ),
      );
      _issueDescriptionController.clear();
    });
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text('Maintenance ticket submitted to Hall Warden & Works!'),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _openReportSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Report Hostel Maintenance Issue',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Hall dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedHall,
                dropdownColor: const Color(0xFF0F172A),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Hostel Hall',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                items: _abuadHalls.map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
                onChanged: (val) => setModalState(() => _selectedHall = val!),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _roomNumberController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Room Number',
                        labelStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      dropdownColor: const Color(0xFF0F172A),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Category',
                        labelStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setModalState(() => _selectedCategory = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _issueDescriptionController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Describe the issue (e.g., tap won\'t close, socket burnt)...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 18),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Dispatch Ticket to Maintenance', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _submitTicket,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Hostel & Roommate Hub',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 19),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF8B5CF6),
          indicatorWeight: 3,
          labelColor: isDark ? Colors.white : Colors.black,
          unselectedLabelColor: Colors.white54,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.handyman_rounded, size: 20), text: 'Maintenance'),
            Tab(icon: Icon(Icons.people_alt_rounded, size: 20), text: 'Roommate Match'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMaintenanceTab(isDark),
          _buildRoommatesTab(isDark),
        ],
      ),
    );
  }

  // ── Tab 1: Maintenance Work Orders ────────────────────────────────────────

  Widget _buildMaintenanceTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        // CTA Card to report
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ABUAD WORKS & SERVICES',
                    style: GoogleFonts.robotoMono(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const Icon(Icons.build_circle_rounded, color: Colors.white, size: 22),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Faulty Socket, Tap, or Wardrobe in your room?',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Directly notify your Hall Warden and campus maintenance artisans with real-time status tracking.',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF6D28D9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Report New Issue', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _openReportSheet,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Text(
          'Your Maintenance Tickets',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),

        ..._tickets.map((t) => _buildTicketCard(t, isDark)),
      ],
    );
  }

  Widget _buildTicketCard(_MaintenanceTicket ticket, bool isDark) {
    Color statusColor;
    if (ticket.status == 'Completed') {
      statusColor = const Color(0xFF10B981);
    } else if (ticket.status == 'Assigned') {
      statusColor = const Color(0xFF3B82F6);
    } else {
      statusColor = const Color(0xFFF59E0B);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ticket.id,
                style: GoogleFonts.robotoMono(fontWeight: FontWeight.bold, fontSize: 12, color: const Color(0xFF8B5CF6)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  ticket.status,
                  style: GoogleFonts.robotoMono(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${ticket.hall} · Room ${ticket.room}',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            ticket.issue,
            style: GoogleFonts.inter(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.category_rounded, size: 14, color: isDark ? Colors.white38 : Colors.black45),
              const SizedBox(width: 4),
              Text(ticket.category, style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45)),
              const Spacer(),
              Text(ticket.reportedTime, style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Roommate Matching Hub ──────────────────────────────────────────

  Widget _buildRoommatesTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Intro
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.black : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Color(0xFF8B5CF6), size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Roommate Compatibility',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      'Matches generated based on sleep schedules, study noise preferences, and cleanliness habits.',
                      style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Text(
          'Top Compatible Students for Next Session',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),

        ..._roommates.map((rm) => _buildRoommateCard(rm, isDark)),
      ],
    );
  }

  Widget _buildRoommateCard(_RoommateMatch match, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: match.color.withValues(alpha: 0.2),
                child: Text(
                  match.avatarInitials,
                  style: GoogleFonts.outfit(color: match.color, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      match.name,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      '${match.level} · ${match.college}',
                      style: GoogleFonts.inter(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: Text(
                  '${match.compatibility}% Match',
                  style: GoogleFonts.robotoMono(color: const Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            match.bio,
            style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
          ),
          const SizedBox(height: 12),

          // Habit tags
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildHabitChip(Icons.bedtime_rounded, match.sleepHabit, isDark),
              _buildHabitChip(Icons.menu_book_rounded, match.studyStyle, isDark),
              _buildHabitChip(Icons.cleaning_services_rounded, match.cleanliness, isDark),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                label: const Text('Connect with Roommate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Chat invitation sent to @${match.handle}!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHabitChip(IconData icon, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white54),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87)),
        ],
      ),
    );
  }
}

class _MaintenanceTicket {
  final String id;
  final String hall;
  final String room;
  final String category;
  final String issue;
  final String status;
  final String reportedTime;
  final String priority;

  _MaintenanceTicket({
    required this.id,
    required this.hall,
    required this.room,
    required this.category,
    required this.issue,
    required this.status,
    required this.reportedTime,
    required this.priority,
  });
}

class _RoommateMatch {
  final String name;
  final String handle;
  final String level;
  final String college;
  final int compatibility;
  final String avatarInitials;
  final Color color;
  final String sleepHabit;
  final String studyStyle;
  final String cleanliness;
  final String bio;

  _RoommateMatch({
    required this.name,
    required this.handle,
    required this.level,
    required this.college,
    required this.compatibility,
    required this.avatarInitials,
    required this.color,
    required this.sleepHabit,
    required this.studyStyle,
    required this.cleanliness,
    required this.bio,
  });
}
