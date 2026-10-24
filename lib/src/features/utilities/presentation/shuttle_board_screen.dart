import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class ShuttleBoardScreen extends StatefulWidget {
  const ShuttleBoardScreen({super.key});

  @override
  State<ShuttleBoardScreen> createState() => _ShuttleBoardScreenState();
}

class _ShuttleBoardScreenState extends State<ShuttleBoardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Campus Shuttle Routes
  final List<_ShuttleRoute> _routes = [
    _ShuttleRoute(
      routeName: 'Route 1: Central Campus Loop',
      stops: 'Male/Female Hostels ⇄ College of Law ⇄ Engineering ⇄ TDC',
      interval: 'Every 8 mins',
      nextBus: 'In 3 mins',
      fare: 'FREE for Students',
      activeBuses: 4,
      color: const Color(0xFF10B981),
    ),
    _ShuttleRoute(
      routeName: 'Route 2: Hospital & Sports Express',
      stops: 'Main Campus Gate ⇄ Sports Arena ⇄ Afe Babalola Hospital (ABUTH)',
      interval: 'Every 15 mins',
      nextBus: 'In 7 mins',
      fare: '₦100 Special Trip',
      activeBuses: 2,
      color: const Color(0xFF3B82F6),
    ),
    _ShuttleRoute(
      routeName: 'Route 3: Postgraduate & Farm Annex',
      stops: 'Central Library ⇄ PG Hall ⇄ Agro-Allied Farm Complex',
      interval: 'Every 20 mins',
      nextBus: 'In 12 mins',
      fare: 'FREE for Students',
      activeBuses: 1,
      color: const Color(0xFF8B5CF6),
    ),
  ];

  // Carpools
  final List<_CarpoolRide> _rides = [
    _CarpoolRide(
      hostName: 'David Adeleke',
      hostHandle: 'davido_abuad',
      destination: 'Akure Domestic Airport (AKR)',
      dateText: 'Friday, Oct 30 · 11:30 AM',
      seatsAvailable: 2,
      totalSeats: 4,
      splitFare: '₦3,500 / seat',
      pickupPoint: 'Nelson Mandela Hall Roundabout',
      notes: 'Heading to catch Air Peace flight to Abuja. Trunk has space for 2 medium luggage.',
    ),
    _CarpoolRide(
      hostName: 'Sola Ajayi',
      hostHandle: 'sola_rides',
      destination: 'Lagos (Berger / Ikeja)',
      dateText: 'Saturday, Nov 1 · 7:00 AM',
      seatsAvailable: 1,
      totalSeats: 3,
      splitFare: '₦8,000 / seat',
      pickupPoint: 'ABUAD Main Gate Car Park',
      notes: 'Clean AC Sienna. Safe, comfortable driving straight to Lagos.',
    ),
    _CarpoolRide(
      hostName: 'Kemi Adebayo',
      hostHandle: 'kemi_ado',
      destination: 'Ado Town / Market Shopping',
      dateText: 'Saturday, Oct 31 · 2:00 PM',
      seatsAvailable: 3,
      totalSeats: 4,
      splitFare: '₦800 / seat',
      pickupPoint: 'Queen Mother Hall Gate',
      notes: 'Supermarket shopping in Ado town. Returning to campus by 5:30 PM.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _postNewCarpool() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Carpool creation form opened! Fill your destination and available seats.'),
        behavior: SnackBarBehavior.floating,
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
          'Campus Shuttle & Travel Board',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF10B981),
          indicatorWeight: 3,
          labelColor: isDark ? Colors.white : Colors.black,
          unselectedLabelColor: Colors.white54,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.directions_bus_rounded, size: 20), text: 'Campus Shuttles'),
            Tab(icon: Icon(Icons.airport_shuttle_rounded, size: 20), text: 'Airport & Town Carpools'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildShuttlesTab(isDark),
          _buildCarpoolsTab(isDark),
        ],
      ),
    );
  }

  // ── Tab 1: Campus Shuttle Timetable ───────────────────────────────────────

  Widget _buildShuttlesTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Live Shuttle Status Banner
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF047857)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.35),
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
                      'CAMPUS TRANSPORTATION SERVICE',
                      style: GoogleFonts.robotoMono(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Icon(Icons.electric_bolt_rounded, color: Colors.amberAccent, size: 20),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '7 Active Shuttles Running on Campus',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Free transport for all matriculated students between hostels, lecture colleges, and TDC.',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Text(
          'Live Route Timetables & Stops',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),

        ..._routes.map((route) => _buildRouteCard(route, isDark)),
      ],
    );
  }

  Widget _buildRouteCard(_ShuttleRoute route, bool isDark) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  route.routeName,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: route.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: route.color),
                ),
                child: Text(
                  route.nextBus,
                  style: GoogleFonts.robotoMono(color: route.color, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.route_rounded, size: 16, color: Colors.white38),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  route.stops,
                  style: GoogleFonts.inter(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Frequency: ${route.interval}',
                style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
              ),
              Text(
                route.fare,
                style: GoogleFonts.robotoMono(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Carpools to Town & Airport ──────────────────────────────────────

  Widget _buildCarpoolsTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Post Ride Banner
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.car_rental_rounded, color: Color(0xFF3B82F6), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Traveling home for the break?',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      'Share car seats with verified ABUAD students and split the fare.',
                      style: GoogleFonts.inter(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onPressed: _postNewCarpool,
                child: const Text('Post Ride'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Text(
          'Active Student Carpools & Shared Cabs',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),

        ..._rides.map((ride) => _buildCarpoolCard(ride, isDark)),
      ],
    );
  }

  Widget _buildCarpoolCard(_CarpoolRide ride, bool isDark) {
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, color: Color(0xFF3B82F6), size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            ride.destination,
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Departure: ${ride.dateText}',
                      style: GoogleFonts.inter(color: const Color(0xFF10B981), fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  ride.splitFare,
                  style: GoogleFonts.robotoMono(fontWeight: FontWeight.bold, color: const Color(0xFF3B82F6), fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            ride.notes,
            style: GoogleFonts.inter(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.pin_drop_outlined, size: 14, color: Colors.white38),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Pickup: ${ride.pickupPoint}',
                  style: GoogleFonts.inter(fontSize: 11, color: isDark ? Colors.white38 : Colors.black45),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${ride.seatsAvailable} of ${ride.totalSeats} seats remaining',
                style: GoogleFonts.robotoMono(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: ride.seatsAvailable > 0 ? const Color(0xFF10B981) : Colors.redAccent,
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                label: const Text('Join Ride', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Seat request sent to @${ride.hostHandle}!'),
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

class _ShuttleRoute {
  final String routeName;
  final String stops;
  final String interval;
  final String nextBus;
  final String fare;
  final int activeBuses;
  final Color color;

  _ShuttleRoute({
    required this.routeName,
    required this.stops,
    required this.interval,
    required this.nextBus,
    required this.fare,
    required this.activeBuses,
    required this.color,
  });
}

class _CarpoolRide {
  final String hostName;
  final String hostHandle;
  final String destination;
  final String dateText;
  final int seatsAvailable;
  final int totalSeats;
  final String splitFare;
  final String pickupPoint;
  final String notes;

  _CarpoolRide({
    required this.hostName,
    required this.hostHandle,
    required this.destination,
    required this.dateText,
    required this.seatsAvailable,
    required this.totalSeats,
    required this.splitFare,
    required this.pickupPoint,
    required this.notes,
  });
}
