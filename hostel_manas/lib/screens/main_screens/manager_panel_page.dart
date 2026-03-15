import 'package:HostelMess/screens/managerScreen/FineManagementPage/fine_management_page.dart';
import 'package:HostelMess/screens/managerScreen/PendingStudentsPage.dart';
import 'package:HostelMess/screens/managerScreen/RoutineManagementPage.dart';
import 'package:HostelMess/screens/managerScreen/ServeMealPage.dart';
import 'package:HostelMess/screens/managerScreen/VoteStatsPage.dart';
import 'package:HostelMess/screens/managerScreen/all_hostel_student_page.dart';
import 'package:HostelMess/screens/managerScreen/create_meal_page.dart';
import 'package:HostelMess/screens/managerScreen/GuestMealPage.dart';
import 'package:flutter/material.dart';

class ManagerPanelPage extends StatelessWidget {
  const ManagerPanelPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 1. Added the AppBar here
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
                );
              },
            ),
            // 2. Added the "All Students" card
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
                // Navigate to your meal list first so admin can pick a date
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
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ServeMealPage()));
              },
            ),
            _adminCard(
              context,
              "Generate Fines",
              Icons.monetization_on_outlined,
              Colors.red,
              () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const FineManagementPage()));

              },
            ),
            _adminCard(
              context,
              "Guest Meal",
              Icons.supervised_user_circle_rounded,
              const Color.fromARGB(255, 54, 174, 244),
              () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const GuestMealPage()));
              },
            ),
            
          ],
        ),
      ),
    );
  }

  Widget _adminCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
    );
  }
}
