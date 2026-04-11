import 'dart:convert';

import 'package:HostelMess/screens/login_screens/login_page.dart';
import 'package:HostelMess/screens/main_screens/admin_screen.dart';
import 'package:HostelMess/screens/main_screens/homepage.dart'; // Ensure this matches your file name
import 'package:flutter/material.dart';
import 'package:HostelMess/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Screens
import 'main_screens/weekly_meals_page.dart';
import 'main_screens/my_meals_page.dart';
import 'main_screens/profile_page.dart';
import 'main_screens/manager_panel_page.dart';

class HomePage extends StatefulWidget {
  final bool isManager;
  final bool isAdmin;

  const HomePage({super.key, this.isManager = false, this.isAdmin = false});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final api = ApiService();

  // State variables to hold the current role
  late bool isManager;
  late bool isAdmin;

  @override
  void initState() {
    super.initState();
    // 1. Initialize with the values passed from SplashScreen
    isManager = widget.isManager;
    isAdmin = widget.isAdmin;
    
    // 2. Fetch fresh data in the background just to be safe
    _checkManagerStatus();
  }

  Future<void> _checkManagerStatus() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString("token");

      if (token != null) {
        final profileData = await api.getProfile();

        bool newManagerStatus = false;
        bool newAdminStatus = false;

        if (profileData != null) {
          newManagerStatus = profileData['role'] == 'manager';
          newAdminStatus = profileData['role'] == 'admin';
        } else {
          // Fallback to local storage if API fails
          String? userStr = prefs.getString("User");
          if (userStr != null) {
            Map<String, dynamic> userMap = jsonDecode(userStr);
            newManagerStatus = userMap['role'] == 'manager';
            newAdminStatus = userMap['role'] == 'admin';
          } else {
            // Token exists but no data, send to login
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            }
            return;
          }
        }

        // 3. ✨ FIXED: Only update state if the roles actually changed
        if (mounted && (isManager != newManagerStatus || isAdmin != newAdminStatus)) {
          setState(() {
            isManager = newManagerStatus;
            isAdmin = newAdminStatus;
            _currentIndex = 0; // Reset to home tab to prevent index crashes
          });
        }
      }
    } catch (e) {
      debugPrint("Error checking manager status: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✨ FIXED: Now using the local state variables (isManager, isAdmin) 
    // instead of widget.isManager. This ensures UI updates instantly!
    final List<Widget> pages = [
      const Homepage(),
      const WeeklyMealsPage(),
      const MyVotesPage(),
      const ProfilePage(),
      if (isManager) const ManagerPanelPage(),
      if (isAdmin) const AdminScreen(),
    ];

    // ✨ FIXED: Added a safe index check for IndexedStack. 
    // If roles change while on tab 5, it safely bumps them back to tab 0 instead of crashing.
    final int safeIndex = _currentIndex >= pages.length ? 0 : _currentIndex;

    return Scaffold(
      body: IndexedStack(index: safeIndex, children: pages),
      bottomNavigationBar: CustomBottomNavbar(
        currentIndex: safeIndex,
        isManager: isManager, // Passing the state variable
        isAdmin: isAdmin,     // Passing the state variable
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}


// ==========================================
// CUSTOM BOTTOM NAVBAR
// ==========================================
class CustomBottomNavbar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap; 
  final bool isManager;
  final bool isAdmin;

  const CustomBottomNavbar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.isManager,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Dynamically build the items list based on roles
    final List<BottomNavigationBarItem> navItems = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        label: "Home",
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.restaurant_menu),
        label: "Votes",
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.menu_book_rounded),
        label: "My Meals",
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person), 
        label: "Profile",
      ),
      if (isManager)
        const BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings),
          label: "Manager",
        ),
      if (isAdmin)
        const BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings),
          label: "Admin",
        ),
    ];

    final safeIndex = currentIndex >= navItems.length ? 0 : currentIndex;

    return BottomNavigationBar(
      currentIndex: safeIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed, // Fixed type prevents icons from shifting/hiding
      selectedItemColor: Colors.deepPurple,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true, 
      items: navItems,
    );
  }
}