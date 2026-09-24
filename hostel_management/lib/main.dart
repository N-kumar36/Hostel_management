import 'package:HostelMess/views/dashbord/home_page.dart';
import 'package:HostelMess/services/dataconnvater.dart';
import 'package:HostelMess/notification_service.dart';

import 'package:flutter/material.dart';
import 'views/auth/login/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';

import 'package:HostelMess/services/app_update_service.dart';
import 'package:HostelMess/views/update/force_update_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ============================================================
  // LOCAL NOTIFICATION INITIALIZATION
  // ============================================================
  await LocalNotificationService.initialize();

  // ============================================================
  // LOAD SAVED THEME
  // ============================================================
  await ThemeController.instance.loadTheme();

  // ============================================================
  // START APPLICATION
  // ============================================================
  runApp(const HostelApp());
}

class HostelApp extends StatelessWidget {
  const HostelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,

          // ======================================================
          // APP TITLE
          // ======================================================
          title: 'Hostel Mess',

          // ======================================================
          // GLOBAL THEME
          // ======================================================
          theme: AppTheme.lightTheme,

          darkTheme: AppTheme.darkTheme,

          themeMode: ThemeController.instance.themeMode,

          // ======================================================
          // START WITH SPLASH
          // ======================================================
          home: const SplashScreen(),
        );
      },
    );
  }
}

// ============================================================================
// SPLASH SCREEN
// ============================================================================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  final Dataconnvater dataConvert = Dataconnvater();

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();

    // ============================================================
    // SPLASH ANIMATION
    // ============================================================

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.8, curve: Curves.elasticOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.2, 1.0, curve: Curves.easeOutBack),
          ),
        );

    _controller.forward();

    // ============================================================
    // START APP STARTUP PROCESS
    // ============================================================

    _startApplication();
  }

  // ==========================================================================
  // COMPLETE STARTUP FLOW
  // ==========================================================================

  Future<void> _startApplication() async {
    if (_checkingUpdate) return;

    _checkingUpdate = true;

    try {
      // ----------------------------------------------------------
      // Keep the original splash duration
      // ----------------------------------------------------------
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      // ----------------------------------------------------------
      // FIRST: CHECK MANDATORY APP UPDATE
      // ----------------------------------------------------------
      //
      // This happens BEFORE authentication.
      //
      // Example:
      //
      // Installed: 1.0.0+1
      // Minimum:   2.0.0+20
      //
      // Result:
      // ForceUpdatePage
      //
      // Installed: 2.0.0+20
      // Minimum:   2.0.0+20
      //
      // Result:
      // Continue normally
      // ----------------------------------------------------------

      final AppUpdateInfo? updateInfo = await AppUpdateService.instance
          .checkForUpdate();

      if (!mounted) return;

      // ----------------------------------------------------------
      // MANDATORY UPDATE
      // ----------------------------------------------------------

      if (updateInfo != null && updateInfo.forceUpdate) {
        _navigateTo(ForceUpdatePage(updateInfo: updateInfo));

        return;
      }

      // ----------------------------------------------------------
      // NO MANDATORY UPDATE
      // CONTINUE WITH NORMAL AUTHENTICATION
      // ----------------------------------------------------------

      await _checkAuth();
    } catch (e) {
      debugPrint('Application startup error: $e');

      // ----------------------------------------------------------
      // IMPORTANT:
      //
      // If the update server has a temporary problem,
      // do NOT lock the user out.
      //
      // Continue with normal authentication.
      // ----------------------------------------------------------

      if (mounted) {
        await _checkAuth();
      }
    } finally {
      _checkingUpdate = false;
    }
  }

  // ==========================================================================
  // AUTHENTICATION
  // ==========================================================================

  Future<void> _checkAuth() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      // ----------------------------------------------------------
      // GET SAVED TOKEN
      // ----------------------------------------------------------

      final String? token = prefs.getString("token");

      // ----------------------------------------------------------
      // NO TOKEN
      // GO TO LOGIN
      // ----------------------------------------------------------

      if (token == null || token.isEmpty) {
        if (mounted) {
          _navigateTo(const LoginPage());
        }

        return;
      }

      // ----------------------------------------------------------
      // GET SAVED USER DATA
      // ----------------------------------------------------------

      final profileData = await dataConvert.getUserData();

      // ----------------------------------------------------------
      // USER DATA FOUND
      // ----------------------------------------------------------

      if (profileData != null) {
        final bool isManager = profileData['role'] == 'manager';

        final bool isAdmin = profileData['role'] == 'admin';

        if (mounted) {
          _navigateTo(HomePage(isManager: isManager, isAdmin: isAdmin));
        }
      }
      // ----------------------------------------------------------
      // USER DATA NOT FOUND
      // ----------------------------------------------------------
      else {
        if (mounted) {
          _navigateTo(const LoginPage());
        }
      }
    } catch (e) {
      debugPrint('Auth Check Error: $e');

      // ----------------------------------------------------------
      // AUTH ERROR
      // ----------------------------------------------------------

      if (mounted) {
        _navigateTo(const LoginPage());
      }
    }
  }

  // ==========================================================================
  // NAVIGATION
  // ==========================================================================

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

  // ==========================================================================
  // DISPOSE
  // ==========================================================================

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ==========================================================================
  // SPLASH UI
  // ==========================================================================

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
            // ==================================================
            // TOP DECORATION
            // ==================================================
            Positioned(
              top: -50,
              right: -50,
              child: _buildCircle(200, Colors.white.withOpacity(0.05)),
            ),

            // ==================================================
            // BOTTOM DECORATION
            // ==================================================
            Positioned(
              bottom: -30,
              left: -30,
              child: _buildCircle(150, Colors.white.withOpacity(0.05)),
            ),

            // ==================================================
            // MAIN SPLASH CONTENT
            // ==================================================
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
                        // ======================================
                        // ICON
                        // ======================================
                        const Icon(
                          Icons.restaurant_menu,
                          size: 80,
                          color: Colors.white,
                        ),

                        const SizedBox(height: 20),

                        // ======================================
                        // APP NAME
                        // ======================================
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

                        // ======================================
                        // TAGLINE
                        // ======================================
                        Text(
                          "Smart Dining Management",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.2,
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ======================================
                        // VERSION CHECK INDICATOR
                        // ======================================
                        AnimatedOpacity(
                          opacity: _checkingUpdate ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),

                          child: const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
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

  // ==========================================================================
  // DECORATIVE CIRCLE
  // ==========================================================================

  Widget _buildCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
