import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../user/data/user_repository.dart';
import '../data/academic_repository.dart';

class StudentIdScreen extends ConsumerStatefulWidget {
  const StudentIdScreen({super.key});

  @override
  ConsumerState<StudentIdScreen> createState() => _StudentIdScreenState();
}

class _StudentIdScreenState extends ConsumerState<StudentIdScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _showFront = true;
  Map<String, String>? _customProfile;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    );
    _loadCustomProfile();
  }

  Future<void> _loadCustomProfile() async {
    final profile = await ref.read(academicRepositoryProvider).getStudentIdProfile();
    if (mounted) setState(() => _customProfile = profile);
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    HapticFeedback.mediumImpact();
    if (_showFront) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
    setState(() => _showFront = !_showFront);
  }

  String _formatMatric(String uid) {
    final clean = uid.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length >= 6) {
      return '21/ENG02/${clean.substring(clean.length - 4)}';
    }
    return '21/ENG02/089';
  }

  void _showEditProfileDialog(String currentMatric, String currentDept, String currentCollege) {
    final matricCtrl = TextEditingController(text: _customProfile?['matricNumber'] ?? currentMatric);
    final deptCtrl = TextEditingController(text: _customProfile?['department'] ?? currentDept);
    final collegeCtrl = TextEditingController(text: _customProfile?['college'] ?? currentCollege);
    String selectedLevel = _customProfile?['level'] ?? '400L';
    String selectedBlood = _customProfile?['bloodGroup'] ?? 'O+';
    String session = _customProfile?['session'] ?? '2025/2026';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.badge_rounded, color: AppColors.secondaryTeal),
              SizedBox(width: 10),
              Text('Edit Student ID', style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: matricCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Matriculation Number',
                    hintText: 'e.g. 21/ENG02/089',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: deptCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Department',
                    hintText: 'e.g. Computer Engineering',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: collegeCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'College / Faculty',
                    hintText: 'e.g. College of Engineering',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedLevel,
                        dropdownColor: const Color(0xFF1E293B),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Level',
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        items: ['100L', '200L', '300L', '400L', '500L', 'Postgrad']
                            .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setDialogState(() => selectedLevel = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedBlood,
                        dropdownColor: const Color(0xFF1E293B),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Blood',
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        items: ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-']
                            .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setDialogState(() => selectedBlood = v);
                        },
                      ),
                    ),
                  ],
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
                final newProfile = {
                  'matricNumber': matricCtrl.text.trim().isNotEmpty ? matricCtrl.text.trim() : currentMatric,
                  'department': deptCtrl.text.trim().isNotEmpty ? deptCtrl.text.trim() : currentDept,
                  'college': collegeCtrl.text.trim().isNotEmpty ? collegeCtrl.text.trim() : currentCollege,
                  'level': selectedLevel,
                  'bloodGroup': selectedBlood,
                  'session': session,
                  'expiryDate': '31 Oct 2026',
                };
                Navigator.pop(ctx);
                await ref.read(academicRepositoryProvider).saveStudentIdProfile(newProfile);
                setState(() => _customProfile = newProfile);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Student ID Card details updated!')),
                  );
                }
              },
              child: const Text('Save Details'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final displayName = user?.displayName.isNotEmpty == true ? user!.displayName : 'Student Name';
    final fallbackMatric = _formatMatric(user?.uid ?? '20230001');
    final fallbackDept = user?.department?.isNotEmpty == true ? user!.department! : 'Computer Engineering';
    final fallbackCollege = user?.college?.isNotEmpty == true ? user!.college! : 'College of Engineering';

    final matricNumber = _customProfile?['matricNumber']?.isNotEmpty == true ? _customProfile!['matricNumber']! : fallbackMatric;
    final department = _customProfile?['department']?.isNotEmpty == true ? _customProfile!['department']! : fallbackDept;
    final college = _customProfile?['college']?.isNotEmpty == true ? _customProfile!['college']! : fallbackCollege;
    final level = _customProfile?['level'] ?? '400L';
    final bloodGroup = _customProfile?['bloodGroup'] ?? 'O+';
    final session = _customProfile?['session'] ?? '2025/2026';
    final expiryDate = _customProfile?['expiryDate'] ?? '31 Oct 2026';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1D) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          'Digital Student ID',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 19),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Card Details',
            onPressed: () => _showEditProfileDialog(matricNumber, department, college),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_android_rounded),
            tooltip: 'Flip Card',
            onPressed: _toggleFlip,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              // Security info pill
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.secondaryTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.secondaryTeal.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded, size: 16, color: AppColors.secondaryTeal),
                    const SizedBox(width: 8),
                    Text(
                      'Official ABUAD Smart Identity Card',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondaryTeal,
                      ),
                    ),
                  ],
                ),
              ),

              // Flippable ID Card
              Center(
                child: GestureDetector(
                  onTap: _toggleFlip,
                  child: AnimatedBuilder(
                    animation: _flipAnimation,
                    builder: (context, child) {
                      final angle = _flipAnimation.value * pi;
                      final isFront = angle < (pi / 2);

                      return Transform(
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0015)
                          ..rotateY(angle),
                        alignment: Alignment.center,
                        child: isFront
                            ? _buildCardFront(
                                displayName,
                                matricNumber,
                                department,
                                college,
                                user?.avatarUrl,
                                level: level,
                                bloodGroup: bloodGroup,
                                expiryDate: expiryDate,
                              )
                            : Transform(
                                transform: Matrix4.identity()..rotateY(pi),
                                alignment: Alignment.center,
                                child: _buildCardBack(matricNumber),
                              ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 18),
              Text(
                'Tap card to flip over for barcode & regulations',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),

              const SizedBox(height: 32),

              // Quick Actions Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(
                          color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                        ),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: Text('Edit ID Info', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      onPressed: () => _showEditProfileDialog(matricNumber, department, college),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondaryTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.qr_code_rounded, size: 18),
                      label: Text('Show QR', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      onPressed: _toggleFlip,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Information List
              _buildInfoSection(
                title: 'Card Details',
                isDark: isDark,
                items: [
                  _InfoRow(label: 'Full Name', value: displayName),
                  _InfoRow(label: 'Matriculation No.', value: matricNumber),
                  _InfoRow(label: 'College / Faculty', value: college),
                  _InfoRow(label: 'Department', value: department),
                  _InfoRow(label: 'Level', value: level),
                  _InfoRow(label: 'Blood Group', value: bloodGroup),
                  _InfoRow(label: 'Academic Session', value: session),
                  _InfoRow(label: 'Status', value: 'Active Student', isStatus: true),
                  _InfoRow(label: 'Expiry Date', value: expiryDate),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardFront(
    String name,
    String matric,
    String department,
    String college,
    String? avatarUrl, {
    String level = '400L',
    String bloodGroup = 'O+',
    String expiryDate = '31 Oct 2026',
  }) {
    return Container(
      width: 350,
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E293B),
            Color(0xFF0F2B33),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppColors.secondaryTeal.withValues(alpha: 0.15),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ],
        border: Border.all(
          color: AppColors.secondaryTeal.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Decorative background patterns
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondaryTeal.withValues(alpha: 0.1),
                ),
              ),
            ),
            Positioned(
              right: 15,
              bottom: 15,
              child: Opacity(
                opacity: 0.08,
                child: Icon(Icons.school_rounded, size: 100, color: Colors.white),
              ),
            ),

            // Card Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Banner
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.school_rounded, color: AppColors.secondaryTeal, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AFE BABALOLA UNIVERSITY',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'STUDENT IDENTITY CARD',
                              style: GoogleFonts.inter(
                                color: AppColors.secondaryTeal,
                                fontWeight: FontWeight.w700,
                                fontSize: 8.5,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.greenAccent, width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.greenAccent,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'VALID',
                              style: GoogleFonts.inter(
                                color: Colors.greenAccent,
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Divider(color: Colors.white12, height: 16),

                  // Middle Section: Photo & Details
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Student Photo
                      Container(
                        width: 76,
                        height: 88,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24, width: 1.5),
                          color: Colors.black,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: avatarUrl != null && avatarUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: avatarUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  errorWidget: (context, url, error) => const Icon(
                                    Icons.person_rounded,
                                    color: Colors.white54,
                                    size: 40,
                                  ),
                                )
                              : const Icon(
                                  Icons.person_rounded,
                                  color: Colors.white54,
                                  size: 40,
                                ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              matric,
                              style: GoogleFonts.robotoMono(
                                color: AppColors.secondaryTeal,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              department,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              college,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: Colors.white54,
                                fontSize: 9.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _badge(level),
                                const SizedBox(width: 6),
                                _badge(bloodGroup),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Bottom Watermark & Security strip
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'EXP: $expiryDate',
                        style: GoogleFonts.robotoMono(color: Colors.white38, fontSize: 8.5),
                      ),
                      Text(
                        '★ ABUAD SMART CAMPUS ★',
                        style: GoogleFonts.outfit(
                          color: Colors.white24,
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardBack(String matric) {
    return Container(
      width: 350,
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F2B33),
            Color(0xFF0F172A),
            Color(0xFF1E293B),
          ],
          begin: Alignment.bottomRight,
          end: Alignment.topLeft,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: AppColors.secondaryTeal.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Magnetic Strip Simulation
              Container(
                height: 32,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF050508),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'This card remains the property of Afe Babalola University.\nIf found, please return to the Security Unit, Ado-Ekiti.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white60,
                  fontSize: 8.5,
                  height: 1.3,
                ),
              ),

              const Spacer(),

              // Scannable Barcode & QR Simulation
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Barcode graphic
                    CustomPaint(
                      size: const Size(180, 36),
                      painter: _BarcodePainter(),
                    ),
                    // Real scannable QR Code
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: QrImageView(
                        data: 'https://portal.abuad.edu.ng/verify?matric=$matric',
                        version: QrVersions.auto,
                        size: 38.0,
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.all(1),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),
              Text(
                matric,
                style: GoogleFonts.robotoMono(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24, width: 0.8),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required bool isDark,
    required List<_InfoRow> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.label,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                    item.isStatus
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              item.value,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          )
                        : Text(
                            item.value,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _InfoRow {
  final String label;
  final String value;
  final bool isStatus;

  _InfoRow({
    required this.label,
    required this.value,
    this.isStatus = false,
  });
}

class _BarcodePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2;

    final widths = [
      2, 1, 3, 1, 2, 4, 1, 2, 1, 3, 2, 1, 4, 2, 1, 3, 1, 2, 4, 1, 2, 3, 1, 2,
      1, 4, 2, 1, 3, 2, 1, 4, 1, 2, 3, 1, 2, 1, 4, 2, 1, 3, 1, 2, 4, 1, 2, 3
    ];
    double x = 4;
    for (int i = 0; i < widths.length && x < size.width - 4; i++) {
      final w = widths[i].toDouble();
      if (i % 2 == 0) {
        canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), paint);
      }
      x += w + 1.2;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
