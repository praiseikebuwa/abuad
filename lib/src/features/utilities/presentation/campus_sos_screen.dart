import 'dart:async';
import 'package:flutter/material.dart';

class CampusSosScreen extends StatefulWidget {
  const CampusSosScreen({super.key});

  @override
  State<CampusSosScreen> createState() => _CampusSosScreenState();
}

class _CampusSosScreenState extends State<CampusSosScreen> {
  bool _isCountdownActive = false;
  int _countdownSeconds = 5;
  Timer? _timer;
  bool _sosDispatched = false;

  void _triggerSos() {
    setState(() {
      _isCountdownActive = true;
      _countdownSeconds = 5;
      _sosDispatched = false;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 1) {
        setState(() {
          _countdownSeconds--;
        });
      } else {
        timer.cancel();
        setState(() {
          _isCountdownActive = false;
          _sosDispatched = true;
        });
      }
    });
  }

  void _cancelSos() {
    _timer?.cancel();
    setState(() {
      _isCountdownActive = false;
      _sosDispatched = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SOS Alert cancelled.')),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.emergency_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Campus SOS & Emergency'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Panic Button Box
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _sosDispatched
                    ? [Colors.red.shade900, Colors.redAccent.shade700]
                    : [const Color(0xFF2E0808), const Color(0xFF4A1010)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.redAccent.withOpacity(0.4), width: 1.5),
            ),
            child: Column(
              children: [
                if (!_isCountdownActive && !_sosDispatched) ...[
                  const Text(
                    'EMERGENCY PANIC DISPATCH',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Press to alert Campus Security and AMSH Medical Response with your live location.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: _triggerSos,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.redAccent,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withOpacity(0.5),
                            blurRadius: 30,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 48, color: Colors.white),
                            SizedBox(height: 4),
                            Text(
                              'SOS',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 26,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ] else if (_isCountdownActive) ...[
                  const Text(
                    'DISPATCHING IN',
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$_countdownSeconds',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 64),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tap Cancel if triggered accidentally',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red.shade900,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: _cancelSos,
                    child: const Text('CANCEL SOS', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ] else if (_sosDispatched) ...[
                  const Icon(Icons.check_circle, color: Colors.white, size: 54),
                  const SizedBox(height: 12),
                  const Text(
                    'SOS DISPATCHED!',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Security team & AMSH ER notified with your hostel coordinates.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                    ),
                    onPressed: _cancelSos,
                    child: const Text('Reset Alert'),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Text(
            'Direct Emergency Helplines',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          _buildContactCard(
            context,
            title: 'Campus Security & Gate Control',
            phone: '0803 000 1122',
            icon: Icons.shield_rounded,
            color: Colors.blueAccent,
            subtitle: 'Immediate patrol dispatch & security presence',
          ),
          _buildContactCard(
            context,
            title: 'AMSH Hospital Emergency (ER)',
            phone: '0805 111 2233',
            icon: Icons.local_hospital_rounded,
            color: Colors.redAccent,
            subtitle: 'Ambulance service & urgent medical care',
          ),
          _buildContactCard(
            context,
            title: 'Campus Fire & Safety Unit',
            phone: '0802 333 4455',
            icon: Icons.local_fire_department_rounded,
            color: Colors.orangeAccent,
            subtitle: 'Fire hazards, electrical sparks & smoke reports',
          ),
          _buildContactCard(
            context,
            title: 'Student Affairs & Guidance Office',
            phone: '0810 444 5566',
            icon: Icons.support_agent_rounded,
            color: Colors.tealAccent,
            subtitle: 'Mental health, counseling & urgent student matters',
          ),

          const SizedBox(height: 20),
          // Medical Profile Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: isDark ? Colors.black : Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.badge_rounded, color: Colors.blueAccent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Your Medical Emergency Card',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Blood Group: O+ Positive', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('Genotype: AA', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Known Allergies: Penicillin, Peanuts', style: TextStyle(fontSize: 13, color: Colors.orange)),
                  const SizedBox(height: 8),
                  const Text('Next of Kin: Dr. & Mrs. Oladipo (0803-123-4567)', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.edit, size: 14),
                      label: const Text('Update Medical ID', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Medical ID syncs with AMSH Student Records.')),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(
    BuildContext context, {
    required String title,
    required String phone,
    required IconData icon,
    required Color color,
    required String subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: isDark ? Colors.black : Colors.white,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])),
            const SizedBox(height: 2),
            Text(phone, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
        trailing: IconButton(
          icon: CircleAvatar(
            backgroundColor: color.withOpacity(0.2),
            child: Icon(Icons.phone, color: color, size: 18),
          ),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Dialing $title ($phone)...')),
            );
          },
        ),
      ),
    );
  }
}
