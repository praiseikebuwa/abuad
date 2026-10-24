import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class StudentGigsScreen extends StatefulWidget {
  const StudentGigsScreen({super.key});

  @override
  State<StudentGigsScreen> createState() => _StudentGigsScreenState();
}

class _StudentGigsScreenState extends State<StudentGigsScreen> {
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    '✂️ Barbing & Hair',
    '🎨 Graphic Design',
    '📸 Photography',
    '💻 Laptop Repairs',
    '📚 Peer Tutoring',
    '🎤 Event MC & DJ',
  ];

  final List<_StudentGig> _gigs = [
    _StudentGig(
      studentName: 'Tunde Fadeyi',
      handle: 'tunde_cuts',
      category: '✂️ Barbing & Hair',
      title: 'Crisp Campus Haircuts & Beard Sculpting',
      hall: 'Nelson Mandela Hall B-Wing',
      price: 'From ₦2,000',
      rating: 4.9,
      reviewsCount: 38,
      whatsapp: '+2348011223344',
      description: 'Professional barbering equipment, sanitized clippers, hot towel treatment, home service to any male hostel.',
    ),
    _StudentGig(
      studentName: 'Blessing Okafor',
      handle: 'blessing_braids',
      category: '✂️ Barbing & Hair',
      title: 'Knotless Braids, Wigs Revamping & Cornrows',
      hall: 'Queen Mother Hall Room 114',
      price: 'From ₦5,000',
      rating: 5.0,
      reviewsCount: 42,
      whatsapp: '+2348022334455',
      description: 'Neat, pain-free braiding in quiet private room. Hair extensions and styling gels included on request.',
    ),
    _StudentGig(
      studentName: 'Ibrahim Musa',
      handle: 'ib_designs',
      category: '🎨 Graphic Design',
      title: 'Flyers, Department Logos, Instagram Carousels',
      hall: 'Afe Hall A102',
      price: 'From ₦3,500',
      rating: 4.8,
      reviewsCount: 29,
      whatsapp: '+2348033445566',
      description: 'Quick 24-hour turnaround for hall week flyers, student association posters, and brand identities.',
    ),
    _StudentGig(
      studentName: 'Emeka Nwosu',
      handle: 'emeka_tech',
      category: '💻 Laptop Repairs',
      title: 'Windows/Mac OS Fixes, Screen Replacements & SSD Upgrades',
      hall: 'Wema Bank Hall C202',
      price: 'From ₦4,000',
      rating: 4.9,
      reviewsCount: 51,
      whatsapp: '+2348044556677',
      description: 'Engineering student certified hardware technician. Diagnoses, thermal paste repasting, formatting, and RAM upgrades.',
    ),
    _StudentGig(
      studentName: 'Aisha Bello',
      handle: 'aisha_tutor',
      category: '📚 Peer Tutoring',
      title: 'MTH 101, CHM 101 & GST Exam Coaching',
      hall: 'Talent Discovery Hall',
      price: '₦2,500 / hr',
      rating: 5.0,
      reviewsCount: 19,
      whatsapp: '+2348055667788',
      description: 'First Class 400L student offering 1-on-1 step-by-step past questions breakdown and exam preparation tips.',
    ),
  ];

  void _postNewGig() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Freelance service application opened. Register your campus business!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredGigs = _selectedCategory == 'All'
        ? _gigs
        : _gigs.where((g) => g.category == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Student Gigs & Freelance Board',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'CAMPUS STUDENT MICRO-ECONOMY',
                        style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Icon(Icons.stars_rounded, color: Colors.amberAccent, size: 22),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Support Student Entrepreneurs in ABUAD',
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Book peer services directly in your hall: haircuts, hair styling, design, laptop repairs, and tutoring.',
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  icon: const Icon(Icons.add_business_rounded),
                  label: const Text('Offer Your Service', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _postNewGig,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Categories horizontal list
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedCategory = cat);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF8B5CF6)
                          : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      cat,
                      style: GoogleFonts.outfit(
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Available Campus Providers (${filteredGigs.length})',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),

          ...filteredGigs.map((gig) => _buildGigCard(gig, isDark)),
        ],
      ),
    );
  }

  Widget _buildGigCard(_StudentGig gig, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                child: Text(
                  gig.studentName.isNotEmpty ? gig.studentName[0] : 'S',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF8B5CF6)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gig.studentName,
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      '@${gig.handle} · ${gig.hall}',
                      style: GoogleFonts.inter(color: isDark ? Colors.white54 : Colors.black45, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amberAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 14, color: Colors.amberAccent),
                    const SizedBox(width: 4),
                    Text(
                      '${gig.rating} (${gig.reviewsCount})',
                      style: GoogleFonts.robotoMono(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            gig.title,
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            gig.description,
            style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                gig.price,
                style: GoogleFonts.robotoMono(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: const Color(0xFF10B981),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: const Icon(Icons.chat_bubble_rounded, size: 16),
                label: const Text('Contact Provider', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Opening chat with @${gig.handle} on ABUAD Life...'),
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
}

class _StudentGig {
  final String studentName;
  final String handle;
  final String category;
  final String title;
  final String hall;
  final String price;
  final double rating;
  final int reviewsCount;
  final String whatsapp;
  final String description;

  _StudentGig({
    required this.studentName,
    required this.handle,
    required this.category,
    required this.title,
    required this.hall,
    required this.price,
    required this.rating,
    required this.reviewsCount,
    required this.whatsapp,
    required this.description,
  });
}
