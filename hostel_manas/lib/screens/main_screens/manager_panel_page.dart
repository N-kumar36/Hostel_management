import 'package:HostelMess/screens/managerScreen/fine_management_page.dart';
import 'package:HostelMess/screens/managerScreen/PendingStudentsPage.dart';
import 'package:HostelMess/screens/managerScreen/RoutineManagementPage.dart';
import 'package:HostelMess/screens/managerScreen/ServeMealPage.dart';
import 'package:HostelMess/screens/managerScreen/VoteStatsPage.dart';
import 'package:HostelMess/screens/managerScreen/all_hostel_student_page.dart';
import 'package:HostelMess/screens/managerScreen/create_meal_page.dart';
import 'package:HostelMess/screens/managerScreen/GuestMealPage.dart';
import 'package:HostelMess/services/api_service.dart';
import 'package:flutter/material.dart';

class ManagerPanelPage extends StatefulWidget {
  const ManagerPanelPage({super.key});

  @override
  State<ManagerPanelPage> createState() => _ManagerPanelPageState();
}

class _ManagerPanelPageState extends State<ManagerPanelPage> {
  final api = ApiService();

  int pendingStudentCount = 0;
  int pendingGuestMealCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchCounts();
  }

  // Fetch the counts from the backend
  Future<void> _fetchCounts() async {
    try {
      // Single API call fetches both numbers instantly
      final res = await api.getDashboardCounts();

      if (mounted && res['success'] == true) {
        setState(() {
          // Fallback to 0 if null
          pendingStudentCount = res['pendingStudents'] ?? 0;
          pendingGuestMealCount = res['pendingGuests'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint("Error fetching counts: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manager Panel"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _adminCard(
              context,
              "Pending Student",
              Icons.person_add_alt_1,
              Colors.green,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PendingStudentsPage(),
                  ),
                ).then((_) => _fetchCounts()); // Refresh count when returning
              },
              badgeCount: pendingStudentCount, // Pass the count here
            ),
            _adminCard(context, "All Students", Icons.group, Colors.purple, () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AllHostelStudentPage(),
                ),
              );
            }),
            _adminCard(
              context,
              "Set Hostel Routine",
              Icons.calendar_today,
              Colors.teal.shade600,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RoutineManagementPage(),
                  ),
                );
              },
            ),
            _adminCard(
              context,
              "Create Meal",
              Icons.add_circle_outline,
              const Color.fromARGB(255, 34, 211, 208),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MealManagementPage(),
                  ),
                );
              },
            ),
            _adminCard(
              context,
              "Vote Stats",
              Icons.bar_chart_rounded,
              Colors.blue,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const VoteStatusSelectionPage(),
                  ),
                );
              },
            ),
            _adminCard(
              context,
              "Serve Meals",
              Icons.restaurant_rounded,
              Colors.orange,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ServeMealPage(),
                  ),
                );
              },
            ),
            _adminCard(
              context,
              "Generate Fines",
              Icons.monetization_on_outlined,
              Colors.red,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FineManagementPage(),
                  ),
                );
              },
            ),
            _adminCard(
              context,
              "Guest Meal",
              Icons.supervised_user_circle_rounded,
              const Color.fromARGB(255, 54, 174, 244),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GuestMealPage(),
                  ),
                ).then((_) => _fetchCounts()); // Refresh count when returning
              },
              badgeCount: pendingGuestMealCount, // Pass the count here
            ),
          ],
        ),
      ),
    );
  }

  // Updated to accept an optional badgeCount
  Widget _adminCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    int badgeCount = 0, // Defaults to 0
  }) {
    return Stack(
      children: [
        // Main Card
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 40, color: color),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ),
        ),

        // Red Notification Badge
        if (badgeCount > 0)
          Positioned(
            top: 8, // Safely inside the card bounds
            right: 8, // Safely inside the card bounds
            child: Container(
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  badgeCount > 99 ? '99+' : badgeCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
