import 'package:flutter/material.dart';

class PatientMainScreen extends StatelessWidget {
  const PatientMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Patient Dashboard',
          style: TextStyle(
            color: Color(0xFF1F2E2F),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none, color: Color(0xFF1F2E2F)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF4D7B5A),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Hi, Sarah',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Your medication routine is on track today.',
                      style: TextStyle(
                        color: Color(0xFFE6F1EA),
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Today\'s medicines',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F2E2F),
                ),
              ),
              const SizedBox(height: 14),
              const _MedicineCard(
                name: 'Amoxicillin',
                time: '08:00 AM',
                dose: '500mg',
                status: 'Taken',
              ),
              const SizedBox(height: 12),
              const _MedicineCard(
                name: 'Vitamin D',
                time: '01:00 PM',
                dose: '1000 IU',
                status: 'Upcoming',
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: const Color(0xFF4D7B5A),
        unselectedItemColor: const Color(0xFF7F8A87),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.medication), label: 'Meds'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Schedule'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _MedicineCard extends StatelessWidget {
  final String name;
  final String time;
  final String dose;
  final String status;

  const _MedicineCard({
    required this.name,
    required this.time,
    required this.dose,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final isTaken = status == 'Taken';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isTaken ? const Color(0xFFDFEDE6) : const Color(0xFFF7F0D8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.medication_liquid,
              color: isTaken ? const Color(0xFF4D7B5A) : const Color(0xFFB27B2F),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2E2F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$time · $dose',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF687A73),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isTaken ? const Color(0xFFEBF5EE) : const Color(0xFFFFF3D9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isTaken ? const Color(0xFF4D7B5A) : const Color(0xFFB27B2F),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
