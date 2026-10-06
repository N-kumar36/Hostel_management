import 'package:HostelMess/views/managementControl/views/buyItemsAdd/buyItems.dart';
import 'package:HostelMess/views/managementControl/views/managerAssign/manager_assign_page.dart';
import 'package:HostelMess/views/managementControl/views/mealSubscription/MealSubscriptionsPage.dart';
import 'package:HostelMess/views/managementControl/views/financeManagement/fine_management_page.dart';
import 'package:HostelMess/views/managementControl/views/pendingStudent/PendingStudentsPage.dart';
import 'package:HostelMess/views/managementControl/views/setRoutine/RoutineManagementPage.dart';
import 'package:HostelMess/views/managementControl/views/serveMeal/ServeMealPage.dart';
import 'package:HostelMess/views/managementControl/views/voteStatus/VoteStatsPage.dart';
import 'package:HostelMess/views/managementControl/views/allStudent/all_hostel_student_page.dart';
import 'package:HostelMess/views/managementControl/views/createMeal/create_meal_page.dart';
import 'package:HostelMess/views/managementControl/views/guestMeal/GuestMealPage.dart';
import 'package:HostelMess/services/api_service.dart';
import 'package:flutter/material.dart';
import '../views/complains/ComplainsPage.dart';
import 'package:HostelMess/views/managementControl/views/polls/AdminPollManagementPage.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final ApiService api = ApiService();

  int pendingStudentCount = 0;
  int pendingGuestMealCount = 0;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchCounts();
  }

  // ------------------------------------------------------------
  // THEME
  // ------------------------------------------------------------

  Color get _background => Theme.of(context).scaffoldBackgroundColor;

  Color get _surface => Theme.of(context).colorScheme.surface;

  Color get _textPrimary => Theme.of(context).colorScheme.onSurface;

  Color get _textSecondary => Theme.of(context).colorScheme.onSurfaceVariant;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  // ------------------------------------------------------------
  // FETCH COUNTS
  // ------------------------------------------------------------

  Future<void> _fetchCounts() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final res = await api.getDashboardCounts();

      if (mounted && res['success'] == true) {
        setState(() {
          pendingStudentCount = res['pendingStudents'] ?? 0;
          pendingGuestMealCount = res['pendingGuests'] ?? 0;
          isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching counts: $e");

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ------------------------------------------------------------
  // NAVIGATION HELPER
  // ------------------------------------------------------------

  Future<void> _openPage(Widget page) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );

    if (mounted) {
      _fetchCounts();
    }
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,

      appBar: AppBar(
        elevation: 0,
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,

        titleSpacing: 20,

        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Admin Panel",
              style: TextStyle(
                color: _textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              "Manage your hostel operations",
              style: TextStyle(
                color: _textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),

        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            decoration: BoxDecoration(
              color: _isDark
                  ? const Color(0xFF20242C)
                  : const Color(0xFFF0F1F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              tooltip: "Refresh",
              onPressed: isLoading ? null : _fetchCounts,
              icon: isLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : Icon(Icons.refresh_rounded, color: _textPrimary, size: 21),
            ),
          ),
        ],
      ),

      body: RefreshIndicator(
        color: Theme.of(context).colorScheme.primary,
        backgroundColor: _surface,
        onRefresh: _fetchCounts,

        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),

          children: [
            // ----------------------------------------------------
            // HEADER
            // ----------------------------------------------------
            _buildWelcomeHeader(),

            const SizedBox(height: 18),

            // ----------------------------------------------------
            // MANAGEMENT LIST
            // ----------------------------------------------------
            _buildSectionTitle(
              "Management",
              "Quick access to hostel management tools",
            ),

            const SizedBox(height: 10),

            _adminCard(
              title: "Pending Students",
              description: "Review and approve new student registrations",
              icon: Icons.person_add_alt_1_rounded,
              color: Colors.green,
              badgeCount: pendingStudentCount,
              onTap: () {
                _openPage(const PendingStudentsPage());
              },
            ),

            _adminCard(
              title: "All Students",
              description: "View and manage all registered hostel students",
              icon: Icons.groups_rounded,
              color: Colors.deepPurple,
              onTap: () {
                _openPage(const AllHostelStudentPage());
              },
            ),

            _adminCard(
              title: "Set Hostel Routine",
              description: "Create and manage the daily hostel meal routine",
              icon: Icons.calendar_month_rounded,
              color: Colors.teal,
              onTap: () {
                _openPage(const RoutineManagementPage());
              },
            ),

            _adminCard(
              title: "Create / Cancel Meal",
              description: "Create and configure meals for the hostel",
              icon: Icons.restaurant_menu_rounded,
              color: const Color(0xFF22D3D0),
              onTap: () {
                _openPage(const MealManagementPage());
              },
            ),

            _adminCard(
              title: "Vote Stats",
              description: "Check student meal voting statistics",
              icon: Icons.bar_chart_rounded,
              color: Colors.blue,
              onTap: () {
                _openPage(const VoteStatusSelectionPage());
              },
            ),

            _adminCard(
              title: "Poll Management",
              description: "Create, schedule and manage student polls",
              icon: Icons.how_to_vote_rounded,
              color: const Color(0xFF7C3AED),
              onTap: () {
                _openPage(const AdminPollManagementPage());
              },
            ),

            _adminCard(
              title: "Serve Meals",
              description: "Manage voted students and mark meals as served",
              icon: Icons.restaurant_rounded,
              color: Colors.orange,
              onTap: () {
                _openPage(const ServeMealPage());
              },
            ),

            _adminCard(
              title: "Finance Management",
              description: "Manage fines, payments and financial records",
              icon: Icons.account_balance_wallet_rounded,
              color: Colors.red,
              onTap: () {
                _openPage(const FineManagementPage());
              },
            ),

            _adminCard(
              title: "Add Shopping Items",
              description: "Add and manage items available for shopping",
              icon: Icons.shopping_cart_rounded,
              color: const Color(0xFF303FDE),
              badgeCount: pendingGuestMealCount,
              onTap: () {
                _openPage(const BuyItemsPage());
              },
            ),

            _adminCard(
              title: "Guest Meal",
              description: "Manage guest meal requests and entries",
              icon: Icons.supervised_user_circle_rounded,
              color: const Color(0xFF36AEF4),
              badgeCount: pendingGuestMealCount,
              onTap: () {
                _openPage(const GuestMealPage());
              },
            ),

            _adminCard(
              title: "Meal Subscriptions",
              description: "View and manage student meal subscriptions",
              icon: Icons.food_bank_rounded,
              color: Colors.green,
              badgeCount: pendingGuestMealCount,
              onTap: () {
                _openPage(const MealSubscriptionsPage());
              },
            ),

            _adminCard(
              title: "Complaints",
              description: "Review complaints, suggestions and requests",
              icon: Icons.feedback_outlined,
              color: const Color(0xFFB8CC38),
              badgeCount: pendingGuestMealCount,
              onTap: () {
                _openPage(const ComplainsPage());
              },
            ),

            _adminCard(
              title: "Managers & Admin Assign",
              description: "Manage managers and administrator assignments",
              icon: Icons.manage_accounts_rounded,
              color: const Color(0xFFC81D1D),
              badgeCount: pendingGuestMealCount,
              onTap: () {
                _openPage(ManagerAssign());
              },
            ),

            const SizedBox(height: 12),

            // ----------------------------------------------------
            // FOOTER
            // ----------------------------------------------------
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // WELCOME HEADER
  // ------------------------------------------------------------

  Widget _buildWelcomeHeader() {
    final Color primary = Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary, const Color(0xFF3B32A0)],
        ),
        borderRadius: BorderRadius.circular(22),

        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(_isDark ? 0.28 : 0.20),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),

      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,

            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),

            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Welcome, Administrator",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  "Control and manage your hostel from one place.",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.78),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // SECTION TITLE
  // ------------------------------------------------------------

  Widget _buildSectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            title,
            style: TextStyle(
              color: _textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            subtitle,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // ADMIN LIST CARD
  // ------------------------------------------------------------

  Widget _adminCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),

      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),

        border: Border.all(
          color: _isDark ? const Color(0xFF2B303A) : const Color(0xFFE8E9F0),
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark ? 0.12 : 0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Material(
        color: Colors.transparent,

        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),

          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),

            child: Row(
              children: [
                // ----------------------------------------------
                // ICON
                // ----------------------------------------------
                Container(
                  width: 52,
                  height: 52,

                  decoration: BoxDecoration(
                    color: color.withOpacity(_isDark ? 0.16 : 0.10),
                    borderRadius: BorderRadius.circular(15),
                  ),

                  child: Icon(icon, color: color, size: 25),
                ),

                const SizedBox(width: 14),

                // ----------------------------------------------
                // TEXT
                // ----------------------------------------------
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,

                              style: TextStyle(
                                color: _textPrimary,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),

                          if (badgeCount > 0) ...[
                            const SizedBox(width: 8),

                            _buildBadge(badgeCount),
                          ],
                        ],
                      ),

                      const SizedBox(height: 4),

                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,

                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // ----------------------------------------------
                // ARROW
                // ----------------------------------------------
                Container(
                  width: 34,
                  height: 34,

                  decoration: BoxDecoration(
                    color: _isDark
                        ? const Color(0xFF20242C)
                        : const Color(0xFFF5F6FA),
                    shape: BoxShape.circle,
                  ),

                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: _textSecondary,
                    size: 21,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // BADGE
  // ------------------------------------------------------------

  Widget _buildBadge(int count) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),

      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),

      decoration: BoxDecoration(
        color: const Color(0xFFDC2626),
        borderRadius: BorderRadius.circular(20),

        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withOpacity(0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),

      child: Center(
        child: Text(
          count > 99 ? "99+" : count.toString(),

          style: const TextStyle(
            color: Colors.white,
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // FOOTER
  // ------------------------------------------------------------

  Widget _buildFooter() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),

        child: Column(
          children: [
            Icon(
              Icons.security_rounded,
              color: _textSecondary.withOpacity(0.5),
              size: 18,
            ),

            const SizedBox(height: 5),

            Text(
              "HostelMess Administration",
              style: TextStyle(
                color: _textSecondary.withOpacity(0.7),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 2),

            Text(
              "Management Control Panel",
              style: TextStyle(
                color: _textSecondary.withOpacity(0.45),
                fontSize: 9.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
