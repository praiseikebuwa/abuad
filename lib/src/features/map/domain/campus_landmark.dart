import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

enum LandmarkCategory {
  college('Colleges', Icons.school_rounded, Color(0xFF6366F1)),
  administrative('Admin & Services', Icons.account_balance_rounded, Color(0xFF8B5CF6)),
  medical('Health & Hospital', Icons.local_hospital_rounded, Color(0xFFEF4444)),
  food('Food & Cafeterias', Icons.restaurant_rounded, Color(0xFFF59E0B)),
  hostel('Hostels & Living', Icons.hotel_rounded, Color(0xFF10B981)),
  sports('Sports & Rec', Icons.sports_soccer_rounded, Color(0xFF3B82F6)),
  library('Library & Research', Icons.menu_book_rounded, Color(0xFF06B6D4));

  final String label;
  final IconData icon;
  final Color color;

  const LandmarkCategory(this.label, this.icon, this.color);
}

class CampusLandmark {
  final String id;
  final String name;
  final String shortCode;
  final LandmarkCategory category;
  final LatLng position;
  final String description;
  final String aiGuideTip;
  final String hours;

  const CampusLandmark({
    required this.id,
    required this.name,
    required this.shortCode,
    required this.category,
    required this.position,
    required this.description,
    required this.aiGuideTip,
    this.hours = 'Open 24/7 (Campus Security access)',
  });

  static const List<CampusLandmark> all = [
    CampusLandmark(
      id: 'senate',
      name: 'Senate Building (Central Administration)',
      shortCode: 'SENATE',
      category: LandmarkCategory.administrative,
      position: LatLng(7.60250, 5.30610),
      description: 'Main university administrative building, Vice Chancellor office, Registry, and Bursary.',
      aiGuideTip: 'Located at the heart of campus. Best spot for clearance, official letters, and administrative services.',
      hours: 'Mon-Fri: 8:00 AM - 4:00 PM',
    ),
    CampusLandmark(
      id: 'hospital',
      name: 'ABUAD Multi-System Hospital (AMSH)',
      shortCode: 'AMSH',
      category: LandmarkCategory.medical,
      position: LatLng(7.60420, 5.30950),
      description: 'World-class 400-bed teaching hospital with emergency center, diagnostics, and specialty clinics.',
      aiGuideTip: 'Take the hospital shuttle or walk along the East Ring Road. Student clinic is situated on the Ground Floor.',
      hours: 'Emergency & Inpatient: 24/7 | Clinics: 8 AM - 5 PM',
    ),
    CampusLandmark(
      id: 'engineering',
      name: 'College of Engineering Complex',
      shortCode: 'ENG',
      category: LandmarkCategory.college,
      position: LatLng(7.60120, 5.30450),
      description: 'Engineering mega complex with mechatronics labs, mechanical workshops, and computing suites.',
      aiGuideTip: 'Home to Civil, Electrical, Mechanical, Mechatronics, and Chemical engineering departments.',
      hours: 'Mon-Sat: 7:30 AM - 7:00 PM',
    ),
    CampusLandmark(
      id: 'law',
      name: 'Aare Afe Babalola Law College',
      shortCode: 'LAW',
      category: LandmarkCategory.college,
      position: LatLng(7.60380, 5.30720),
      description: 'Flagship law college with ceremonial Moot Court, specialized law library, and modern lecture halls.',
      aiGuideTip: 'Strict corporate dress code enforced (white-on-black). Situated north of the Senate Building.',
      hours: 'Mon-Fri: 8:00 AM - 6:00 PM',
    ),
    CampusLandmark(
      id: 'mhs',
      name: 'College of Medicine & Health Sciences',
      shortCode: 'MHS',
      category: LandmarkCategory.college,
      position: LatLng(7.60450, 5.30880),
      description: 'Pre-clinical and clinical lecture halls, anatomy museum, and physiology research labs.',
      aiGuideTip: 'Adjacent to AMSH Hospital. Convenient connecting pathway directly into the teaching hospital.',
      hours: 'Mon-Sat: 8:00 AM - 6:00 PM',
    ),
    CampusLandmark(
      id: 'sms',
      name: 'College of Social & Management Sciences',
      shortCode: 'SMS',
      category: LandmarkCategory.college,
      position: LatLng(7.60180, 5.30540),
      description: 'Accounting, economics, business admin, international relations, and media studios.',
      aiGuideTip: 'Located south-west of the Senate building with its own cafeteria courtyard.',
      hours: 'Mon-Fri: 8:00 AM - 6:00 PM',
    ),
    CampusLandmark(
      id: 'sciences',
      name: 'College of Sciences & Computing',
      shortCode: 'SCI',
      category: LandmarkCategory.college,
      position: LatLng(7.60290, 5.30480),
      description: 'Modern laboratories for Computer Science, Software Engineering, Microbiology, and Biochemistry.',
      aiGuideTip: 'Equipped with multiple high-speed computing labs and tech hubs for student developers.',
      hours: 'Mon-Sat: 8:00 AM - 7:00 PM',
    ),
    CampusLandmark(
      id: 'library',
      name: 'Main University Library & E-Learning',
      shortCode: 'LIB',
      category: LandmarkCategory.library,
      position: LatLng(7.60280, 5.30660),
      description: 'Central library with physical book stacks, high-speed Wi-Fi carrels, and e-research databases.',
      aiGuideTip: 'Quiet study zones on the 2nd floor. Perfect for exam revisions and thesis preparation.',
      hours: 'Mon-Fri: 8:00 AM - 9:00 PM | Sat: 9:00 AM - 5:00 PM',
    ),
    CampusLandmark(
      id: 'alfa_belgore',
      name: 'Alfa Belgore Ceremonial Hall',
      shortCode: 'HALL',
      category: LandmarkCategory.administrative,
      position: LatLng(7.60210, 5.30700),
      description: 'Grand auditorium hosting university matriculations, convocations, symposiums, and cultural events.',
      aiGuideTip: 'Key landmark near Central Square. Landmark meeting spot for campus tours and student assemblies.',
    ),
    CampusLandmark(
      id: 'planetarium',
      name: 'Planetarium & Talent Discovery Centre',
      shortCode: 'PLANET',
      category: LandmarkCategory.administrative,
      position: LatLng(7.60330, 5.30820),
      description: 'First university planetarium in West Africa with astronomical dome and creativity studios.',
      aiGuideTip: 'Great weekend relaxation spot. Offers periodic space exhibitions and stargazing nights.',
      hours: 'Tue-Sun: 10:00 AM - 6:00 PM',
    ),
    CampusLandmark(
      id: 'cafeteria',
      name: 'Main Campus Food Court & Buka',
      shortCode: 'BUKA',
      category: LandmarkCategory.food,
      position: LatLng(7.60150, 5.30650),
      description: 'Central dining hub with variety of hot meals, Jollof rice, grills, juices, and bakeries.',
      aiGuideTip: 'Peak lunch hours are 12:30 PM - 2:00 PM. Mobile ordering and pickup are available.',
      hours: 'Daily: 7:00 AM - 9:30 PM',
    ),
    CampusLandmark(
      id: 'sports',
      name: 'Talbot Sports Complex & Olympic Pool',
      shortCode: 'SPORT',
      category: LandmarkCategory.sports,
      position: LatLng(7.60050, 5.30780),
      description: 'Football stadium, 400m synthetic track, Olympic swimming pool, tennis and basketball courts.',
      aiGuideTip: 'Open for daily workouts, inter-college football tournaments, and university sports leagues.',
      hours: 'Daily: 6:00 AM - 8:00 PM',
    ),
    CampusLandmark(
      id: 'male_hostels',
      name: 'Male Hostels Quad (Talent, Adeleke Halls)',
      shortCode: 'M-HOSTEL',
      category: LandmarkCategory.hostel,
      position: LatLng(7.59980, 5.30500),
      description: 'Male residential halls with furnished study rooms, solar inverters, and laundry points.',
      aiGuideTip: 'Hostel gate closes at 10:00 PM curfew. Maintenance desk available at the Porter lodge.',
      hours: 'Curfew: 10:00 PM nightly',
    ),
    CampusLandmark(
      id: 'female_hostels',
      name: 'Female Hostels Quad (Queen, Royal Halls)',
      shortCode: 'F-HOSTEL',
      category: LandmarkCategory.hostel,
      position: LatLng(7.60520, 5.30400),
      description: 'Female student living community with courtyard, convenience supermarket, and study parlors.',
      aiGuideTip: 'Hostel gate closes at 10:00 PM curfew. Quick maintenance dispatch accessible via Porter desk.',
      hours: 'Curfew: 10:00 PM nightly',
    ),
  ];
}
