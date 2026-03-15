import 'package:flutter/material.dart';

class CustomBottomNavbar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>
  onTap; // Using ValueChanged is a standard Flutter practice
  final bool isManager;

  const CustomBottomNavbar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.isManager,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Define the items list
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
      const BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
      if (isManager)
        const BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings),
          label: "Manager",
        ),
    ];

    // 2. Safety Check: Ensure the currentIndex never exceeds the actual list length
    // This prevents "Index out of range" crashes during state transitions.
    final safeIndex = currentIndex >= navItems.length ? 0 : currentIndex;

    return BottomNavigationBar(
      currentIndex: safeIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.deepPurple,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true, // Personal preference for better UX
      items: navItems,
    );
  }
}
