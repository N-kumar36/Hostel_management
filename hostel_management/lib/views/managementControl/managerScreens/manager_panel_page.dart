import 'package:flutter/material.dart';
import 'package:HostelMess/services/api_service.dart';

import 'package:HostelMess/views/managementControl/views/buyItemsAdd/buyItems.dart';
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
  final ApiService api = ApiService();

  int pendingStudentCount = 0;
  int pendingGuestMealCount = 0;
  int pendingComplaintCount = 0;
  int pendingFineCount = 0;

  bool isScreenLoading = false;

  // ============================================================
  // COLORS
  // ============================================================

  static const Color primary = Color(0xFF5146E5);
  static const Color primaryDark = Color(0xFF3B32A0);

  static const Color green = Color(0xFF16A34A);
  static const Color blue = Color(0xFF2563EB);
  static const Color orange = Color(0xFFF59E0B);
  static const Color red = Color(0xFFDC2626);
  static const Color teal = Color(0xFF0D9488);
  static const Color cyan = Color(0xFF0891B2);
  static const Color lime = Color(0xFF84A11D);

  // ============================================================
  // THEME HELPERS
  // ============================================================

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _background => Theme.of(context).scaffoldBackgroundColor;

  Color get _surface => Theme.of(context).colorScheme.surface;

  Color get _textPrimary => Theme.of(context).colorScheme.onSurface;

  Color get _textSecondary => Theme.of(context).colorScheme.onSurfaceVariant;

  Color get _border => Theme.of(context).dividerColor;

  Color get _subtleSurface =>
      _isDark ? const Color(0xFF20242C) : const Color(0xFFF4F5FA);

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _fetchCounts();
  }

  // ============================================================
  // FETCH COUNTS
  // ============================================================

  Future<void> _fetchCounts() async {
    if (isScreenLoading) return;

    setState(() {
      isScreenLoading = true;
    });

    try {
      final res = await api.getDashboardCounts();

      if (mounted && res['success'] == true) {
        setState(() {
          pendingStudentCount = res['pendingStudents'] ?? 0;

          pendingGuestMealCount = res['pendingGuests'] ?? 0;

          pendingComplaintCount = res['pendingComplaints'] ?? 0;

          pendingFineCount = res['pendingFines'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint("Error loading dashboard counters: $e");
    } finally {
      if (mounted) {
        setState(() {
          isScreenLoading = false;
        });
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,

      appBar: AppBar(
        elevation: 0,
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _textPrimary,

        titleSpacing: 18,

        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [primary, primaryDark],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.dashboard_rounded,
                color: Colors.white,
                size: 21,
              ),
            ),

            const SizedBox(width: 11),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Manager Panel",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),

                Text(
                  "HostelMess Management",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),

        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: _subtleSurface,
              borderRadius: BorderRadius.circular(11),
            ),
            child: IconButton(
              tooltip: "Refresh",
              onPressed: isScreenLoading ? null : _fetchCounts,
              icon: isScreenLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: primary,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded, color: primary, size: 21),
            ),
          ),
        ],
      ),

      // ==========================================================
      // SAFE AREA
      // ==========================================================
      body: SafeArea(
        bottom: true,

        child: RefreshIndicator(
          onRefresh: _fetchCounts,
          color: primary,

          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),

            padding: EdgeInsets.fromLTRB(
              14,
              14,
              14,
              30 + MediaQuery.of(context).padding.bottom,
            ),

            children: [
              // ==================================================
              // STUDENT & MEAL MANAGEMENT
              // ==================================================
              _buildSectionHeader(
                title: "Student & Meal Management",
                subtitle: "Students, meals and daily operations",
              ),

              const SizedBox(height: 9),

              _buildManagementList(
                children: [
                  _managementTile(
                    title: "Pending Students",
                    subtitle: "Review and approve student registrations",
                    icon: Icons.person_add_alt_1_rounded,
                    color: green,
                    badgeCount: pendingStudentCount,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PendingStudentsPage(),
                      ),
                    ).then((_) => _fetchCounts()),
                  ),

                  _managementTile(
                    title: "All Students",
                    subtitle: "View and manage all hostel students",
                    icon: Icons.groups_rounded,
                    color: primary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AllHostelStudentPage(),
                      ),
                    ),
                  ),

                  _managementTile(
                    title: "Hostel Routine",
                    subtitle: "Set and manage the weekly mess routine",
                    icon: Icons.calendar_month_rounded,
                    color: teal,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RoutineManagementPage(),
                      ),
                    ),
                  ),

                  _managementTile(
                    title: "Create Meal",
                    subtitle: "Create and manage meal schedules",
                    icon: Icons.restaurant_menu_rounded,
                    color: cyan,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MealManagementPage(),
                      ),
                    ),
                  ),

                  _managementTile(
                    title: "Vote Stats",
                    subtitle: "View student meal voting statistics",
                    icon: Icons.bar_chart_rounded,
                    color: blue,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VoteStatusSelectionPage(),
                      ),
                    ),
                  ),

                  _managementTile(
                    title: "Serve Meals",
                    subtitle: "Serve meals and track serving status",
                    icon: Icons.restaurant_rounded,
                    color: orange,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ServeMealPage()),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              // ==================================================
              // FINANCE & SERVICES
              // ==================================================
              _buildSectionHeader(
                title: "Finance & Services",
                subtitle: "Payments, subscriptions and guest services",
              ),

              const SizedBox(height: 9),

              _buildManagementList(
                children: [
                  _managementTile(
                    title: "Guest Meals",
                    subtitle: "Review and manage guest meal requests",
                    icon: Icons.supervised_user_circle_rounded,
                    color: cyan,
                    badgeCount: pendingGuestMealCount,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const GuestMealPage()),
                    ).then((_) => _fetchCounts()),
                  ),

                  _managementTile(
                    title: "Finance Management",
                    subtitle: "Manage fines, payments and approvals",
                    icon: Icons.account_balance_wallet_rounded,
                    color: red,
                    badgeCount: pendingFineCount,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FineManagementPage(),
                      ),
                    ).then((_) => _fetchCounts()),
                  ),

                  _managementTile(
                    title: "Shopping Items",
                    subtitle: "Manage items required for the mess",
                    icon: Icons.shopping_bag_rounded,
                    color: primary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BuyItemsPage()),
                    ).then((_) => _fetchCounts()),
                  ),

                  _managementTile(
                    title: "Meal Packages",
                    subtitle: "Manage student meal subscriptions",
                    icon: Icons.inventory_2_rounded,
                    color: green,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MealSubscriptionsPage(),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              // ==================================================
              // COMMUNICATION
              // ==================================================
              _buildSectionHeader(
                title: "Communication",
                subtitle: "Handle complaints and student requests",
              ),

              const SizedBox(height: 9),

              _buildManagementList(
                children: [
                  _managementTile(
                    title: "Complaints",
                    subtitle: "Review complaints and student requests",
                    icon: Icons.support_agent_rounded,
                    color: lime,
                    badgeCount: pendingComplaintCount,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ComplainsPage()),
                    ).then((_) => _fetchCounts()),
                  ),
                ],
              ),

              // ==================================================
              // EXTRA BOTTOM SPACE
              // ==================================================
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SECTION HEADER
  // ============================================================

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: _textPrimary,
              letterSpacing: -0.25,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LIST CONTAINER
  // ============================================================

  Widget _buildManagementList({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.08 : 0.025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),

        child: Column(
          children: [
            for (int i = 0; i < children.length; i++) ...[
              children[i],

              if (i != children.length - 1)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 75,
                  endIndent: 14,
                  color: _border,
                ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MANAGEMENT TILE
  // ============================================================

  Widget _managementTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return Material(
      color: Colors.transparent,

      child: InkWell(
        onTap: onTap,

        borderRadius: BorderRadius.circular(18),

        splashColor: color.withOpacity(0.08),

        highlightColor: color.withOpacity(0.04),

        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),

          child: Row(
            children: [
              // ==================================================
              // ICON
              // ==================================================
              Container(
                width: 48,
                height: 48,

                decoration: BoxDecoration(
                  color: color.withOpacity(_isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),

                child: Icon(icon, color: color, size: 22),
              ),

              const SizedBox(width: 13),

              // ==================================================
              // TEXT
              // ==================================================
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,

                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,

                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // ==================================================
              // BADGE
              // ==================================================
              if (badgeCount > 0)
                Container(
                  constraints: const BoxConstraints(
                    minWidth: 25,
                    minHeight: 25,
                  ),

                  padding: const EdgeInsets.symmetric(horizontal: 6),

                  decoration: BoxDecoration(
                    color: red,
                    shape: BoxShape.circle,

                    boxShadow: [
                      BoxShadow(
                        color: red.withOpacity(0.22),
                        blurRadius: 7,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),

                  child: Center(
                    child: Text(
                      badgeCount > 99 ? "99+" : badgeCount.toString(),

                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),

              if (badgeCount > 0) const SizedBox(width: 8),

              // ==================================================
              // ARROW
              // ==================================================
              Container(
                width: 30,
                height: 30,

                decoration: BoxDecoration(
                  color: color.withOpacity(_isDark ? 0.10 : 0.055),
                  shape: BoxShape.circle,
                ),

                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
