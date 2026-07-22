import 'package:HostelMess/views/managementControl/views/buyItemsAdd/buyItems.dart';
import 'package:flutter/material.dart';
import 'package:HostelMess/services/api_service.dart';

// Import references...
import 'package:HostelMess/views/managementControl/views/mealSubscription/MealSubscriptionsPage.dart';
import 'package:HostelMess/views/managementControl/views/financeManagement/fine_management_page.dart';
import 'package:HostelMess/views/managementControl/views/pendingStudent/PendingStudentsPage.dart';
import 'package:HostelMess/views/managementControl/views/setRoutine/RoutineManagementPage.dart';
import 'package:HostelMess/views/managementControl/views/serveMeal/ServeMealPage.dart';
import 'package:HostelMess/views/managementControl/views/voteStatus/VoteStatsPage.dart';
import 'package:HostelMess/views/managementControl/views/allStudent/all_hostel_student_page.dart';
import 'package:HostelMess/views/managementControl/views/createMeal/create_meal_page.dart';
import 'package:HostelMess/views/managementControl/views/guestMeal/GuestMealPage.dart';
import 'package:HostelMess/views/managementControl/views/complains/ComplainsPage.dart';

class ManagerPanelPage extends StatefulWidget {
  const ManagerPanelPage({super.key});

  @override
  State<ManagerPanelPage> createState() => _ManagerPanelPageState();
}

class _ManagerPanelPageState extends State<ManagerPanelPage> {
  final api = ApiService();

  int pendingStudentCount = 0;
  int pendingGuestMealCount = 0;
  int pendingComplaintCount = 0;
  int pendingFineCount = 0;
  bool isScreenLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchCounts();
  }

  Future<void> _fetchCounts() async {
    if (isScreenLoading) return;
    setState(() => isScreenLoading = true);

    try {
      final res = await api.getDashboardCounts();

      if (mounted && res['success'] == true) {
        setState(() {
          pendingStudentCount = res['pendingStudents'] ?? 0;
          pendingGuestMealCount = res['pendingGuests'] ?? 0;
          pendingComplaintCount = res['pendingComplaints'] ?? 0;
          pendingFineCount = res['pendingFines'] ?? 0;
        });
        print(
          "Dashboard counts loaded: $res | Pending Students: $pendingStudentCount, Pending Guests: $pendingGuestMealCount, Pending Complaints: $pendingComplaintCount, Pending Fines: $pendingFineCount",
        );
      }
    } catch (e) {
      debugPrint("Error loading dashboard counters: $e");
    } finally {
      if (mounted) {
        setState(() => isScreenLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Manager Panel",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.deepPurple),
            onPressed: _fetchCounts,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchCounts,
        color: Colors.deepPurple,
        child: GridView.count(
          padding: const EdgeInsets.all(16.0),
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.1,
          children: [
            _adminCard(
              context,
              "Pending Students",
              Icons.person_add_alt_1_rounded,
              Colors.green,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PendingStudentsPage(),
                ),
              ).then((_) => _fetchCounts()),
              badgeCount: pendingStudentCount,
            ),
            _adminCard(
              context,
              "All Students",
              Icons.group_rounded,
              Colors.purple,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AllHostelStudentPage(),
                ),
              ),
            ),
            _adminCard(
              context,
              "Set Hostel Routine",
              Icons.calendar_today_rounded,
              Colors.teal.shade600,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RoutineManagementPage(),
                ),
              ),
            ),
            _adminCard(
              context,
              "Create Meal",
              Icons.add_circle_outline_rounded,
              const Color.fromARGB(255, 34, 211, 208),
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MealManagementPage(),
                ),
              ),
            ),
            _adminCard(
              context,
              "Vote Stats",
              Icons.bar_chart_rounded,
              Colors.blue,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const VoteStatusSelectionPage(),
                ),
              ),
            ),
            _adminCard(
              context,
              "Serve Meals",
              Icons.restaurant_rounded,
              Colors.orange,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ServeMealPage()),
              ),
            ),
            _adminCard(
              context,
              "Guest Meals",
              Icons.supervised_user_circle_rounded,
              const Color.fromARGB(255, 54, 174, 244),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GuestMealPage()),
              ).then((_) => _fetchCounts()),
              badgeCount: pendingGuestMealCount,
            ),

            //  UPDATED: Finance Management Card with independent counter badge
            _adminCard(
              context,
              "Finance Management",
              Icons.monetization_on_outlined,
              Colors.red,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FineManagementPage(),
                ),
              ).then((_) => _fetchCounts()),
              badgeCount: pendingFineCount,
            ),

            _adminCard(
              context,
              "Add Shopping Items",
              Icons.shopping_cart_outlined,
              const Color.fromARGB(255, 48, 63, 222),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BuyItemsPage()),
                ).then((_) => _fetchCounts());
              },
              badgeCount: pendingGuestMealCount,
            ),

           

            _adminCard(
              context,
              "Meal Subscriptions",
              Icons.food_bank_rounded,
              Colors.green.shade700,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MealSubscriptionsPage(),
                ),
              ),
              badgeCount: 0,
            ),
            _adminCard(
              context,
              "Complaints",
              Icons.feedback_outlined,
              const Color.fromARGB(255, 184, 204, 56),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ComplainsPage()),
              ).then((_) => _fetchCounts()),
              badgeCount: pendingComplaintCount,
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
    VoidCallback onTap, {
    int badgeCount = 0,
  }) {
    return Stack(
      children: [
        Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: color.withOpacity(0.2), width: 1),
          ),
          color: color.withOpacity(0.04),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 36, color: color),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 13,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 1.5),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  badgeCount > 99 ? '99+' : badgeCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
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
