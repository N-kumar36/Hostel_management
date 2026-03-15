import 'package:HostelMess/screens/homePagesScreen/complainPage.dart';
import 'package:HostelMess/screens/homePagesScreen/financials_page.dart';
import 'package:HostelMess/screens/homePagesScreen/historyPage.dart';
import 'package:HostelMess/screens/homePagesScreen/notification_page.dart';
import 'package:HostelMess/screens/homePagesScreen/utilityFunction/DailyMenuCard.dart';
import 'package:HostelMess/screens/homePagesScreen/utilityFunction/RoutineScreen.dart';
import 'package:HostelMess/screens/main_screens/profile_page.dart';
import 'package:HostelMess/screens/main_screens/weekly_meals_page.dart';
import 'package:HostelMess/services/api_service.dart';
import 'package:HostelMess/services/localServices.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  final api = ApiService();
  final L_S = LocalService(); 
  final themeColor = Colors.deepPurple;

  final GlobalKey<DailyMenuCardState> _menuCardKey = GlobalKey<DailyMenuCardState>();

  String studentName = "Student";
  int totalMealsThisMonth = 0;
  int mealsConsumed = 0;
  double pendingDuesTotal = 0.0; 
  bool isStatsLoading = true;
  bool hasProcessingFines = false; // New flag

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    await Future.wait([_fetchProfileData(), _updateStats()]);
  }

  Future<void> _fetchProfileData() async {
    final data = await L_S.fetchProfile();
    if (data != null && mounted) {
      setState(() {
        studentName = data['name'] ?? data['user']?['name'] ?? "Student";
      });
    }
  }

  Future<void> _updateStats() async {
    final stats = await L_S.fetchAndCalculateMealStats();
    
    double totalPending = 0.0;
    bool processingFound = false;
    try {
      final fines = await api.getMyFines();
      for (var fine in fines) {
        String status = fine['status'].toString().toLowerCase();
        if (status == 'pending') {
          totalPending += double.tryParse(fine['amount'].toString()) ?? 0.0;
        } else if (status == 'processing') {
          processingFound = true; // Still show section if verification is pending
        }
      }
    } catch (e) {
      debugPrint("Error fetching fines: $e");
    }

    if (mounted) {
      setState(() {
        totalMealsThisMonth = stats['total'] ?? 0;
        mealsConsumed = stats['consumed'] ?? 0;
        pendingDuesTotal = totalPending;
        hasProcessingFines = processingFound;
        isStatsLoading = false;
      });
    }
  }

  Future<void> _handleRefresh() async {
    setState(() => isStatsLoading = true);
    await _loadDashboardData();
    if (_menuCardKey.currentState != null) {
      await _menuCardKey.currentState!.fetchTodayData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Hostel Dash", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            Text("Welcome, $studentName", style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        backgroundColor: themeColor,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationPage())),
            icon: const Icon(Icons.notifications_active, color: Colors.white),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: themeColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildQuickActions(),
              const SizedBox(height: 24),
              _buildSectionHeader(
                "Today's Menu",
                "View Routine",
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const WeeklyRoutineModal(),
                  ).then((_) => _handleRefresh());
                },
              ),
              DailyMenuCard(key: _menuCardKey),
              const SizedBox(height: 24),
              _buildSectionHeader("Meal Summary", DateFormat('MMMM yyyy').format(DateTime.now())),
              if (isStatsLoading)
                const LinearProgressIndicator()
              else
                Row(
                  children: [
                    _buildStatCard("Total Meals", "$totalMealsThisMonth", Icons.restaurant, Colors.blue),
                    const SizedBox(width: 12),
                    _buildStatCard("Consumed", "$mealsConsumed", Icons.done_all, Colors.green),
                  ],
                ),

              // --- FIXED FINANCIALS SECTION ---
              if (pendingDuesTotal > 0 || hasProcessingFines) ...[
                const SizedBox(height: 24),
                _buildSectionHeader("Financials", null),
                _buildPaymentCard(),
              ],
              // --------------------------------

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  // ... (Keep your existing _buildQuickActions, _buildActionItem, _buildSectionHeader, _buildStatCard)

  Widget _buildActionItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String? actionText, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (actionText != null)
            GestureDetector(
              onTap: onTap,
              child: Text(actionText, style: TextStyle(color: themeColor, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildActionItem(Icons.how_to_vote, "Vote", Colors.orange, () => 
          Navigator.push(context, MaterialPageRoute(builder: (context) => const WeeklyMealsPage())).then((_) => _handleRefresh())),
        _buildActionItem(Icons.history, "History", Colors.blue, () => 
          Navigator.push(context, MaterialPageRoute(builder: (context) => const HistoryPage())).then((_) => _handleRefresh())),
        _buildActionItem(Icons.feedback_outlined, "Complain", Colors.red, () => 
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ComplainPage()))),
        _buildActionItem(Icons.person_outline, "Profile", Colors.teal, () => 
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage()))),
      ],
    );
  }

  Widget _buildPaymentCard() {
    // If pending is 0 but has processing, change UI message
    String label = pendingDuesTotal > 0 ? "Pending Dues" : "Verification in Progress";
    Color bgColor = pendingDuesTotal > 0 ? themeColor : Colors.orange;

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const FinancialsPage()))
            .then((_) => _handleRefresh());
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [bgColor, bgColor.withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 4),
                Text(
                  "₹${pendingDuesTotal.toStringAsFixed(0)}", 
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}