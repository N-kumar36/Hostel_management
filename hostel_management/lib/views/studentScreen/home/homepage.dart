import 'package:HostelMess/views/studentScreen/complain/complainPage.dart';
import 'package:HostelMess/views/studentScreen/financeControlls/finance_views.dart';
import 'package:HostelMess/views/studentScreen/todaysVotes/allStudent_todaysVotes.dart';
import 'package:HostelMess/views/utility_screen/financials_page.dart';
import 'package:HostelMess/views/studentScreen/history/historyPage.dart';
import 'package:HostelMess/views/notificationScreen/notification_page.dart';
import 'package:HostelMess/views/studentScreen/messFinance/All_StudentPayment_Screen.dart';
import 'package:HostelMess/views/studentScreen/home/DailyMenuCard.dart';
import 'package:HostelMess/views/utility_screen/RoutineScreen.dart';
import 'package:HostelMess/views/studentScreen/profile/profile_page.dart';
import 'package:HostelMess/views/utility_screen/HostelRulesWidget.dart';
import 'package:HostelMess/views/utility_screen/meal_packages_section.dart';
import 'package:HostelMess/views/studentScreen/votes/weekly_meals_page.dart';
import 'package:HostelMess/services/api_service.dart';
import 'package:HostelMess/services/localServices.dart';
import 'package:HostelMess/views/studentScreen/active_students/active_students_page.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  final ApiService api = ApiService();
  final LocalService localService = LocalService();

  final GlobalKey<DailyMenuCardState> _menuCardKey =
      GlobalKey<DailyMenuCardState>();

  // ===========================================================================
  // BRAND COLORS
  // ===========================================================================

  static const Color primary = Color(0xFF5B4FE9);
  static const Color primaryDark = Color(0xFF4338CA);

  static const Color lightBackground = Color(0xFFF6F7FB);
  static const Color lightTextDark = Color(0xFF111827);
  static const Color lightTextGrey = Color(0xFF6B7280);

  // ===========================================================================
  // THEME HELPERS
  // ===========================================================================

  Color get _background => Theme.of(context).scaffoldBackgroundColor;

  Color get _surface => Theme.of(context).colorScheme.surface;

  Color get _textPrimary => Theme.of(context).colorScheme.onSurface;

  Color get _textSecondary => Theme.of(context).colorScheme.onSurfaceVariant;

  Color get _border {
    final brightness = Theme.of(context).brightness;

    return brightness == Brightness.dark
        ? const Color(0xFF292D38)
        : const Color(0xFFEAEAF0);
  }

  Color get _divider {
    final brightness = Theme.of(context).brightness;

    return brightness == Brightness.dark
        ? const Color(0xFF2A2E39)
        : const Color(0xFFE5E7EB);
  }

  Color get _softSurface {
    final brightness = Theme.of(context).brightness;

    return brightness == Brightness.dark
        ? const Color(0xFF20242D)
        : Colors.white;
  }

  Color get _softPrimary {
    final brightness = Theme.of(context).brightness;

    return brightness == Brightness.dark
        ? const Color(0xFF25243E)
        : const Color(0xFFEEF0FF);
  }

  Color get _progressBackground {
    final brightness = Theme.of(context).brightness;

    return brightness == Brightness.dark
        ? const Color(0xFF30343E)
        : const Color(0xFFEEF0F4);
  }

  Color get _shadowColor {
    final brightness = Theme.of(context).brightness;

    return brightness == Brightness.dark
        ? Colors.black.withOpacity(0.20)
        : Colors.black.withOpacity(0.025);
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  // ===========================================================================
  // STATE
  // ===========================================================================

  String studentName = "Student";

  int totalMealsThisMonth = 0;
  int mealsConsumed = 0;

  double pendingDuesTotal = 0.0;

  bool isStatsLoading = true;
  bool hasProcessingFines = false;

  // ===========================================================================
  // INIT
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  // ===========================================================================
  // DATA
  // ===========================================================================

  Future<void> _loadDashboardData() async {
    await Future.wait([_fetchProfileData(), _updateStats()]);
  }

  Future<void> _fetchProfileData() async {
    try {
      final data = await localService.fetchProfile();

      if (data != null && mounted) {
        setState(() {
          studentName = data['name'] ?? data['user']?['name'] ?? "Student";
        });
      }
    } catch (e) {
      debugPrint("Profile Error: $e");
    }
  }

  Future<void> _updateStats() async {
    try {
      final statsResponse = await api.getVoteSummary();

      int totalLimit = 0;
      int totalConsumed = 0;

      if (statsResponse['success'] == true &&
          statsResponse['data'] is List &&
          (statsResponse['data'] as List).isNotEmpty) {
        final subData = statsResponse['data'][0];

        final Map<String, dynamic> maxLimits = Map<String, dynamic>.from(
          subData['maxLimits'] ?? {},
        );

        final Map<String, dynamic> usage = Map<String, dynamic>.from(
          subData['usage'] ?? {},
        );

        maxLimits.forEach((key, value) {
          if (value is num) {
            totalLimit += value.toInt();
          }
        });

        usage.forEach((key, value) {
          if (value is num) {
            totalConsumed += value.toInt();
          }
        });
      }

      double totalPending = 0.0;
      bool processingFound = false;

      final fines = await api.getMyFines();

      if (fines != null) {
        for (final fine in fines) {
          final status = fine['status'].toString().toLowerCase();

          if (status == 'pending' || status == 'rejected') {
            totalPending += double.tryParse(fine['amount'].toString()) ?? 0.0;
          } else if (status == 'processing') {
            processingFound = true;
          }
        }
      }

      if (!mounted) return;

      setState(() {
        totalMealsThisMonth = totalLimit;
        mealsConsumed = totalConsumed;
        pendingDuesTotal = totalPending;
        hasProcessingFines = processingFound;
        isStatsLoading = false;
      });
    } catch (e) {
      debugPrint("Dashboard Stats Error: $e");

      if (mounted) {
        setState(() {
          isStatsLoading = false;
        });
      }
    }
  }

  Future<void> _handleRefresh() async {
    if (mounted) {
      setState(() {
        isStatsLoading = true;
      });
    }

    await _loadDashboardData();

    if (_menuCardKey.currentState != null) {
      await _menuCardKey.currentState!.fetchTodayData();
    }
  }

  // ===========================================================================
  // UX DESIGNER ACTIONS
  // ===========================================================================

  Future<void> _callDesigner() async {
    const String phoneNumber = '8016113479';

    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);

    try {
      final bool launched = await launchUrl(
        phoneUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        _showSnackBar('Unable to open the phone dialer.');
      }
    } catch (e) {
      debugPrint('Call launcher error: $e');

      if (mounted) {
        _showSnackBar('Unable to open the phone dialer.');
      }
    }
  }

  Future<void> _openDesignerPortfolio() async {
    final Uri portfolioUri = Uri.parse('https://debraj.edgeone.app');

    try {
      final bool launched = await launchUrl(
        portfolioUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        _showSnackBar('Unable to open portfolio.');
      }
    } catch (e) {
      debugPrint('Portfolio launcher error: $e');

      if (mounted) {
        _showSnackBar('Unable to open portfolio.');
      }
    }
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: RefreshIndicator(
          color: primary,
          backgroundColor: _surface,
          onRefresh: _handleRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),

              SliverToBoxAdapter(child: _buildQuickActions()),

              SliverToBoxAdapter(child: _buildMenuSection()),

              SliverToBoxAdapter(child: _buildMealSummary()),

              SliverToBoxAdapter(
                child: MealPackagesSection(onActionSuccess: _handleRefresh),
              ),

              if (pendingDuesTotal > 0 || hasProcessingFines)
                SliverToBoxAdapter(child: _buildFinancialSection()),

              SliverToBoxAdapter(child: _buildPaymentSection()),

              SliverToBoxAdapter(child: _buildRulesSection()),

              SliverToBoxAdapter(child: _buildUxDesignerCard()),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // HEADER
  // ===========================================================================

  Widget _buildHeader() {
    final firstName = studentName.trim().split(' ').first;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5146E5), Color(0xFF3B32A0)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(_isDark ? 0.30 : 0.24),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: const Icon(
                  Icons.home_work_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Hostel Dash",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      "Welcome back, $firstName",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),

              _buildNotificationButton(),
            ],
          ),

          const SizedBox(height: 22),

          Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                color: Colors.white70,
                size: 16,
              ),

              const SizedBox(width: 7),

              Text(
                DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now()),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationButton() {
    return Material(
      color: Colors.white.withOpacity(0.14),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationPage()),
          );
        },
        child: Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: const Icon(
            Icons.notifications_none_rounded,
            color: Colors.white,
            size: 23,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // QUICK ACTIONS
  // ===========================================================================

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            title: "Quick Access",
            subtitle: "Everything you need, right here",
          ),

          const SizedBox(height: 13),

          SizedBox(
            height: 112,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _buildQuickActionCard(
                  icon: Icons.how_to_vote_rounded,
                  title: "All Votes",
                  subtitle: "Students",
                  color: const Color(0xFFF59E0B),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AllStudentVotes(),
                      ),
                    ).then((_) => _handleRefresh());
                  },
                ),

                _buildQuickActionCard(
                  icon: Icons.history_rounded,
                  title: "My History",
                  subtitle: "Meals",
                  color: const Color(0xFF2563EB),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HistoryPage()),
                    ).then((_) => _handleRefresh());
                  },
                ),

                _buildQuickActionCard(
                  icon: Icons.groups_rounded,
                  title: "Active Students",
                  subtitle: "View students",
                  color: const Color(0xFF16A05D),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ActiveStudentsPage(),
                      ),
                    ).then((_) => _handleRefresh());
                  },
                ),

                _buildQuickActionCard(
                  icon: Icons.feedback_outlined,
                  title: "Complain",
                  subtitle: "Report issue",
                  color: const Color(0xFFEF4444),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ComplainPage()),
                    );
                  },
                ),

                _buildQuickActionCard(
                  icon: Icons.account_balance_wallet_outlined,
                  title: "Finance",
                  subtitle: "Overview",
                  color: const Color(0xFF0D9488),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FinanceViews()),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 125,
      margin: const EdgeInsets.only(right: 10),
      child: Material(
        color: _surface,
        borderRadius: BorderRadius.circular(19),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(19),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: _border),
              boxShadow: [
                if (!_isDark)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.015),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),

                const Spacer(),

                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: _textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TODAY'S MENU
  // ===========================================================================

  Widget _buildMenuSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 25),
      child: Column(
        children: [
          _buildSectionTitle(
            title: "Today's Menu",
            subtitle: "What's being served today",
            actionText: "View Routine",
            onAction: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RoutineScreen()),
              ).then((_) => _handleRefresh());
            },
          ),

          const SizedBox(height: 13),

          DailyMenuCard(key: _menuCardKey),
        ],
      ),
    );
  }

  // ===========================================================================
  // MEAL SUMMARY
  // ===========================================================================

  Widget _buildMealSummary() {
    final double progress = totalMealsThisMonth <= 0
        ? 0
        : (mealsConsumed / totalMealsThisMonth).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 25),
      child: Column(
        children: [
          _buildSectionTitle(
            title: "Meal Summary",
            subtitle: "Your monthly consumption",
            actionText: "History",
            onAction: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryPage()),
              ).then((_) => _handleRefresh());
            },
          ),

          const SizedBox(height: 13),

          Container(
            padding: const EdgeInsets.all(19),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: _shadowColor,
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: isStatsLoading
                ? _buildStatsLoading()
                : Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildMealStat(
                              icon: Icons.restaurant_rounded,
                              label: "Total Meals",
                              value: totalMealsThisMonth.toString(),
                              color: const Color(0xFF4F46E5),
                            ),
                          ),

                          Container(width: 1, height: 58, color: _divider),

                          Expanded(
                            child: _buildMealStat(
                              icon: Icons.done_all_rounded,
                              label: "Consumed",
                              value: mealsConsumed.toString(),
                              color: const Color(0xFF16A34A),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Consumption",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _textSecondary,
                            ),
                          ),

                          Text(
                            "${(progress * 100).round()}%",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _textPrimary,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: progress,
                          backgroundColor: _progressBackground,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            primary,
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          DateFormat('MMMM yyyy').format(DateTime.now()),
                          style: TextStyle(
                            fontSize: 11,
                            color: _textSecondary.withOpacity(0.75),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: color, size: 21),
        ),

        const SizedBox(width: 11),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
              ),
            ),

            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsLoading() {
    return const SizedBox(
      height: 135,
      child: Center(
        child: CircularProgressIndicator(strokeWidth: 2.5, color: primary),
      ),
    );
  }

  // ===========================================================================
  // FINANCIALS
  // ===========================================================================

  Widget _buildFinancialSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 25),
      child: Column(
        children: [
          _buildSectionTitle(title: "Financials", subtitle: "Payment status"),

          const SizedBox(height: 13),

          _buildPaymentCard(),
        ],
      ),
    );
  }

  Widget _buildPaymentCard() {
    final bool hasPending = pendingDuesTotal > 0;

    final Color accent = hasPending
        ? const Color(0xFF7C3AED)
        : const Color(0xFFD97706);

    final String title = hasPending
        ? "Pending Dues"
        : "Verification in Progress";

    final String subtitle = hasPending
        ? "Payment required"
        : "We're verifying your payment";

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FinancialsPage()),
          ).then((_) => _handleRefresh());
        },
        child: Container(
          padding: const EdgeInsets.all(19),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accent, accent.withOpacity(0.82)],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(_isDark ? 0.30 : 0.20),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  hasPending
                      ? Icons.account_balance_wallet_rounded
                      : Icons.hourglass_top_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    if (hasPending) ...[
                      const SizedBox(height: 5),
                      Text(
                        "₹${pendingDuesTotal.toStringAsFixed(0)}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.13),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // STUDENT PAYMENT STATUS
  // ===========================================================================

  Widget _buildPaymentSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 25),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _border),
          boxShadow: [
            if (!_isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.012),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5).withOpacity(_isDark ? 0.14 : 1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.groups_rounded,
                color: Color(0xFF059669),
                size: 22,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Student Payments",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _textPrimary,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    "View overall payment status",
                    style: TextStyle(
                      fontSize: 11,
                      color: _textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            Material(
              color: _softPrimary,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const StudentPaymentScreen(),
                  ).then((_) => _handleRefresh());
                },
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: primary,
                    size: 19,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // RULES
  // ===========================================================================

  Widget _buildRulesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            title: "Hostel Rules",
            subtitle: "Keep these in mind",
          ),

          const SizedBox(height: 13),

          // Existing widget is intentionally
          // preserved. It will use the global
          // theme once its own hardcoded colors
          // are converted.
          const HostelRulesWidget(),
        ],
      ),
    );
  }

  // ===========================================================================
  // UX DESIGNER CARD
  // ===========================================================================

  Widget _buildUxDesignerCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 25, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: _shadowColor,
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [primary, Color(0xFF8B7CF6)],
                    ),
                    borderRadius: BorderRadius.circular(17),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withOpacity(_isDark ? 0.30 : 0.20),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.design_services_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),

                const SizedBox(width: 13),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'UX DESIGNER',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: _textSecondary,
                          letterSpacing: 1.1,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        'Debraj Pratihar',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: _textPrimary,
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        'UI/UX • Product Experience',
                        style: TextStyle(
                          fontSize: 10,
                          color: _textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: _softPrimary,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: primary,
                    size: 17,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Container(height: 1, color: _divider),

            const SizedBox(height: 13),

            Row(
              children: [
                Expanded(
                  child: _buildDesignerContact(
                    icon: Icons.phone_rounded,
                    title: 'Call',
                    value: '8016113479',
                    color: const Color(0xFF16A05D),
                    onTap: _callDesigner,
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: _buildDesignerContact(
                    icon: Icons.language_rounded,
                    title: 'Portfolio',
                    value: 'debraj.edgeone.app',
                    color: const Color(0xFF2563EB),
                    onTap: _openDesignerPortfolio,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // DESIGNER CONTACT ITEM
  // ===========================================================================

  Widget _buildDesignerContact({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(_isDark ? 0.10 : 0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 17),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 4),

              Icon(Icons.open_in_new_rounded, size: 13, color: color),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // SECTION TITLE
  // ===========================================================================

  Widget _buildSectionTitle({
    required String title,
    String? subtitle,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: _textPrimary,
                ),
              ),

              if (subtitle != null) ...[
                const SizedBox(height: 3),

                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: _textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),

        if (actionText != null)
          GestureDetector(
            onTap: onAction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: _softPrimary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionText,
                    style: const TextStyle(
                      color: primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(width: 3),

                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: primary,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ===========================================================================
  // SNACKBAR
  // ===========================================================================

  void _showSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onInverseSurface,
            ),
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      );
  }
}
