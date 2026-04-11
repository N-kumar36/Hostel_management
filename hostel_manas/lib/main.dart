import 'package:HostelMess/screens/home_page.dart';
import 'package:HostelMess/services/dataconnvater.dart';
import 'package:flutter/material.dart';
import 'screens/login_screens/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const HostelApp());

class HostelApp extends StatelessWidget {
  const HostelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true, 
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.light,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  final dataConvert = Dataconnvater();
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Initialize Controller with a smooth duration
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // 2. Setup smooth, layered animations
    _fadeAnimation = CurvedAnimation(
      parent: _controller, 
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.8, curve: Curves.elasticOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller, 
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutBack),
    ));

    // 3. Start Animation
    _controller.forward();
    
    // 4. Run Auth Check
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Determine the minimum time the splash must stay visible
    // We wait for the animation controller to finish + a small buffer
    await Future.delayed(const Duration(seconds: 2));

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString("token");

      if (token == null || token.isEmpty) {
        if (mounted) _navigateTo(const LoginPage());
        return;
      }

      // Fetch user profile
      final profileData = await dataConvert.getUserData();

      if (profileData != null) {
        bool isManager = profileData['role'] == 'manager';
        bool isAdmin = profileData['role'] == 'admin';
        if (mounted) _navigateTo(HomePage(isManager: isManager, isAdmin: isAdmin));
      } else {
        // Token exists but data fetch failed (expired session)
        if (mounted) _navigateTo(const LoginPage());
      }
    } catch (e) {
      debugPrint("Auth Check Error: $e");
      if (mounted) _navigateTo(const LoginPage());
    }
  }

  void _navigateTo(Widget page) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xff6A11CB), Color(0xFF2575FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Background Decorative Circles (Optional for style)
            Positioned(
              top: -50,
              right: -50,
              child: _buildCircle(200, Colors.white.withOpacity(0.05)),
            ),
            Positioned(
              bottom: -30,
              left: -30,
              child: _buildCircle(150, Colors.white.withOpacity(0.05)),
            ),
            
            // Central Branding
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.restaurant_menu,
                          size: 80,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "Hostel Mess",
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 2.0,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                offset: Offset(2, 4),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Smart Dining Management",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}