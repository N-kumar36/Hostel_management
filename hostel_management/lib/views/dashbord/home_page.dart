import 'dart:convert';

import 'package:HostelMess/views/auth/login/login_page.dart';
import 'package:HostelMess/views/managementControl/adminScreens/admin_screen.dart';
import 'package:HostelMess/views/studentScreen/home/homepage.dart';
import 'package:flutter/material.dart';
import 'package:HostelMess/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Screens
import '../studentScreen/votes/weekly_meals_page.dart';
import '../studentScreen/myMeals/my_meals_page.dart';
import '../studentScreen/profile/profile_page.dart';
import '../managementControl/managerScreens/manager_panel_page.dart';
import '../managementControl/cookControl/CookPanelPage.dart';

class HomePage extends StatefulWidget {
  final bool isManager;
  final bool isAdmin;
  final bool isCook;

  const HomePage({
    super.key,
    this.isManager = false,
    this.isAdmin = false,
    this.isCook = false,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final ApiService api = ApiService();

  late bool isManager;
  late bool isAdmin;
  late bool isCook;

  @override
  void initState() {
    super.initState();

    isManager = widget.isManager;
    isAdmin = widget.isAdmin;
    isCook = widget.isCook;

    _checkManagerStatus();
  }

  // ============================================================
  // CHECK USER ROLE
  // ============================================================

  Future<void> _checkManagerStatus() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final String? token = prefs.getString("token");

      if (token == null || token.isEmpty) {
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );

        return;
      }

      final profileData = await api.getProfile();

      bool newManagerStatus = false;
      bool newAdminStatus = false;
      bool newCookStatus = false;

      if (profileData != null) {
        newManagerStatus = profileData['role'] == 'manager';

        newAdminStatus = profileData['role'] == 'admin';
        newCookStatus = profileData['role'] == 'cook';
      } else {
        // Fallback to locally cached user
        final String? userStr = prefs.getString("User");

        if (userStr != null && userStr.isNotEmpty) {
          final Map<String, dynamic> userMap = jsonDecode(userStr);

          newManagerStatus = userMap['role'] == 'manager';

          newAdminStatus = userMap['role'] == 'admin';

          newCookStatus = userMap['role'] == 'cook';
        } else {
          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          );

          return;
        }
      }

      if (!mounted) return;

      if (isManager != newManagerStatus ||
          isAdmin != newAdminStatus ||
          isCook != newCookStatus) {
        setState(() {
          isManager = newManagerStatus;
          isAdmin = newAdminStatus;
          isCook = newCookStatus;

          // Reset to Home whenever role-based
          // navigation structure changes.
          _currentIndex = 0;
        });
      }
    } catch (e) {
      debugPrint("Error checking user role: $e");
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const Homepage(),
      const WeeklyMealsPage(),
      const MyVotesPage(),
      const ProfilePage(),

      if (isManager) const ManagerPanelPage(),

      if (isCook) const CookPanelPage(),

      if (isAdmin) const AdminScreen(),
    ];

    final int safeIndex = _currentIndex >= pages.length ? 0 : _currentIndex;

    return Scaffold(
      extendBody: true,

      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      body: IndexedStack(index: safeIndex, children: pages),

      bottomNavigationBar: CustomBottomNavbar(
        currentIndex: safeIndex,
        isManager: isManager,
        isCook: isCook,
        isAdmin: isAdmin,
        onTap: (index) {
          if (index >= pages.length) return;

          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

// ================================================================
// MODERN BOTTOM NAVIGATION BAR
// ================================================================

class CustomBottomNavbar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  final bool isManager;
  final bool isCook;
  final bool isAdmin;

  const CustomBottomNavbar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.isManager,
    required this.isCook,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final bool isDark = theme.brightness == Brightness.dark;

    final List<_NavItem> navItems = [
      const _NavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: "Home",
      ),

      const _NavItem(
        icon: Icons.restaurant_menu_outlined,
        activeIcon: Icons.restaurant_menu_rounded,
        label: "Votes",
      ),

      const _NavItem(
        icon: Icons.menu_book_outlined,
        activeIcon: Icons.menu_book_rounded,
        label: "My Meals",
      ),

      const _NavItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: "Profile",
      ),

      if (isManager)
        const _NavItem(
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard_rounded,
          label: "Manager",
          special: true,
        ),

      if (isCook)
        const _NavItem(
          icon: Icons.restaurant_outlined,
          activeIcon: Icons.restaurant_rounded,
          label: "Cook",
          special: true,
        ),

      if (isAdmin)
        const _NavItem(
          icon: Icons.admin_panel_settings_outlined,
          activeIcon: Icons.admin_panel_settings_rounded,
          label: "Admin",
          special: true,
        ),
    ];

    final int safeIndex = currentIndex >= navItems.length ? 0 : currentIndex;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          height: 72,

          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111827) : Colors.white,

            borderRadius: BorderRadius.circular(24),

            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(.07)
                  : Colors.black.withOpacity(.05),
            ),

            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? .30 : .10),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),

          child: Row(
            children: List.generate(navItems.length, (index) {
              return Expanded(
                child: _buildNavItem(
                  context,
                  navItems[index],
                  index,
                  safeIndex == index,
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // NAV ITEM
  // ============================================================

  Widget _buildNavItem(
    BuildContext context,
    _NavItem item,
    int index,
    bool selected,
  ) {
    final ThemeData theme = Theme.of(context);

    final bool isDark = theme.brightness == Brightness.dark;

    final Color activeColor = item.special
        ? const Color(0xFF06B6D4)
        : const Color(0xFF6366F1);

    final Color inactiveColor = isDark
        ? Colors.white.withOpacity(.45)
        : Colors.black.withOpacity(.45);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(index),

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),

        curve: Curves.easeOutCubic,

        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),

        decoration: BoxDecoration(
          color: selected ? activeColor.withOpacity(.11) : Colors.transparent,

          borderRadius: BorderRadius.circular(17),

          border: selected
              ? Border.all(color: activeColor.withOpacity(.12))
              : null,
        ),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),

              transitionBuilder: (child, animation) {
                return ScaleTransition(scale: animation, child: child);
              },

              child: Icon(
                selected ? item.activeIcon : item.icon,

                key: ValueKey(selected),

                size: selected ? 23 : 21,

                color: selected ? activeColor : inactiveColor,
              ),
            ),

            const SizedBox(height: 4),

            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),

              style: TextStyle(
                color: selected ? activeColor : inactiveColor,

                fontSize: selected ? 10.5 : 10,

                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),

              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// NAV ITEM MODEL
// ================================================================

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool special;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.special = false,
  });
}
