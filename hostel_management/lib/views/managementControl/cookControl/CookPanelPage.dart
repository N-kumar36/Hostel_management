import 'package:flutter/material.dart';

import 'package:HostelMess/views/managementControl/views/allStudent/all_hostel_student_page.dart';
import 'package:HostelMess/views/managementControl/views/createMeal/create_meal_page.dart';
import 'package:HostelMess/views/managementControl/views/guestMeal/GuestMealPage.dart';
import 'package:HostelMess/views/managementControl/views/serveMeal/ServeMealPage.dart';
import 'package:HostelMess/views/managementControl/views/voteStatus/VoteStatsPage.dart';

class CookPanelPage extends StatefulWidget {
  const CookPanelPage({super.key});

  @override
  State<CookPanelPage> createState() => _CookPanelPageState();
}

class _CookPanelPageState extends State<CookPanelPage> {
  static const Color primary = Color(0xFF5146E5);
  static const Color primaryDark = Color(0xFF3B32A0);

  static const Color green = Color(0xFF16A34A);
  static const Color blue = Color(0xFF2563EB);
  static const Color orange = Color(0xFFF59E0B);
  static const Color cyan = Color(0xFF0891B2);
  static const Color purple = Color(0xFF7C3AED);

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _background => Theme.of(context).scaffoldBackgroundColor;

  Color get _surface => Theme.of(context).colorScheme.surface;

  Color get _textPrimary => Theme.of(context).colorScheme.onSurface;

  Color get _textSecondary => Theme.of(context).colorScheme.onSurfaceVariant;

  Color get _border => Theme.of(context).dividerColor;

  Color get _subtleSurface =>
      _isDark ? const Color(0xFF20242C) : const Color(0xFFF4F5FA);

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
                Icons.restaurant_rounded,
                color: Colors.white,
                size: 21,
              ),
            ),

            const SizedBox(width: 11),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Cook Panel",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: _textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),

                Text(
                  "HostelMess Kitchen Operations",
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
      ),

      body: SafeArea(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),

          padding: EdgeInsets.fromLTRB(
            14,
            14,
            14,
            30 + MediaQuery.of(context).padding.bottom,
          ),

          children: [
            _buildWelcomeCard(),

            const SizedBox(height: 22),

            _buildSectionHeader(
              title: "Kitchen Operations",
              subtitle: "Manage daily meal activities",
            ),

            const SizedBox(height: 9),

            _buildManagementList(
              children: [
                _managementTile(
                  title: "All Students",
                  subtitle: "View hostel students and student information",
                  icon: Icons.groups_rounded,
                  color: primary,
                  onTap: () {
                    _openPage(const AllHostelStudentPage());
                  },
                ),

                _managementTile(
                  title: "Create Meal",
                  subtitle: "Create and manage daily meal schedules",
                  icon: Icons.restaurant_menu_rounded,
                  color: cyan,
                  onTap: () {
                    _openPage(const MealManagementPage());
                  },
                ),

                _managementTile(
                  title: "Guest Meals",
                  subtitle: "Manage guest meal requests",
                  icon: Icons.supervised_user_circle_rounded,
                  color: green,
                  onTap: () {
                    _openPage(const GuestMealPage());
                  },
                ),

                _managementTile(
                  title: "Serve Meals",
                  subtitle: "Serve meals and track student serving status",
                  icon: Icons.restaurant_rounded,
                  color: orange,
                  onTap: () {
                    _openPage(const ServeMealPage());
                  },
                ),

                _managementTile(
                  title: "Vote Status",
                  subtitle: "View student meal voting information",
                  icon: Icons.bar_chart_rounded,
                  color: blue,
                  onTap: () {
                    _openPage(const VoteStatusSelectionPage());
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            _buildInfoCard(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  Future<void> _openPage(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    if (!mounted) return;

    setState(() {});
  }

  // ============================================================
  // WELCOME CARD
  // ============================================================

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary, primaryDark],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(_isDark ? 0.30 : 0.20),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: const Icon(
              Icons.soup_kitchen_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),

          const SizedBox(width: 13),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Welcome, Cook",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                SizedBox(height: 4),

                Text(
                  "Manage meals, serving and guest operations from one place.",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
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
  // MANAGEMENT LIST
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.25,
                        fontWeight: FontWeight.w500,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

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

  // ============================================================
  // INFORMATION CARD
  // ============================================================

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _subtleSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: purple.withOpacity(_isDark ? 0.16 : 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: purple,
              size: 19,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              "Cook access is limited to daily kitchen and meal operations. "
              "Manager-only financial, approval and administrative features "
              "are not available from this panel.",
              style: TextStyle(
                color: _textSecondary,
                fontSize: 10.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
