import 'package:flutter/material.dart';

class ClinicQueueScreen extends StatefulWidget {
  const ClinicQueueScreen({super.key});

  @override
  State<ClinicQueueScreen> createState() => _ClinicQueueScreenState();
}

class _ClinicQueueScreenState extends State<ClinicQueueScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int? _myTicketNumber = 48;
  final int _currentServingTicket = 42;
  final int _estimatedMinsPerPatient = 6;

  final List<Map<String, dynamic>> _pharmacyStock = [
    {'name': 'Artemether + Lumefantrine (Coartem)', 'type': 'Anti-Malarial', 'inStock': true, 'qty': 'Plenty available'},
    {'name': 'Paracetamol 500mg Tablets', 'type': 'Pain & Fever Relief', 'inStock': true, 'qty': 'In stock'},
    {'name': 'Amoxicillin / Clavulanic Acid 625mg', 'type': 'Antibiotics', 'inStock': true, 'qty': 'Requires Prescription'},
    {'name': 'Vitamin C 1000mg Chewables', 'type': 'Supplements', 'inStock': true, 'qty': 'In stock'},
    {'name': 'Oral Rehydration Salts (ORS)', 'type': 'Hydration', 'inStock': true, 'qty': 'In stock'},
    {'name': 'Salbutamol Inhaler (Ventolin)', 'type': 'Asthma Relief', 'inStock': false, 'qty': 'Out of stock (Refilling at 2 PM)'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _getNewTicket() {
    setState(() {
      _myTicketNumber = 53;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Virtual queue ticket #53 booked at Health Centre OPD.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final peopleAhead = _myTicketNumber != null ? (_myTicketNumber! - _currentServingTicket) : 0;
    final estimatedWait = peopleAhead * _estimatedMinsPerPatient;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.local_hospital_rounded, color: Colors.tealAccent),
            SizedBox(width: 8),
            Text('AMSH Health Centre & OPD'),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.tealAccent,
          indicatorColor: Colors.tealAccent,
          tabs: const [
            Tab(text: 'Virtual Queue'),
            Tab(text: 'Pharmacy Stock'),
            Tab(text: 'Consultation'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: VIRTUAL QUEUE
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                color: isDark ? Colors.black : const Color(0xFFE6F7F5),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CURRENT TICKET SERVING',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.tealAccent : Colors.teal.shade800,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '#$_currentServingTicket',
                                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.tealAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.meeting_room_outlined, size: 16, color: Colors.tealAccent),
                                SizedBox(width: 6),
                                Text('Dr. Balogun (Room 2)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 28),
                      if (_myTicketNumber != null) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text('Your Ticket', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Text('#$_myTicketNumber', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.tealAccent)),
                              ],
                            ),
                            Column(
                              children: [
                                const Text('Patients Ahead', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Text('$peopleAhead', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Column(
                              children: [
                                const Text('Est. Wait', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Text('~$estimatedWait mins', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Row(
                          children: [
                            Icon(Icons.notifications_active_outlined, size: 16, color: Colors.tealAccent),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'You will receive a notification when 2 patients are remaining before your turn.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        const Text('You do not have an active queue ticket right now.'),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.tealAccent.shade700,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _getNewTicket,
                          icon: const Icon(Icons.confirmation_num_outlined),
                          label: const Text('Join OPD Virtual Queue'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Health Centre Guidelines', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.badge_outlined, color: Colors.tealAccent),
                title: const Text('Have Student ID card ready'),
                subtitle: const Text('Required at the nurses station before vital signs check.'),
              ),
              ListTile(
                leading: const Icon(Icons.medication_liquid_outlined, color: Colors.tealAccent),
                title: const Text('Emergency Cases Bypass Queue'),
                subtitle: const Text('Severe asthma, acute trauma, or collapse should report straight to Emergency ER.'),
              ),
            ],
          ),

          // TAB 2: PHARMACY STOCK
          ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _pharmacyStock.length,
            itemBuilder: (context, idx) {
              final med = _pharmacyStock[idx];
              final inStock = med['inStock'] as bool;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                color: isDark ? Colors.black : Colors.white,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: inStock ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                    child: Icon(
                      inStock ? Icons.check_circle_outline : Icons.highlight_off_rounded,
                      color: inStock ? Colors.green : Colors.redAccent,
                    ),
                  ),
                  title: Text(med['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text('${med['type']} • ${med['qty']}', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: inStock ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      inStock ? 'Available' : 'Out',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: inStock ? Colors.green : Colors.redAccent,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // TAB 3: CONSULTATION BOOKING
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: isDark ? Colors.black : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Book Specialist Consultation',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Select a clinic department for non-emergency appointments.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      _buildDeptOption('Dental Clinic (AMSH Ward 1)', 'Mon, Wed, Fri (9 AM - 2 PM)'),
                      _buildDeptOption('Optometry & Eye Clinic', 'Tuesdays & Thursdays'),
                      _buildDeptOption('Physiotherapy & Sports Rehab', 'Daily (10 AM - 4 PM)'),
                      _buildDeptOption('Counseling & Mental Wellness', 'Confidential appointments'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeptOption(String title, String schedule) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withOpacity(0.2))),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text(schedule, style: const TextStyle(fontSize: 11)),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.tealAccent.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Appointment requested for $title. You will be scheduled via SMS.')),
            );
          },
          child: const Text('Book', style: TextStyle(fontSize: 12)),
        ),
      ),
    );
  }
}
