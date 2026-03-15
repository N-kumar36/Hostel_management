import 'dart:convert';

import 'package:HostelMess/screens/login_screens/login_page.dart';
import 'package:HostelMess/screens/main_screens/homepage.dart';
import 'package:flutter/material.dart';
import 'package:HostelMess/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Screens
import 'main_screens/weekly_meals_page.dart';
import 'main_screens/my_meals_page.dart';
import 'main_screens/profile_page.dart';
import 'main_screens/manager_panel_page.dart';
// Note: Ensure LoginPage is imported if you reference it
// import 'auth/login_page.dart';

import '../components/custom_bottom_navbar.dart';

class HomePage extends StatefulWidget {
  final bool isManager;

  const HomePage({super.key, this.isManager = false});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  // FIXED: Added missing semicolon
  final api = ApiService();

  // Logic moves here or to a controller/provider
  late bool isManager;

  @override
  void initState() {
    super.initState();
    // Initialize with the value passed from the constructor
    isManager = widget.isManager;
    // If you need to refresh it immediately, call your logic here
    _checkManagerStatus();
  }

  // 2. Fixed logic function (renamed from HomePage)
  Future<void> _checkManagerStatus() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString("token");

      if (token != null) {
        final profileData = await api.getProfile();

        if (profileData == null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        }

        bool result = false;

        if (profileData != null) {
          result = profileData['role'] == 'manager';
        } else {
          String? userStr = prefs.getString("User");
          if (userStr != null) {
            Map<String, dynamic> userMap = jsonDecode(userStr);
            result = userMap['role'] == 'manager';
          }
        }

        // 3. Update the UI state
        setState(() {
          isManager = result;
        });
      }
    } catch (e) {
      debugPrint("Error checking manager status: $e");
    }
  }

  // Logic Note:
  // You usually don't want _checkAuth inside the HomePage itself
  // if it redirects back to HomePage. That logic belongs in a
  // Splash Screen or a Root Wrapper. I have commented it out
  // to prevent navigation loops, but kept the logic if you need it.

  @override
  Widget build(BuildContext context) {
    // Pages list dynamically built based on role
    final List<Widget> pages = [
       const Homepage(),
      const WeeklyMealsPage(),
      const MyVotesPage(),
      const ProfilePage(),
      if (widget.isManager) const ManagerPanelPage(),
    ];

    return Scaffold(
      // IndexedStack preserves the state of each tab so they don't reload
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: CustomBottomNavbar(
        currentIndex: _currentIndex,
        isManager: widget.isManager,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
